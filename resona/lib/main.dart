import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:synheart_core/synheart_core.dart';

import 'home/home_screen.dart';
import 'platform/resona_live_activity.dart';
import 'player/player_screen.dart';
import 'settings/settings_screen.dart';
import 'state/resona_state_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'ai.synheart.resona.audio',
    androidNotificationChannelName: 'Resona playback',
    androidNotificationOngoing: true,
  );
  resonaPlayback.preloadAdaptiveTracks();
  runApp(const ResonaApp());
}

class ResonaApp extends StatefulWidget {
  const ResonaApp({super.key});

  @override
  State<ResonaApp> createState() => _ResonaAppState();
}

class _ResonaAppState extends State<ResonaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ResonaLiveActivity.listenForLinks(
        onOpenPlayer: () {
          if (resonaPlayerVisible) return;
          _navigatorKey.currentState?.pushNamed('/player');
        },
        onWearablePair: (uri) async {
          final navigatorContext = _navigatorKey.currentContext;
          if (navigatorContext == null) return;
          final messenger = ScaffoldMessenger.maybeOf(navigatorContext);
          try {
            await ResonaStateEngine.instance.connectFromPairingLink(uri);
            messenger?.showSnackBar(
              const SnackBar(content: Text('Wearable connected')),
            );
          } catch (_) {
            messenger?.showSnackBar(
              const SnackBar(
                content: Text('Could not connect to the wearable source'),
              ),
            );
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'Resona',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF08090C),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8E7CFF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
    routes: {
      '/diagnostics': (_) => const RuntimeDiagnosticScreen(),
      '/player': (_) => PlayerScreen(initialIndex: resonaPlayback.trackIndex),
      '/settings': (_) => const SettingsScreen(),
    },
  );
}

enum DiagnosticPhase { idle, starting, collecting, stopping, failed }

class RuntimeDiagnosticScreen extends StatefulWidget {
  const RuntimeDiagnosticScreen({super.key});

  @override
  State<RuntimeDiagnosticScreen> createState() => _RuntimeDiagnosticState();
}

class _RuntimeDiagnosticState extends State<RuntimeDiagnosticScreen> {
  DiagnosticPhase _phase = DiagnosticPhase.idle;
  StreamSubscription<HSIState>? _hsiSubscription;
  StreamSubscription<WearSample>? _wearSubscription;
  Timer? _clock;
  HSIState? _state;
  WearSample? _wearSample;
  DateTime? _startedAt;
  String? _error;
  Map<String, dynamic> _diagnostics = const {};

  bool get _busy =>
      _phase == DiagnosticPhase.starting || _phase == DiagnosticPhase.stopping;

  Future<void> _start() async {
    if (_busy || _phase == DiagnosticPhase.collecting) return;
    setState(() {
      _phase = DiagnosticPhase.starting;
      _error = null;
      _state = null;
      _wearSample = null;
    });

    try {
      await Synheart.initialize(
        config: SynheartConfig(
          appId: 'ai.synheart.resona',
          subjectId: 'resona-demo-listener',
          appVersion: '0.1.0',
          appName: 'Resona',
          category: 'Music',
          developer: 'Synheart AI',
          allowUnsignedCapabilities: true,
          wearConfig: const WearConfig(),
          behaviorConfig: const BehaviorConfig(),
          consentConfig: ConsentConfig(
            deviceId: 'resona-ios-demo-device',
            platform: 'ios',
            userId: 'resona-demo-listener',
          ),
        ),
      );

      final form = Synheart.consentGetEditableFormTyped();
      if (form == null) {
        throw StateError('The runtime did not provide a consent form.');
      }
      await Synheart.consentSubmitFormTyped(
        form: form.copyWith(
          biosignals: true,
          behavior: true,
          phoneContext: false,
          allowCloud: false,
          allowResearch: false,
          allowVendorSync: false,
          syni: false,
        ),
      );

      final effective = Synheart.consentEffectiveStateTyped();
      if (effective?.biosignals != true && effective?.behavior != true) {
        throw StateError('Local signal consent was not granted.');
      }

      _hsiSubscription = Synheart.onStateUpdate.listen((state) {
        if (!mounted) return;
        setState(() {
          _state = state;
          _diagnostics = Synheart.runtimeDiagnostics();
        });
      }, onError: _onStreamError);
      _wearSubscription = Synheart.wearSampleStream.listen((sample) {
        if (mounted) setState(() => _wearSample = sample);
      });

      await Synheart.startSession();
      Synheart.pushBehaviorTouch(DateTime.now().millisecondsSinceEpoch);
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      if (!mounted) return;
      setState(() {
        _startedAt = DateTime.now();
        _diagnostics = Synheart.runtimeDiagnostics(probeAll: true);
        _phase = DiagnosticPhase.collecting;
      });
    } catch (error) {
      await _releaseRuntime();
      if (!mounted) return;
      setState(() {
        _phase = DiagnosticPhase.failed;
        _error = error.toString();
      });
    }
  }

  void _onStreamError(Object error) {
    if (mounted) setState(() => _error = error.toString());
  }

  Future<void> _stop() async {
    if (_phase != DiagnosticPhase.collecting || _busy) return;
    setState(() => _phase = DiagnosticPhase.stopping);
    try {
      await Synheart.stopSession();
      await _releaseRuntime();
      if (mounted) {
        setState(() {
          _phase = DiagnosticPhase.idle;
          _startedAt = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _phase = DiagnosticPhase.failed;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _releaseRuntime() async {
    _clock?.cancel();
    _clock = null;
    await _hsiSubscription?.cancel();
    await _wearSubscription?.cancel();
    _hsiSubscription = null;
    _wearSubscription = null;
    await Synheart.dispose();
  }

  void _recordInteraction() {
    if (_phase != DiagnosticPhase.collecting) return;
    Synheart.pushBehaviorTouch(DateTime.now().millisecondsSinceEpoch);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Interaction sent to the on-device runtime'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _hsiSubscription?.cancel();
    _wearSubscription?.cancel();
    if (_phase == DiagnosticPhase.collecting) {
      unawaited(Synheart.stopSession().then((_) => Synheart.dispose()));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collecting = _phase == DiagnosticPhase.collecting;
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    final freshness = _state == null
        ? null
        : DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(_state!.timestampMs),
          );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
          children: [
            _Header(phase: _phase),
            const SizedBox(height: 42),
            const Text(
              'Can Resona hear\nthe state?',
              style: TextStyle(
                fontSize: 42,
                height: 1.02,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.8,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'This local check verifies the native runtime before music adaptation is added. Nothing is uploaded.',
              style: TextStyle(
                color: Color(0xFF9698A3),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeading(
                    icon: collecting
                        ? Icons.radio_button_checked_rounded
                        : Icons.memory_rounded,
                    label: collecting ? 'LIVE SESSION' : 'RUNTIME',
                    color: collecting
                        ? const Color(0xFF72E5B6)
                        : const Color(0xFF8E7CFF),
                  ),
                  const SizedBox(height: 22),
                  _MetricRow(
                    label: 'Core',
                    value:
                        (_diagnostics['version'] ??
                                Synheart.runtimeVersion ??
                                'Not loaded')
                            .toString(),
                  ),
                  _MetricRow(
                    label: 'Session',
                    value: collecting ? _formatDuration(elapsed) : 'Stopped',
                  ),
                  _MetricRow(
                    label: 'HSI windows',
                    value: '${_diagnostics['frameCount'] ?? 0}',
                  ),
                  _MetricRow(
                    label: 'Latest state',
                    value: freshness == null
                        ? 'Waiting for first window'
                        : '${freshness.inSeconds}s ago',
                    last: true,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorPanel(message: _error!),
            ],
            const SizedBox(height: 14),
            _StatePanel(state: _state, wearSample: _wearSample),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : (collecting ? _stop : _start),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                backgroundColor: collecting
                    ? const Color(0xFF242631)
                    : const Color(0xFF8E7CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      collecting
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
              label: Text(
                _phase == DiagnosticPhase.starting
                    ? 'Starting Core…'
                    : _phase == DiagnosticPhase.stopping
                    ? 'Stopping…'
                    : collecting
                    ? 'Stop diagnostic'
                    : 'Start local diagnostic',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (collecting) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _recordInteraction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: const Color(0xFFC6BFFF),
                  side: const BorderSide(color: Color(0xFF3C375E)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('Send interaction pulse'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.phase});

  final DiagnosticPhase phase;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF8E7CFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.graphic_eq_rounded),
      ),
      const SizedBox(width: 13),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESONA',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          Text(
            'CORE DIAGNOSTIC',
            style: TextStyle(
              color: Color(0xFF777984),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
            ),
          ),
        ],
      ),
      const Spacer(),
      _StatusPill(phase: phase),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.phase});

  final DiagnosticPhase phase;

  @override
  Widget build(BuildContext context) {
    final active = phase == DiagnosticPhase.collecting;
    final failed = phase == DiagnosticPhase.failed;
    final color = failed
        ? const Color(0xFFFF6871)
        : active
        ? const Color(0xFF72E5B6)
        : const Color(0xFF777984);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        active
            ? '● LIVE'
            : failed
            ? '● ISSUE'
            : '○ LOCAL',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF111318),
      border: Border.all(color: const Color(0xFF242731)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 9),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.7,
        ),
      ),
    ],
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: last ? 0 : 14, top: 2),
    margin: EdgeInsets.only(bottom: last ? 0 : 12),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFF22242C))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF777984))),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.state, required this.wearSample});

  final HSIState? state;
  final WearSample? wearSample;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          icon: Icons.blur_on_rounded,
          label: 'AVAILABLE STATE',
          color: Color(0xFFFFB86B),
        ),
        const SizedBox(height: 20),
        if (state == null)
          const Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Start the session, then allow roughly one minute for the first runtime window.',
                  style: TextStyle(color: Color(0xFF9698A3), height: 1.4),
                ),
              ),
            ],
          )
        else if (state!.hasParseError)
          Text(
            'HSI parse error: ${state!.parseError}',
            style: const TextStyle(color: Color(0xFFFF7B82)),
          )
        else ...[
          _AxesGrid(axes: state!.hsi),
          const SizedBox(height: 18),
          _ModalitiesRow(state: state!),
          ..._withheldReasons(state!.rawJson).map(
            (reason) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                reason,
                style: const TextStyle(
                  color: Color(0xFF858792),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
        if (wearSample != null) ...[
          const SizedBox(height: 18),
          Text(
            'Wear signal received${wearSample!.hr == null ? '' : ' • ${wearSample!.hr!.round()} bpm'}',
            style: const TextStyle(
              color: Color(0xFF72E5B6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

class _AxesGrid extends StatelessWidget {
  const _AxesGrid({required this.axes});

  final HSIAxes axes;

  @override
  Widget build(BuildContext context) {
    final values = <(String, HSIAxisValue?)>[
      ('Focus', axes.focus),
      ('Arousal', axes.arousal),
      ('Capacity', axes.capacity),
      ('Stress', axes.stress),
      ('Sleep', axes.sleep),
      ('Focus quality', axes.focusQuality),
      ('Interruptions', axes.interruptionPressure),
      ('Interaction', axes.interactionMode),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values
          .map((entry) => _AxisChip(label: entry.$1, axis: entry.$2))
          .toList(),
    );
  }
}

class _AxisChip extends StatelessWidget {
  const _AxisChip({required this.label, required this.axis});

  final String label;
  final HSIAxisValue? axis;

  @override
  Widget build(BuildContext context) {
    final available = axis != null && axis!.confidence > 0;
    return Container(
      width: (MediaQuery.sizeOf(context).width - 74) / 2,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: available ? const Color(0xFF1A1927) : const Color(0xFF16181E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF858792), fontSize: 12),
          ),
          const SizedBox(height: 7),
          Text(
            available ? '${(axis!.value * 100).round()}%' : 'Withheld',
            style: TextStyle(
              color: available
                  ? const Color(0xFFEDEBFF)
                  : const Color(0xFF666873),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (available)
            Text(
              '${(axis!.confidence * 100).round()}% confidence',
              style: const TextStyle(color: Color(0xFF8E7CFF), fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _ModalitiesRow extends StatelessWidget {
  const _ModalitiesRow({required this.state});

  final HSIState state;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _ModalityChip(
        label: 'Physiology',
        active: state.modalities.physiological,
      ),
      _ModalityChip(label: 'Motion', active: state.modalities.kinematic),
      _ModalityChip(label: 'Interaction', active: state.modalities.digital),
    ],
  );
}

class _ModalityChip extends StatelessWidget {
  const _ModalityChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF10251F) : const Color(0xFF17191F),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '${active ? '●' : '○'} $label',
      style: TextStyle(
        color: active ? const Color(0xFF72E5B6) : const Color(0xFF666873),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF2A1116),
      border: Border.all(color: const Color(0xFF642A33)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF7B82)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFFFB5B9), height: 1.4),
          ),
        ),
      ],
    ),
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

List<String> _withheldReasons(String rawJson) {
  try {
    final root = jsonDecode(rawJson);
    if (root is! Map) return const [];
    final meta = root['meta'];
    if (meta is! Map) return const [];
    final synheart = meta['synheart'];
    if (synheart is! Map) return const [];
    final withheld = synheart['state_withheld'];
    if (withheld is Map) {
      return withheld.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .toList(growable: false);
    }
    if (withheld is List) {
      return withheld.map((entry) => entry.toString()).toList(growable: false);
    }
  } catch (_) {
    // HSIState already reports malformed payloads; this detail stays optional.
  }
  return const [];
}

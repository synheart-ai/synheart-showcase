import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../app/signals.dart';
import '../app/state_engine.dart';
import '../data/catalogue.dart';
import '../data/demo_scenarios.dart';
import 'check_in_parts.dart';
import 'theme.dart';
import 'widgets.dart';

/// Settings, laid out as a streaming app's App Settings: bold section
/// headings on black, full-width rows with an icon, a title, a grey line and
/// a switch, chevron or status. Consent comes first and nothing is collected
/// before it (RFC §4.4, §6); each source asks only for its own permissions,
/// when it is chosen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.pendingLink});

  /// A WearSim link that arrived before consent was given.
  final Uri? pendingLink;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _link = TextEditingController();
  List<WearableDevice>? _devices;
  bool _scanning = false;

  late final SceneStateEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = context.read<SceneStateEngine>();
    if (widget.pendingLink != null) _link.text = '${widget.pendingLink}';
  }

  @override
  void dispose() {
    // Collection is continuous: leaving Settings keeps the source connected.
    _link.dispose();
    super.dispose();
  }

  DemoLog get _log => context.read<SceneCubit>().log;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The engine keeps the error for display.
    }
  }

  Future<void> _consent() async {
    _log.record(DemoEvent.checkInConsented);
    await _run(_engine.consent);
    if (mounted && _engine.consented && widget.pendingLink != null) await _pair();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final found = await _engine.scanBluetooth();
      if (mounted) setState(() => _devices = found);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pair() async {
    final uri = Uri.tryParse(_link.text.trim());
    if (uri == null) return;
    await _run(() => _engine.pairWearSim(uri));
  }

  void _useDemo(DemoScenario d) {
    _log.record(DemoEvent.demoScenarioUsed, {'scenario': d.name});
    context.read<SceneCubit>().setCurrentState(d.state);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SceneStateEngine>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (!engine.consented)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ConsentCard(
                  busy: engine.busy,
                  error: engine.error,
                  onAgree: _consent,
                  onSkip: () {
                    _log.record(DemoEvent.checkInSkipped);
                    Navigator.of(context).maybePop();
                  },
                ),
              )
            else ...[
              _Section('Synheart', [
                SettingsRow(
                  icon: Icons.favorite,
                  iconColor: SceneColors.accent,
                  title: 'Reading your current state',
                  subtitle: 'On — heart rate and how you use your phone, continuously, also in the background. Turn off to stop.',
                  trailing: Switch(value: true, onChanged: (_) => _run(_engine.withdraw)),
                ),
              ]),
              ..._sources(context, engine),
              _BehaviorSection(backend: engine.backend),
            ],
            _Section('Presenting? Use demo data', [
              for (final d in DemoScenario.values)
                SettingsRow(
                  icon: Icons.play_circle_outline,
                  title: 'Demo data: ${d.title}',
                  subtitle: '${d.purpose}. Labelled as demo data wherever it appears.',
                  onTap: () => _useDemo(d),
                ),
            ]),
            if (engine.consented)
              _Section('WearSim demo source', [
                Container(
                  color: _rowColor,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Open a wearsim:// pairing link, or paste one here.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SceneColors.sage)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _link,
                      decoration: InputDecoration(
                        hintText: 'wearsim://pair?endpoint=ws://…',
                        hintStyle: const TextStyle(color: SceneColors.sage),
                        filled: true,
                        fillColor: SceneColors.panel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: engine.busy ? null : _pair, child: const Text('Pair WearSim')),
                  ]),
                ),
              ]),
            const _FilmData(),
          ],
        ),
      ),
    );
  }

  List<Widget> _sources(BuildContext context, SceneStateEngine engine) {
    final connected = engine.source != WearableSource.none;
    final chosen = engine.chosenName;
    String status() => engine.sourceStalled
        ? 'No heart rate for a minute · reconnecting every minute…'
        : engine.isLive
            ? 'Signal arriving${engine.heartRate == null ? '' : ' · ${engine.heartRate!.round()} BPM'}'
            : 'Waiting for a signal…';
    return [
      _Section('Heart-rate source', [
        SettingsRow(
          icon: connected ? Icons.sensors : Icons.sensors_off,
          iconColor: connected && engine.isLive ? SceneColors.accent : null,
          title: chosen ?? 'Choose a source',
          subtitle: connected ? status() : 'Pick one below. Scene reads it continuously, also in the background, while you have agreed.',
          trailing: connected ? TextButton(onPressed: () => _run(_engine.disconnectSource), child: const Text('Disconnect')) : null,
        ),
        if (engine.error != null)
          SettingsRow(icon: Icons.error_outline, iconColor: SceneColors.accent, title: 'Could not connect', subtitle: engine.error!),
        SettingsRow(
          icon: Icons.watch_outlined,
          title: 'Apple Health / Health Connect',
          subtitle: 'Heart-rate and HRV records from your watch. You will be asked for permission.',
          onTap: engine.busy ? null : () => _run(_engine.connectPlatformHealth),
        ),
        if (engine.backend.supportsWatch)
          SettingsRow(
            icon: Icons.watch,
            title: 'Galaxy Watch',
            subtitle: 'Live heart rate from Scene on your watch. Heart rate only — some readings may stay unavailable.',
            onTap: engine.busy ? null : () => _run(_engine.connectWatch),
          ),
        SettingsRow(
          icon: Icons.bluetooth,
          title: 'Bluetooth heart-rate monitor',
          subtitle: 'The most direct live signal — a chest strap or arm band.',
          onTap: engine.busy || _scanning ? null : _scan,
          trailing: _scanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
        ),
        if (_devices != null) ...[
          if (_devices!.isEmpty) const SettingsRow(icon: Icons.search_off, title: 'No heart-rate monitors found nearby.'),
          for (final d in _devices!) SettingsRow(icon: Icons.link, title: d.name, indent: true, onTap: () => _run(() => _engine.connectBluetooth(d))),
        ],
      ]),
    ];
  }
}

const _rowColor = Color(0xFF1C1C1C);

/// A bold section heading over full-width rows separated by thin lines.
class _Section extends StatelessWidget {
  const _Section(this.title, this.rows);
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w800))),
        ),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFF2E2E2E)),
          row,
        ],
      ]);
}

/// One settings row: icon, title, an optional grey line, and a switch,
/// button, chevron (when tappable) or nothing.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.iconColor, this.indent = false});

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: _rowColor,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent ? 56 : 16, 12, 12, 12),
            child: Row(children: [
              Icon(icon, size: 28, color: iconColor ?? SceneColors.sage),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 17)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                  ],
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!] else if (onTap != null) const Icon(Icons.chevron_right, color: SceneColors.sage),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Where posters and synopses come from, with TMDB's required attribution.
class _FilmData extends StatelessWidget {
  const _FilmData();

  @override
  Widget build(BuildContext context) {
    final movies = context.watch<MovieInfoStore>();
    final status = !movies.enabled
        ? 'No TMDB token in this build, so posters are typographic. Run with --dart-define-from-file=tmdb.json.'
        : movies.loading
            ? 'Fetching film data… ${movies.matched} of ${allFilms.length}'
            : movies.error ?? '${movies.matched} of ${allFilms.length} films matched on TMDB. Cached for offline use.';
    return _Section('Film data', [
      SettingsRow(
        icon: Icons.movie_outlined,
        title: 'Posters, synopses and trailers',
        subtitle: status,
        trailing: movies.enabled && !movies.loading
            ? IconButton(
                tooltip: 'Fetch film data again',
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await movies.clear();
                  await movies.refresh(allFilms);
                },
              )
            : null,
      ),
      Container(
        color: _rowColor,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: const TmdbCredit(
          lead: 'Posters, synopses and trailers come from TMDB (and trailers from YouTube), fetched over the internet; '
              'no health data is sent with them. Recommendations use Scene\'s own film tags.',
        ),
      ),
    ]);
  }
}

/// What behavior signals Scene collects, and Notification access (only the
/// person can grant it, in system Settings; re-checked on return).
class _BehaviorSection extends StatefulWidget {
  const _BehaviorSection({required this.backend});

  final SignalBackend backend;

  @override
  State<_BehaviorSection> createState() => _BehaviorSectionState();
}

class _BehaviorSectionState extends State<_BehaviorSection> with WidgetsBindingObserver {
  bool? _access;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final granted = await widget.backend.notificationAccessGranted();
    if (mounted) setState(() => _access = granted);
  }

  @override
  Widget build(BuildContext context) => _Section('Behavior signals', [
        const SettingsRow(
          icon: Icons.touch_app_outlined,
          title: 'How you use your phone',
          subtitle: 'Taps, scrolls and swipes in Scene, app switches, notification and call events (with the name of '
              'the app that posted a notification), and motion — never content, text, senders or numbers. '
              'Collected continuously, also in the background.',
        ),
        if (_access == true)
          const SettingsRow(icon: Icons.notifications_active_outlined, title: 'Notification events', subtitle: 'On')
        else
          SettingsRow(
            icon: Icons.notifications_off_outlined,
            title: 'Notification events',
            subtitle: 'Notification events need Notification access.',
            trailing: TextButton(onPressed: widget.backend.openNotificationAccess, child: const Text('Allow')),
          ),
      ]);
}

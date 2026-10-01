import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../app/state_engine.dart';
import '../data/demo_scenarios.dart';
import 'check_in_parts.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 4 — Synheart Check-In (plan §4, §10; RFC §4.4). A short, explicit
/// moment: consent, then a minute or two while Synheart reads the chosen
/// wearable, then the Current State card. Collection runs only here.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late final SceneStateEngine _engine;
  late final DemoLog _log;
  Timer? _tick;
  bool _left = false;

  /// The phase last seen, so an outcome is logged once per check-in: the
  /// engine notifies on every reading, and the runtime keeps closing (empty)
  /// windows after collection stops.
  CheckInPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _engine = context.read<SceneStateEngine>();
    _log = context.read<SceneCubit>().log;
    _engine.addListener(_onEngine);
    // After the first frame: resetting notifies listeners, which must not
    // happen while this route is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _engine.resetCheckIn());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _engine.checkIn == CheckInPhase.reading) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _engine.removeListener(_onEngine);
    // Leaving mid-check-in stops collection.
    _engine.cancelCheckIn();
    super.dispose();
  }

  void _onEngine() {
    if (_left || !mounted) return;
    final phase = _engine.checkIn;
    final changed = phase != _lastPhase;
    _lastPhase = phase;
    if (!changed) return;
    if (phase == CheckInPhase.done) {
      _left = true;
      _log.record(DemoEvent.checkInSucceeded, {'source': _engine.checkInResult?.source.name ?? ''});
      _engine.resetCheckIn();
      // Replace: Back from the result should not reopen the check-in.
      context.pushReplacement(Routes.state);
    } else if (phase == CheckInPhase.notEnoughSignal) {
      _log.record(DemoEvent.checkInInsufficientSignal);
    } else if (phase == CheckInPhase.failed) {
      _log.record(DemoEvent.checkInFailed);
    }
  }

  Future<void> _consent() async {
    _log.record(DemoEvent.checkInConsented);
    try {
      await _engine.consent();
    } catch (_) {}
  }

  void _skip() {
    _log.record(DemoEvent.checkInSkipped);
    context.read<SceneCubit>().clearCurrentState();
    context.go(Routes.tonight);
  }

  void _useDemo(DemoScenario d) {
    _log.record(DemoEvent.demoScenarioUsed, {'scenario': d.name});
    context.read<SceneCubit>().setCurrentState(d.state);
    _left = true;
    context.pushReplacement(Routes.state);
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<SceneStateEngine>();
    return Scaffold(
      appBar: AppBar(title: const Text('Synheart check-in'), actions: const [SettingsButton()]),
      body: PageBody(
        children: [
          if (!engine.consented)
            ConsentCard(busy: engine.busy, error: engine.error, onAgree: _consent, onSkip: _skip)
          else
            ..._phase(context, engine),
          if (!engine.checkInRunning) ...[
            const SizedBox(height: 28),
            ..._demo(context),
          ],
        ],
      ),
    );
  }

  List<Widget> _phase(BuildContext context, SceneStateEngine engine) {
    final t = Theme.of(context).textTheme;
    Widget changeSource() => TextButton(
          onPressed: () => context.push(Routes.settings),
          child: Text(engine.chosenSource == null ? 'Choose a source' : 'Change source'),
        );

    switch (engine.checkIn) {
      case CheckInPhase.connecting:
        return [
          const SizedBox(height: 40),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text('Connecting to ${engine.chosenName}…', style: t.titleMedium, textAlign: TextAlign.center),
        ];
      case CheckInPhase.reading:
        final started = engine.checkInStartedAt;
        final elapsed = started == null ? Duration.zero : context.read<SceneCubit>().now().difference(started);
        final mmss = '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
        final status = switch (engine.display) {
          DisplayState.settling => 'Movement is affecting the reading. Stay still for a moment.',
          DisplayState.notEnoughEvidence => 'Not enough signal yet — keep still, it can take a little longer.',
          _ => 'Synheart is reading your rhythm on this device.',
        };
        return [
          const Eyebrow('Your present moment'),
          const SizedBox(height: 6),
          Text('Sit back for a minute', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text('This usually takes one to two minutes.', style: t.bodyLarge?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 28),
          Center(
            child: Column(children: [
              const Icon(Icons.favorite, color: SceneColors.warm, size: 40),
              const SizedBox(height: 6),
              Text(engine.isLive && engine.heartRate != null ? '${engine.heartRate!.round()} BPM' : 'Waiting for heart rate…',
                  style: t.headlineSmall),
              const SizedBox(height: 4),
              Text('${engine.chosenName} · $mmss', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
            ]),
          ),
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(status, style: t.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: () => _engine.cancelCheckIn(), child: const Text('Cancel check-in')),
        ];
      case CheckInPhase.notEnoughSignal || CheckInPhase.failed:
        final failed = engine.checkIn == CheckInPhase.failed;
        return [
          Callout(
            title: failed ? 'The check-in could not start' : 'Not enough signal',
            child: Text(failed
                ? (engine.error ?? 'Scene could not connect to ${engine.chosenName}.')
                : 'Synheart could not get a confident reading this time. That is not a negative result — '
                    'your picks can still use your taste.'),
          ),
          if (!failed && engine.diagnostics != null) _Details(engine),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _engine.startCheckIn(), child: const Text('Try again')),
          TextButton(onPressed: _skip, child: const Text('Use my taste only')),
          changeSource(),
        ];
      case CheckInPhase.idle || CheckInPhase.done:
        final ready = engine.chosenSource != null;
        return [
          const Eyebrow('Your present moment'),
          const SizedBox(height: 6),
          Text('A one-minute check-in', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'What you usually enjoy is not necessarily what fits every evening. Synheart reads your wearable briefly, '
            'on this device, to add that context.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.watch_outlined, color: SceneColors.ink),
              title: Text(ready ? engine.chosenName! : 'No source chosen yet'),
              subtitle: Text(ready
                  ? 'Read only for this check-in'
                  : 'Choose a Galaxy Watch, a heart-rate strap or Apple Health / Health Connect.'),
            ),
          ),
          const SizedBox(height: 12),
          if (ready) FilledButton(onPressed: () => _engine.startCheckIn(), child: const Text('Start check-in')),
          changeSource(),
          TextButton(onPressed: _skip, child: const Text('Skip — use my taste only')),
        ];
    }
  }

  List<Widget> _demo(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      Text('Presenting? Use demo data instead', style: t.titleMedium),
      const SizedBox(height: 4),
      Text('Seeded readings, labelled as demo data wherever they appear.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
      const SizedBox(height: 10),
      for (final d in DemoScenario.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () => _useDemo(d),
            child: Text('Demo data: ${d.title} — ${d.purpose.toLowerCase()}', textAlign: TextAlign.center),
          ),
        ),
    ];
  }
}

/// What the check-in received, so "Not enough signal" can be explained on
/// the spot (counts and confidences only).
class _Details extends StatelessWidget {
  const _Details(this.engine);

  final SceneStateEngine engine;

  @override
  Widget build(BuildContext context) {
    final d = engine.diagnostics!;
    final t = Theme.of(context).textTheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text('Details', style: t.titleSmall),
        children: [
          Text(d.diagnosis, style: t.bodyMedium),
          const SizedBox(height: 8),
          for (final line in d.summary(DateTime.now())) Text(line, style: t.bodySmall?.copyWith(color: SceneColors.sage)),
        ],
      ),
    );
  }
}

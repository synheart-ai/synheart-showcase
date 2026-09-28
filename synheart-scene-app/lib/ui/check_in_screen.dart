import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:synheart_behavior/synheart_behavior.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../app/synheart.dart';
import '../data/demo_scenarios.dart';
import '../domain/state.dart';
import '../engine/state_from_typing.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Where the check-in is (RFC §9.3: loading, success, insufficient signal,
/// failure). Success leaves the screen.
enum CheckInPhase { consent, starting, typing, reading, insufficient, failed }

/// Screen 4 — Synheart Check-In. Consent comes first and nothing is
/// collected before it (RFC §4.4, §6). The Behavior SDK records *how* the
/// user types (rhythm, pauses, corrections), never *what* they type.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _text = TextEditingController();
  final _samples = <TypingSample>[];
  late final SynheartService _synheart;
  BehaviorSession? _session;
  CheckInPhase _phase = CheckInPhase.consent;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _synheart = context.read<SynheartService>();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Stop collecting as soon as the check-in closes; a failure here must not
    // break leaving the screen.
    _session?.end().then((_) {}, onError: (Object _) {});
    _synheart.stop();
    _text.dispose();
    super.dispose();
  }

  DemoLog get _log => context.read<SceneCubit>().log;

  Future<void> _agree() async {
    _log.record(DemoEvent.checkInConsented);
    setState(() => _phase = CheckInPhase.starting);
    // The native SDK is optional for the typing metrics (see SynheartService),
    // so a failure to start it does not block the check-in.
    if (await _synheart.start()) {
      try {
        _session = await _synheart.behavior!.startSession();
      } catch (e) {
        debugPrint('Synheart session not started: $e');
      }
    }
    if (mounted) setState(() => _phase = CheckInPhase.typing);
  }

  void _skip() {
    _log.record(DemoEvent.checkInSkipped, {'at': _phase.name});
    context.read<SceneCubit>().clearCurrentState();
    context.pushReplacement(Routes.tonight);
  }

  // Called by BehaviorTextField when a typing burst ends. Only timing
  // metrics arrive here — the text never leaves this screen.
  void _onTyping(BehaviorEvent e) {
    if (e.eventType == BehaviorEventType.typing) _samples.add(TypingSample.fromMetrics(e.metrics));
  }

  Future<void> _read() async {
    setState(() => _phase = CheckInPhase.reading);
    // Losing focus ends the typing burst, which emits its event.
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    CurrentState? state;
    try {
      state = stateFromTyping(_samples);
    } catch (e) {
      _log.record(DemoEvent.checkInFailed);
      setState(() {
        _phase = CheckInPhase.failed;
        _failure = '$e';
      });
      return;
    }
    if (state == null) {
      _log.record(DemoEvent.checkInInsufficientSignal, {'bursts': '${_samples.length}'});
      setState(() => _phase = CheckInPhase.insufficient);
      return;
    }
    _log.record(DemoEvent.checkInSucceeded, {'nativeSdk': '${_synheart.behavior != null}'});
    _text.clear(); // Nothing the user wrote is kept.
    context.read<SceneCubit>().setCurrentState(state);
    // Replace: Back from the result should not reopen the consent page.
    context.pushReplacement(Routes.state);
  }

  void _useDemo(DemoScenario d) {
    _log.record(DemoEvent.demoScenarioUsed, {'scenario': d.name});
    context.read<SceneCubit>().setCurrentState(d.state);
    context.pushReplacement(Routes.state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synheart check-in')),
      body: _phase == CheckInPhase.consent ? _consent(context) : _checkIn(context),
    );
  }

  Widget _consent(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PageBody(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(onPressed: _agree, child: const Text('I agree — start the check-in')),
          const SizedBox(height: 6),
          TextButton(onPressed: _skip, child: const Text('Skip — use my taste only')),
        ],
      ),
      children: [
        const Eyebrow('Before we start'),
        const SizedBox(height: 6),
        Text('A short typing check-in', style: t.headlineSmall),
        const SizedBox(height: 14),
        Text(
          'You will write a sentence or two about your day. Synheart measures the rhythm of your typing '
          'to suggest what kind of film may fit this evening.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 16),
        const _Point(icon: Icons.keyboard_outlined, title: 'What is measured', text: 'Typing speed, pauses, steadiness and corrections — while this screen is open.'),
        const _Point(icon: Icons.visibility_off_outlined, title: 'What is not', text: 'Your words. The text is cleared when you continue and never stored.'),
        const _Point(icon: Icons.phone_iphone, title: 'Where', text: 'On this device. Nothing is sent anywhere.'),
        const _Point(
          icon: Icons.history,
          title: 'What is kept',
          text: 'Only the result — three levels and the time of the check-in — until you reset the demo.',
        ),
        const SizedBox(height: 18),
        Text('Presenting? Use demo data instead', style: t.titleMedium),
        const SizedBox(height: 4),
        Text('Seeded results, labelled as demo data wherever they appear.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 10),
        for (final d in DemoScenario.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => _useDemo(d),
              child: Text('Demo data: ${d.title} — ${d.purpose.toLowerCase()}', textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }

  Widget _checkIn(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = _phase == CheckInPhase.starting || _phase == CheckInPhase.reading;
    final progress = (_text.text.length / 90).clamp(0.0, 1.0);

    return PageBody(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: busy || _text.text.trim().isEmpty ? null : _read,
            child: Text(_phase == CheckInPhase.reading ? 'Reading your typing rhythm…' : 'Read my current context'),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: _skip, child: const Text('Skip — use my taste only')),
        ],
      ),
      children: [
        const Eyebrow('Your present moment'),
        const SizedBox(height: 6),
        Text('How has today been?', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('Write a few sentences — anything you like.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 18),
        if (_phase == CheckInPhase.starting)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else ...[
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: SceneColors.line)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            // Not createBehaviorTextField(): that factory passes no callback or
            // SDK instance, so its typing events are dropped (synheart_behavior 0.4.1).
            child: BehaviorTextField(
              controller: _text,
              behavior: _synheart.behavior,
              maxLines: 5,
              onTypingEvent: _onTyping,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Busy morning, calmer afternoon…'),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: SceneColors.line, color: SceneColors.sage),
          ),
        ],
        const SizedBox(height: 18),
        switch (_phase) {
          CheckInPhase.insufficient => const Callout(
              key: ValueKey('insufficient'),
              title: 'Not enough signal yet',
              child: Text('There is not enough typing to read a signal. Keep writing a little more, or skip and use your taste only.'),
            ),
          CheckInPhase.failed => Callout(
              key: const ValueKey('failed'),
              title: 'The check-in did not work',
              child: Text('Your picks are still available on taste alone.${_failure == null ? '' : '\n\n$_failure'}'),
            ),
          _ => const Callout(
              title: 'How you type, never what you type',
              child: Text('Pace, pauses and corrections are measured on this device while you write. Your words are not recorded.'),
            ),
        },
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SceneColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              Text(text, style: t.bodyMedium),
            ]),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:synheart_behavior/synheart_behavior.dart';

import '../app/scene_cubit.dart';
import '../app/synheart.dart';
import '../domain/state.dart';
import '../engine/state_from_typing.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 4 — Synheart Check-In: a short journaling prompt. The Behavior SDK
/// records *how* the user types (rhythm, pauses, corrections), never *what*
/// they type (plan §4).
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _text = TextEditingController();
  final _samples = <TypingSample>[];
  BehaviorSession? _session;
  bool _reading = false;

  SynheartBehavior? get _behavior => context.read<SynheartService>().behavior;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  Future<void> _startSession() async {
    final behavior = _behavior;
    if (behavior == null) return;
    try {
      _session = await behavior.startSession();
    } catch (e) {
      debugPrint('Synheart session not started: $e');
    }
  }

  @override
  void dispose() {
    // Close the SDK session; a failure here must not break leaving the screen.
    _session?.end().then((_) {}, onError: (Object _) {});
    _text.dispose();
    super.dispose();
  }

  // Called by BehaviorTextField when a typing burst ends. Only timing
  // metrics arrive here — the text never leaves this screen.
  void _onTyping(BehaviorEvent e) {
    if (e.eventType == BehaviorEventType.typing) _samples.add(TypingSample.fromMetrics(e.metrics));
  }

  Future<void> _read() async {
    setState(() => _reading = true);
    // Losing focus ends the typing burst, which emits its event.
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final state = stateFromTyping(_samples);
    if (state == null) {
      setState(() => _reading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a little more — a sentence or two is enough.')),
      );
      return;
    }
    _text.clear(); // Nothing the user wrote is kept.
    context.read<SceneCubit>().setCurrentState(state);
    context.go(Routes.state);
  }

  void _manual(CurrentState s) {
    context.read<SceneCubit>().setCurrentState(s);
    context.go(Routes.state);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final behavior = context.read<SynheartService>().behavior;
    final progress = (_text.text.length / 90).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Synheart check-in')),
      body: PageBody(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (behavior != null)
              FilledButton(
                onPressed: _reading || _text.text.trim().isEmpty ? null : _read,
                child: Text(_reading ? 'Reading your signals…' : 'Read my current state'),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _manual(const CurrentState(energy: 0.5, mentalLoad: 0.5, engagement: 0.5, source: StateSource.adjusted)),
                    child: const Text('Set it myself'),
                  ),
                ),
                Expanded(
                  child: TextButton(onPressed: () => _manual(CurrentState.planExample), child: const Text('Use demo scenario')),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Eyebrow('Your present moment'),
          const SizedBox(height: 6),
          Text('How has today been?', style: t.headlineSmall),
          const SizedBox(height: 4),
          Text('Write a few sentences — anything you like.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 18),
          if (behavior != null) ...[
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: SceneColors.line)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              // Not createBehaviorTextField(): that factory passes no callback or
              // SDK instance, so its typing events are dropped (synheart_behavior 0.4.1).
              child: BehaviorTextField(
                controller: _text,
                behavior: behavior,
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
            const SizedBox(height: 18),
            const Callout(
              title: 'How you type, never what you type',
              child: Text(
                'Synheart reads the rhythm of your typing — pace, pauses and corrections — on this device. '
                'Your words are not recorded, and this text is cleared when you continue.',
              ),
            ),
          ] else
            Callout(
              title: 'Synheart is not available on this device',
              child: Text(
                'You can still set your state by hand, or use the demo scenario.\n\n${context.read<SynheartService>().error ?? ''}'.trim(),
              ),
            ),
        ],
      ),
    );
  }
}

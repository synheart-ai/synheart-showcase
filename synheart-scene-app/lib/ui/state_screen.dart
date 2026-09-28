import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../domain/state.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 5 — Current State: signals in simple, non-clinical language, with
/// the user in control of the final picture (plan §4, UX guardrail).
class StateScreen extends StatelessWidget {
  const StateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final current = context.select((SceneCubit c) => c.state.current);
    final cubit = context.read<SceneCubit>();

    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your current state')),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.go(Routes.checkIn), child: const Text('Start my check-in')),
          children: const [Callout(child: Text('Do a quick Synheart check-in first.'))],
        ),
      );
    }

    void adjust(CurrentState s) => cubit.setCurrentState(s.copyWith(source: StateSource.adjusted));

    return Scaffold(
      appBar: AppBar(title: const Text('Your current state')),
      body: PageBody(
        bottom: FilledButton(onPressed: () => context.go(Routes.tonight), child: const Text("See tonight's picks")),
        children: [
          Eyebrow(current.source.label),
          const SizedBox(height: 6),
          Text('You seem to be ${current.suggestedExperience.phrase}.', style: t.headlineSmall),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _SignalRow(
                    label: 'Energy',
                    level: current.energyLevel,
                    onChanged: (l) => adjust(current.copyWith(energy: l.value)),
                  ),
                  const Divider(height: 28),
                  _SignalRow(
                    label: 'Mental load',
                    level: current.mentalLoadLevel,
                    onChanged: (l) => adjust(current.copyWith(mentalLoad: l.value)),
                  ),
                  const Divider(height: 28),
                  _SignalRow(
                    label: 'Engagement',
                    level: current.engagementLevel,
                    onChanged: (l) => adjust(current.copyWith(engagement: l.value)),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(child: Text('Suggested experience', style: t.titleMedium)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: SceneColors.panel, borderRadius: BorderRadius.circular(20)),
                        child: Text(current.suggestedExperience.label, style: t.titleMedium),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Callout(
            child: Text(
              'These are contextual signals from how you typed — not a diagnosis. '
              'Tap a level to change anything that does not feel right; you always make the final choice.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.label, required this.level, required this.onChanged});

  final String label;
  final Level level;
  final ValueChanged<Level> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: t.titleMedium)),
          Text(level.label, style: t.titleMedium?.copyWith(color: SceneColors.sage)),
        ]),
        const SizedBox(height: 10),
        SegmentedButton<Level>(
          showSelectedIcon: false,
          segments: [for (final l in Level.values) ButtonSegment(value: l, label: Text(l.label))],
          selected: {level},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 5 — Current context: provisional, non-clinical labels with the
/// check-in time, and a suggested viewing intent the user can accept, change
/// or skip (RFC §4.5, §6).
class StateScreen extends StatelessWidget {
  const StateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final current = context.select((SceneCubit c) => c.state.current);
    final cubit = context.read<SceneCubit>();

    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your current context')),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Start my check-in')),
          children: const [Callout(child: Text('Do a quick Synheart check-in first.'))],
        ),
      );
    }

    void adjust(CurrentState s) => cubit.setCurrentState(s.copyWith(source: StateSource.adjusted));
    final viewing = context.select((SceneCubit c) => c.state.viewing);
    final suggested = current.suggestedExperience.suggestedIntent;
    final at = current.capturedAt;
    final stale = current.isStaleAt(cubit.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Your current context')),
      body: PageBody(
        bottom: FilledButton(onPressed: () => context.push(Routes.tonight), child: const Text("See tonight's picks")),
        children: [
          Eyebrow(current.source.label),
          if (at != null) ...[
            const SizedBox(height: 4),
            Text(
              'Checked in at ${_hhmm(at)} · ${ageLabel(at, cubit.now())}${stale ? ' — too old to use' : ''}',
              style: t.bodyMedium?.copyWith(color: stale ? SceneColors.warm : SceneColors.sage),
            ),
          ],
          const SizedBox(height: 10),
          Text('This may be ${current.suggestedExperience.phrase}.', style: t.headlineSmall),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signals from typing — provisional labels', style: t.labelSmall),
                  const SizedBox(height: 14),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('What kind of evening?', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Suggested: ${suggested.label}. Your choice always wins over the suggestion — or skip it.',
            style: t.bodyMedium?.copyWith(color: SceneColors.sage),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final intent in EveningIntent.values)
                ChoiceChip(
                  label: Text(intent == suggested ? '${intent.label} (suggested)' : intent.label),
                  selected: viewing.intent == intent,
                  onSelected: (on) => cubit.setIntent(on ? intent : null),
                ),
              ChoiceChip(
                label: const Text('No preference'),
                selected: viewing.intent == null,
                onSelected: (_) => cubit.setIntent(null),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Callout(
            child: Text(
              'Energy, mental load and engagement are Scene\'s provisional reading of your typing rhythm — '
              'not validated measures, and not a diagnosis. Tap a level to change anything that does not feel right.',
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.pushReplacement(Routes.checkIn), child: const Text('Check in again')),
        ],
      ),
    );
  }
}

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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

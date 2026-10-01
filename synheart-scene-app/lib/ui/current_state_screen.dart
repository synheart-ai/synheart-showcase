import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../engine/explain.dart';
import 'check_in_parts.dart';
import 'routes.dart';
import 'state_card.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 5 — Current State (plan §4's example card; RFC §4.5): the check-in
/// result in plain words, its time, and the suggested evening to accept,
/// change or skip.
class CurrentStateScreen extends StatelessWidget {
  const CurrentStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.watch<SceneCubit>();
    final reading = cubit.state.current;

    if (reading == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your current state'), actions: const [SettingsButton()]),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.pushReplacement(Routes.checkIn), child: const Text('Do a Synheart check-in')),
          children: const [Callout(child: Text('No check-in yet.'))],
        ),
      );
    }

    final need = reading.hasEvidence ? reading.suggestedExperience : null;
    final at = reading.capturedAt;
    final stale = reading.isStaleAt(cubit.now());
    final headline = !reading.hasEvidence
        ? 'Not enough signal to say what fits tonight.'
        : need == null
            ? 'You seem balanced.'
            : 'This may be ${need.phrase}.';

    return Scaffold(
      appBar: AppBar(title: const Text('Your current state'), actions: const [SettingsButton()]),
      body: PageBody(
        bottom: FilledButton(onPressed: () => context.go(Routes.tonight), child: const Text("See tonight's picks")),
        children: [
          Eyebrow(reading.source.label),
          if (at != null) ...[
            const SizedBox(height: 4),
            Text(
              'Checked in at ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} · ${ageLabel(at, cubit.now())}'
              '${stale ? ' — too old to use' : ''}',
              style: t.bodyMedium?.copyWith(color: stale ? SceneColors.warm : SceneColors.sage),
            ),
          ],
          const SizedBox(height: 10),
          Text(headline, style: t.headlineSmall),
          const SizedBox(height: 18),
          StateCard(reading: reading),
          const SizedBox(height: 22),
          IntentChoice(suggested: stale ? null : need?.suggestedIntent),
          const SizedBox(height: 18),
          const Callout(
            child: Text(
              'These are contextual signals from Synheart, computed on this device — not a diagnosis. '
              'You always make the final choice.',
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.pushReplacement(Routes.checkIn), child: const Text('Check in again')),
        ],
      ),
    );
  }
}

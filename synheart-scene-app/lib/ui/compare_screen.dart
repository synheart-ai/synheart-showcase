import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 8 — "What changed?": taste-only and taste + state side by side, as
/// in the plan's table (§6), with the demo line and the closing message.
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<SceneCubit>().state;

    if (s.profile == null || s.current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('What changed?')),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.go(Routes.checkIn), child: const Text('Do my check-in')),
          children: const [Callout(child: Text('Scene needs your baseline and a check-in to compare.'))],
        ),
      );
    }

    final taste = picksFor(s, mode: RecommendationMode.tasteOnly);
    final withState = picksFor(s, mode: RecommendationMode.tastePlusState);
    final tasteIds = taste.map((r) => r.film.id).toSet();
    final rows = taste.length > withState.length ? taste.length : withState.length;

    return Scaffold(
      appBar: AppBar(title: const Text('What changed?')),
      body: PageBody(
        bottom: FilledButton(
          onPressed: () {
            context.read<SceneCubit>().setMode(RecommendationMode.tastePlusState);
            context.go(Routes.tonight);
          },
          child: const Text('Watch with my current state'),
        ),
        children: [
          Text('BASED ON TASTE  ⇄  TASTE + CURRENT STATE', style: t.labelSmall, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Table(
            border: const TableBorder(horizontalInside: BorderSide(color: SceneColors.line)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: SceneColors.panel),
                children: [
                  _cell(context, 'Taste only', header: true),
                  _cell(context, 'Taste + current state', header: true),
                ],
              ),
              for (var i = 0; i < rows; i++)
                TableRow(children: [
                  _cell(context, i < taste.length ? taste[i].film.title : ''),
                  _cell(context, i < withState.length ? withState[i].film.title : '', isNew: i < withState.length && !tasteIds.contains(withState[i].film.id)),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.fiber_new_outlined, size: 18, color: SceneColors.warm),
            const SizedBox(width: 6),
            Expanded(child: Text('new tonight because of your current state', style: t.bodyMedium?.copyWith(color: SceneColors.sage))),
          ]),
          const SizedBox(height: 20),
          const Callout(title: 'Demo line', child: Text("Your preferences haven't changed. Your context has.")),
          const SizedBox(height: 12),
          const Callout(
            title: 'Closing message',
            child: Text('Synheart adds the missing context between what a person generally prefers and what may fit their present moment.'),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String text, {bool header = false, bool isNew = false}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(children: [
        Expanded(child: Text(text, style: header ? t.titleMedium : t.bodyLarge)),
        if (isNew) const Icon(Icons.fiber_new_outlined, size: 18, color: SceneColors.warm),
      ]),
    );
  }
}

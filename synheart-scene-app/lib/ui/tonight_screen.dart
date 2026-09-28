import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';
import 'tonight_extras.dart';
import 'widgets.dart';

/// Screen 6 — Tonight's Picks, with the key demo toggle (screen 8):
/// BASED ON TASTE ⇄ TASTE + CURRENT STATE (plan §5, §6).
class TonightScreen extends StatelessWidget {
  const TonightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SceneCubit>().state;
    final cubit = context.read<SceneCubit>();

    if (s.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tonight's picks")),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.push(Routes.profile), child: const Text('Build my movie profile')),
          children: const [Callout(child: Text('Scene needs your movie profile first.'))],
        ),
      );
    }

    final picks = Picks.of(cubit);
    final list = picks.list();
    final current = picks.state;
    final at = s.current?.capturedAt;

    final String note;
    if (picks.withState) {
      note = '';
    } else if (picks.isStale) {
      note = 'Taste only. Your check-in from ${ageLabel(at!, cubit.now())} is too old to use — check in again to see what fits right now.';
    } else if (current == null) {
      note = 'Taste only. No check-in was used — do one to see what fits right now.';
    } else {
      note = 'Taste only — the way a conventional recommender would.';
    }

    return LogOnShow(
      event: DemoEvent.recommendationsViewed,
      fields: {'mode': picks.mode.name, 'stale': '${picks.isStale}'},
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Tonight's picks"),
          actions: [
            if (current != null && at != null)
              TextButton.icon(
                onPressed: () => context.push(Routes.state),
                icon: const Icon(Icons.favorite, size: 16),
                label: Text(ageLabel(at, cubit.now())),
              ),
          ],
        ),
        body: PageBody(
          bottom: current == null
              ? FilledButton(onPressed: () => context.push(Routes.checkIn), child: Text(picks.isStale ? 'Check in again' : 'Add my current context'))
              : OutlinedButton(onPressed: () => context.push(Routes.compare), child: const Text('What changed? Compare side by side')),
          children: [
            SegmentedButton<RecommendationMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: RecommendationMode.tasteOnly, label: Text('BASED ON TASTE')),
                ButtonSegment(value: RecommendationMode.tastePlusState, label: Text('TASTE + CURRENT STATE')),
              ],
              selected: {picks.mode},
              onSelectionChanged: current == null ? null : (m) => cubit.setMode(m.first),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: picks.withState
                  ? Callout(
                      key: const ValueKey('changed'),
                      title: "Your preferences haven't changed.",
                      child: Text('Your context has.${current!.source == StateSource.preset ? ' (Demo data — not a real check-in.)' : ''}'),
                    )
                  : Callout(key: ValueKey(note), child: Text(note)),
            ),
            const SizedBox(height: 16),
            const ChooseMyEvening(),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Column(
                key: ValueKey('${picks.mode}-$current-${s.viewing}-${s.hiddenFilmIds.length}'),
                children: [
                  for (final (i, r) in list.indexed) ...[
                    _PickCard(rank: i + 1, recommendation: r, headline: picks.explanation(r).headline),
                    const SizedBox(height: 12),
                  ],
                  if (list.isEmpty) const Callout(child: Text('Nothing fits these filters — try removing one.')),
                ],
              ),
            ),
            if (picks.withState) const StateCollections(),
          ],
        ),
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.rank, required this.recommendation, required this.headline});

  final int rank;
  final Recommendation recommendation;
  final String headline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = recommendation.film;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': 'picks', 'rank': '$rank'});
          context.push(Routes.why(f.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Poster(f),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(f.title, style: t.titleLarge)),
                      Text('#$rank', style: t.labelSmall),
                    ]),
                    const SizedBox(height: 2),
                    Text(recommendation.fitLabel, style: t.bodyMedium?.copyWith(color: SceneColors.accent, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${f.year} · ${f.runtimeMinutes} min · ${f.genres.take(2).map((g) => g.label).join(' · ')}',
                        style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                    const SizedBox(height: 8),
                    Text(headline, style: t.bodyMedium),
                    const SizedBox(height: 8),
                    Text('Why this movie? →', style: t.bodyMedium?.copyWith(color: SceneColors.ink, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

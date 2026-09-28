import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
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
          bottom: FilledButton(onPressed: () => context.go(Routes.profile), child: const Text('Build my movie profile')),
          children: const [Callout(child: Text('Scene needs your movie profile first.'))],
        ),
      );
    }

    final picks = picksFor(s);
    final withState = s.mode == RecommendationMode.tastePlusState && s.current != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tonight's picks"),
        actions: [
          if (s.current != null)
            TextButton.icon(
              onPressed: () => context.go(Routes.state),
              icon: const Icon(Icons.favorite, size: 16),
              label: Text(s.current!.suggestedExperience.label),
            ),
        ],
      ),
      body: PageBody(
        bottom: s.current == null
            ? FilledButton(onPressed: () => context.go(Routes.checkIn), child: const Text('Add my current state'))
            : OutlinedButton(onPressed: () => context.go(Routes.compare), child: const Text('What changed? Compare side by side')),
        children: [
          SegmentedButton<RecommendationMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: RecommendationMode.tasteOnly, label: Text('BASED ON TASTE')),
              ButtonSegment(value: RecommendationMode.tastePlusState, label: Text('TASTE + CURRENT STATE')),
            ],
            selected: {s.current == null ? RecommendationMode.tasteOnly : s.mode},
            onSelectionChanged: s.current == null ? null : (m) => cubit.setMode(m.first),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: withState
                ? const Callout(key: ValueKey('changed'), title: "Your preferences haven't changed.", child: Text('Your context has.'))
                : Callout(
                    key: const ValueKey('taste'),
                    child: Text(s.current == null
                        ? 'Picked on your taste alone. Do a Synheart check-in to see what fits right now.'
                        : 'Picked on your taste alone — the way a conventional recommender would.'),
                  ),
          ),
          if (withState) ...[
            const SizedBox(height: 16),
            const ChooseMyEvening(),
          ],
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Column(
              key: ValueKey('${s.mode}-${s.current}-${s.viewing}'),
              children: [
                for (final (i, r) in picks.indexed) ...[
                  _PickCard(rank: i + 1, recommendation: r, headline: explanationFor(s, r).headline),
                  const SizedBox(height: 12),
                ],
                if (picks.isEmpty) const Callout(child: Text('Nothing fits these filters — try removing one.')),
              ],
            ),
          ),
          if (withState) const StateCollections(),
        ],
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
        onTap: () => context.push(Routes.why(f.id)),
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

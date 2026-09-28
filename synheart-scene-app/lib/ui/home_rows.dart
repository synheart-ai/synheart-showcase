import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../domain/film.dart';
import '../engine/collections.dart';
import '../engine/recommender.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';

void _open(BuildContext context, Film f, String from, {int? rank}) {
  context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': from, if (rank != null) 'rank': '$rank'});
  context.push(Routes.why(f.id));
}

/// The top pick, large — the first thing on the home screen.
class HeroPick extends StatelessWidget {
  const HeroPick({super.key, required this.recommendation, required this.headline});

  final Recommendation recommendation;
  final String headline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = recommendation.film;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, f, 'hero', rank: 1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Poster(f, width: 118, height: 170),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#1 TONIGHT', style: t.labelSmall),
                        const SizedBox(height: 4),
                        Text(f.title, style: t.headlineSmall),
                        const SizedBox(height: 4),
                        Text('${f.year} · ${f.runtimeMinutes} min', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                        Text(f.genres.take(2).map((g) => g.label).join(' · '), style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                        const SizedBox(height: 8),
                        Text(recommendation.fitLabel,
                            style: t.bodyMedium?.copyWith(color: SceneColors.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(headline, style: t.bodyLarge),
              const SizedBox(height: 8),
              Text(f.logline, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
              const SizedBox(height: 12),
              Text('Why this movie? →', style: t.bodyMedium?.copyWith(color: SceneColors.ink, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tonight's ranked list as a row, with the rank on each tile.
class TopRow extends StatelessWidget {
  const TopRow({super.key, required this.picks});

  final List<Recommendation> picks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Not a fixed-height ListView: five tiles, sized to their text, so a
    // two-line title or large text never overflows.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, r) in picks.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            SizedBox(
              width: 124,
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(context, r.film, 'top', rank: i + 1),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Poster(r.film, width: 108, height: 150),
                        const SizedBox(height: 6),
                        Text('#${i + 1}', style: t.labelSmall),
                        Text(r.film.title, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(r.fit.label, style: t.bodySmall?.copyWith(color: SceneColors.accent)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A titled row of posters.
class PosterRow extends StatelessWidget {
  const PosterRow({super.key, required this.title, this.subtitle, required this.films, required this.from});

  final String title;
  final String? subtitle;
  final List<Film> films;

  /// For the event log: which row a film was picked from.
  final String from;

  @override
  Widget build(BuildContext context) {
    if (films.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text(title, style: t.titleLarge),
        if (subtitle != null) Text(subtitle!, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: films.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final f = films[i];
              return Semantics(
                button: true,
                label: '${f.title}, ${f.year}. Why this movie?',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _open(context, f, from),
                  child: Poster(f, width: 88, height: 128),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Browse rows under the top list: the state-aware collections when a
/// reading is in use, otherwise "Because you like …" rows from taste alone.
class BrowseRows extends StatelessWidget {
  const BrowseRows({super.key, required this.withState, required this.exclude});

  final bool withState;

  /// Films already shown in tonight's top list.
  final Set<String> exclude;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SceneCubit>();
    final s = cubit.state;
    final profile = s.profile;
    if (profile == null) return const SizedBox.shrink();
    final current = cubit.freshState;

    if (withState && current != null) {
      final collections = buildCollections(profile, state: current, context: s.viewing, hidden: s.hiddenFilmIds);
      return Column(children: [
        for (final e in collections.entries) PosterRow(title: e.key.title, subtitle: e.key.subtitle, films: e.value, from: e.key.name),
      ]);
    }
    final rows = tasteRows(profile, hidden: s.hiddenFilmIds, exclude: exclude, context: s.viewing);
    return Column(children: [
      for (final (g, films) in rows) PosterRow(title: 'Because you like ${g.label}', films: films, from: 'taste-${g.name}'),
    ]);
  }
}

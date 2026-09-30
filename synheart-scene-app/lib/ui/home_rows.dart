import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
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

/// The top pick as a cinema-app hero: full-bleed poster art, the title, a
/// tag line and the two actions — trailer and *Why this movie?*.
class HeroPick extends StatelessWidget {
  const HeroPick({super.key, required this.recommendation, required this.headline});

  final Recommendation recommendation;
  final String headline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = recommendation.film;
    final trailer = context.watch<MovieInfoStore>()[f.id]?.trailerUrl;
    final tags = ['Movie', ...f.genres.take(2).map((g) => g.label), '${f.runtimeMinutes} min'];
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SceneColors.line)),
      child: InkWell(
        onTap: () => _open(context, f, 'hero', rank: 1),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              Poster(f, width: w, height: w * 1.32, radius: 0),
              // Darken the lower half so the title and actions read on any art.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 0.72, 1],
                      colors: [Colors.transparent, SceneColors.paper.withValues(alpha: 0.82), SceneColors.paper],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  children: [
                    Text('#1 TONIGHT', style: t.labelSmall?.copyWith(color: SceneColors.accent)),
                    const SizedBox(height: 6),
                    Text(f.title, textAlign: TextAlign.center, style: t.displaySmall),
                    const SizedBox(height: 8),
                    Text(tags.join('  •  '), textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: SceneColors.body)),
                    const SizedBox(height: 4),
                    Text(recommendation.fitLabel, style: t.bodyMedium?.copyWith(color: SceneColors.accent, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Row(children: [
                      if (trailer != null) ...[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': 'hero-trailer'});
                              launchUrl(trailer, mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 28),
                            label: const Text('Trailer'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(backgroundColor: SceneColors.panel.withValues(alpha: 0.92)),
                          onPressed: () => _open(context, f, 'hero', rank: 1),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Why this pick'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(headline, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Tonight's ranked list as a "top" row: a large rank numeral beside each
/// poster, with the title and fit underneath.
class TopRow extends StatelessWidget {
  const TopRow({super.key, required this.picks});

  final List<Recommendation> picks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Not a fixed-height ListView: tiles sized to their text, so a two-line
    // title or large text never overflows.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, r) in picks.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(
              width: 168,
              child: Card(
                color: SceneColors.paper,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(context, r.film, 'top', rank: i + 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        SizedBox(width: 58, child: _RankNumeral(i + 1)),
                        Poster(r.film, width: 110, height: 160),
                      ]),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(58, 6, 4, 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('#${i + 1}', style: t.labelSmall?.copyWith(color: SceneColors.accent)),
                          Text(r.film.title, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(r.fit.label, style: t.bodySmall),
                        ]),
                      ),
                    ],
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

/// The big outlined rank beside a top-row poster; decorative (the "#n"
/// label under it is what screen readers read).
class _RankNumeral extends StatelessWidget {
  const _RankNumeral(this.rank);
  final int rank;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomRight,
          child: Text('$rank',
                style: TextStyle(
                  fontSize: 104,
                  height: 0.9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -6,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = SceneColors.sage,
                )),
        ),
      );
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
        const SizedBox(height: 26),
        Text(title, style: t.titleLarge),
        if (subtitle != null) Text(subtitle!, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: films.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = films[i];
              return Semantics(
                button: true,
                label: '${f.title}, ${f.year}. Why this movie?',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _open(context, f, from),
                  child: Poster(f, width: 116, height: 168),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../domain/film.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'poster.dart';
import 'routes.dart';
import 'state_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

void openTitle(BuildContext context, Film f, String from, {int? rank}) {
  context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': from, if (rank != null) 'rank': '$rank'});
  context.push(Routes.why(f.id));
}

void playTrailer(BuildContext context, Film f, Uri trailer, String from) {
  context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': from});
  launchUrl(trailer, mode: LaunchMode.externalApplication);
}

/// "+ My List" / "✓ My List".
class MyListButton extends StatelessWidget {
  const MyListButton({super.key, required this.film, this.compact = false});
  final Film film;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final on = context.select((SceneCubit c) => c.state.myList.contains(film.id));
    final icon = Icon(on ? Icons.check : Icons.add, size: 26);
    void tap() => context.read<SceneCubit>().toggleMyList(film.id);
    if (compact) {
      return TextButton(
        onPressed: tap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(height: 4), const Text('My List')]),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(backgroundColor: const Color(0xD9404040)),
      onPressed: tap,
      icon: icon,
      label: const Text('My List'),
    );
  }
}

/// The top pick as a cinema-app hero: full-bleed poster art, the title, a
/// tag line, then Play (the trailer) and + My List.
class HeroPick extends StatelessWidget {
  const HeroPick({super.key, required this.recommendation, this.tagline});

  final Recommendation recommendation;

  /// Why it leads tonight, in a few words (shown under the tags).
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = recommendation.film;
    final trailer = context.watch<MovieInfoStore>()[f.id]?.trailerUrl;
    final tags = ['Movie', ...f.genres.take(3).map((g) => g.label)];
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF3A3A3A))),
      child: InkWell(
        onTap: () => openTitle(context, f, 'hero', rank: 1),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(children: [
            Poster(f, width: w, height: w * 1.38, radius: 0),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 0.78, 1],
                    colors: [Colors.transparent, SceneColors.paper.withValues(alpha: 0.75), SceneColors.paper.withValues(alpha: 0.95)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(children: [
                Text(f.title, textAlign: TextAlign.center, style: t.displaySmall),
                const SizedBox(height: 8),
                Text(tags.join('  •  '), textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: SceneColors.body)),
                if (tagline != null) ...[
                  const SizedBox(height: 4),
                  Text(tagline!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: SceneColors.accent, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: trailer == null ? () => openTitle(context, f, 'hero', rank: 1) : () => playTrailer(context, f, trailer, 'hero-play'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                      label: const Text('Play'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: MyListButton(film: f)),
                ]),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

/// A titled row of posters, each optionally with a red badge.
class PosterRow extends StatelessWidget {
  const PosterRow({super.key, required this.title, required this.films, required this.from, this.badges = const {}});

  final String title;
  final List<Film> films;

  /// Film id → badge text ("Easy watch", "Strong fit").
  final Map<String, String> badges;

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
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: films.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = films[i];
              final badge = badges[f.id];
              return Semantics(
                button: true,
                label: '${f.title}, ${f.year}${badge == null ? '' : '. $badge'}. Open.',
                child: ExcludeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => openTitle(context, f, from),
                    child: Stack(alignment: Alignment.bottomCenter, children: [
                      Poster(f, width: 124, height: 180),
                      if (badge != null) _Badge(badge),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: SceneColors.red, borderRadius: BorderRadius.circular(3)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// Top ten, with the large outlined rank numeral beside each poster.
class TopRow extends StatelessWidget {
  const TopRow({super.key, required this.title, required this.picks});

  final String title;
  final List<Recommendation> picks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 26),
      Text(title, style: t.titleLarge),
      const SizedBox(height: 10),
      SizedBox(
        height: 172,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: picks.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, i) {
            final f = picks[i].film;
            return Semantics(
              button: true,
              label: 'Number ${i + 1}: ${f.title}. Open.',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => openTitle(context, f, 'top', rank: i + 1),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    SizedBox(
                      width: i + 1 >= 10 ? 92 : 62,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomRight,
                        child: Text('${i + 1}',
                            style: TextStyle(
                              fontSize: 128,
                              height: 0.86,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -8,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3.5
                                ..color = const Color(0xFF8C8C8C),
                            )),
                      ),
                    ),
                    Poster(f, width: 116, height: 172),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// The state-aware banner — the place a cinema app puts a themed section:
/// tinted by the current state, saying what Synheart sees right now and
/// three picks for it, each with a round Watch button. Without a usable
/// reading it says why and offers the check-in.
class StateBanner extends StatelessWidget {
  const StateBanner({super.key, required this.picks, required this.films});

  final Picks picks;

  /// The picks to list (already in tonight's order).
  final List<Recommendation> films;

  static List<Color> tint(Experience? e) => switch (e) {
        Experience.unwind => const [Color(0xFF1E4D3A), Color(0xFF0E241B)],
        Experience.easyWatch => const [Color(0xFF4B2A6B), Color(0xFF221432)],
        Experience.stayEngaged => const [Color(0xFF173E6B), Color(0xFF0B1D33)],
        null => const [Color(0xFF3A3A3A), Color(0xFF1A1A1A)],
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<SceneCubit>();
    final st = picks.state;
    final need = picks.hasUsableState ? st!.suggestedExperience : null;
    final String eyebrow;
    final String headline;
    final String message;
    if (picks.hasUsableState) {
      eyebrow = st!.source == StateSource.preset ? 'RIGHT NOW · DEMO DATA' : 'RIGHT NOW · FROM YOUR WEARABLE';
      headline = need?.label ?? 'No clear need';
      message = need?.message ?? 'Nothing stands out right now, so tonight leans on your taste.';
    } else if (picks.isStale) {
      eyebrow = 'RIGHT NOW';
      headline = 'Reading too old';
      message = 'Your last reading, from ${ageLabel(cubit.state.current!.capturedAt!, cubit.now())}, is too old to use. Picks follow your taste.';
    } else if (picks.lacksEvidence) {
      eyebrow = 'RIGHT NOW';
      headline = 'Listening…';
      message = 'There is not enough signal yet to say what fits right now — this is not a negative result. Picks follow your taste.';
    } else {
      eyebrow = 'RIGHT NOW';
      headline = 'Picks that fit your state';
      message = 'Connect your watch and Scene tunes Home to how you are right now. Until then, picks follow your taste.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: tint(need)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          label: '$headline. $message Opens your current state.',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: () => showStateSheet(context),
              child: Column(children: [
                Text(eyebrow, textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: SceneColors.ink, letterSpacing: 2.4)),
                const SizedBox(height: 6),
                Text(headline, textAlign: TextAlign.center, style: t.displaySmall),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: SceneColors.body)),
                if (picks.hasUsableState && st!.isLowConfidence) ...[
                  const SizedBox(height: 6),
                  const Center(child: LowConfidenceTag()),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!picks.hasUsableState)
          FilledButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Connect your watch'))
        else
          for (final r in films) _BannerRow(r),
      ]),
    );
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow(this.r);
  final Recommendation r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = r.film;
    final backdrop = context.watch<MovieInfoStore>()[f.id]?.backdropUrl(size: 'w300');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openTitle(context, f, 'banner'),
          child: Row(children: [
            SizedBox(
              width: 132,
              height: 84,
              child: backdrop == null
                  ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: Poster(f, width: 132, height: 190, radius: 0))
                  : ExcludeSemantics(
                      child: CachedNetworkImage(
                        imageUrl: backdrop,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const ColoredBox(color: SceneColors.panel),
                        errorWidget: (_, _, _) => FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: Poster(f, width: 132, height: 190, radius: 0)),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                Text('Movie  •  ${f.genres.first.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: SceneColors.body)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 30),
                ),
                const SizedBox(height: 2),
                Text('Watch', style: t.bodySmall?.copyWith(color: SceneColors.ink, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../domain/film.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';
import 'home_rows.dart';
import 'nav_bar.dart';
import 'picks.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';
import 'tonight_extras.dart';
import 'widgets.dart';

/// A film's title page: backdrop and Play, title, meta line, synopsis, the
/// My List / Rate / Check in row, then two tabs — *Why It Fits* (taste,
/// right now, and how that shaped this pick, from the contribution record,
/// RFC §8) and *More Like This*.
class WhyScreen extends StatefulWidget {
  const WhyScreen({super.key, required this.filmId});

  final String filmId;

  @override
  State<WhyScreen> createState() => _WhyScreenState();
}

class _WhyScreenState extends State<WhyScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    context.watch<SceneCubit>();
    final picks = Picks.of(context.read<SceneCubit>());
    final r = picks.score(widget.filmId);

    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const PageBody(children: [Callout(child: Text('That film is not in tonight\'s list.'))]),
      );
    }

    final f = r.film;
    final info = context.watch<MovieInfoStore>()[f.id];
    final trailer = info?.trailerUrl;
    final runtime = '${f.runtimeMinutes ~/ 60}h ${f.runtimeMinutes % 60}m';
    final more = [
      for (final other in picks.list(limit: 1000))
        if (other.film.id != f.id && other.film.genres.any(f.genres.contains)) other.film,
    ].take(12).toList();

    return LogOnShow(
      event: DemoEvent.explanationViewed,
      fields: {'film': f.id, 'mode': picks.mode.name},
      child: Scaffold(
        appBar: AppBar(),
        extendBody: true,
        bottomNavigationBar: const SceneNavBar(current: null),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Backdrop(film: f, onPlay: trailer == null ? null : () => playTrailer(context, f, trailer, 'title-backdrop')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/scene_mark.png', height: 22, excludeFromSemantics: true),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(r.fitLabel.toUpperCase(), style: t.labelSmall?.copyWith(color: SceneColors.accent, letterSpacing: 1.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(f.title, style: t.displaySmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${f.year}', style: t.bodyLarge?.copyWith(color: SceneColors.sage)),
                      _Pill(f.genres.first.label),
                      Text(runtime, style: t.bodyLarge?.copyWith(color: SceneColors.sage)),
                      if (f.isShort) const _Pill('Under 90 min'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: trailer == null ? null : () => playTrailer(context, f, trailer, 'title-play'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 30),
                    label: Text(trailer == null ? 'No trailer available' : 'Watch trailer'),
                  ),
                  const SizedBox(height: 14),
                  Text(info?.overview ?? f.logline, style: t.bodyLarge),
                  const SizedBox(height: 6),
                  Text(f.genres.map((g) => g.label).join(' · '), style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: MyListButton(film: f, compact: true)),
                      Expanded(
                        child: TextButton(
                          onPressed: () => _rate(context, f.id),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.thumb_up_alt_outlined, size: 26), SizedBox(height: 4), Text('Rate')],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => context.push(Routes.checkIn),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.favorite_border, size: 26), SizedBox(height: 4), Text('Check in')],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Tabs(selected: _tab, labels: const ['Why It Fits', 'More Like This'], onSelect: (i) => setState(() => _tab = i)),
                  const SizedBox(height: 16),
                  if (_tab == 0) _WhyItFits(r: r, picks: picks) else _MoreLikeThis(films: more),
                  const SizedBox(height: 16),
                  const TmdbCredit(lead: 'Film data from TMDB.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _rate(BuildContext context, String filmId) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: FeedbackPanel(filmId: filmId),
    ),
  ),
);

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.film, required this.onPlay});
  final Film film;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final url = context.watch<MovieInfoStore>()[film.id]?.backdropUrl();
    Widget fallback() => FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: Poster(film, width: 320, height: 460, radius: 0));
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            fallback()
          else
            ExcludeSemantics(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: SceneColors.panel),
                errorWidget: (_, _, _) => fallback(),
              ),
            ),
          if (onPlay != null)
            Center(
              child: IconButton(
                tooltip: 'Play the trailer',
                iconSize: 56,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  side: const BorderSide(color: Colors.white70, width: 2),
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                onPressed: onPlay,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFF404040), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: const TextStyle(color: SceneColors.ink, fontSize: 14)),
  );
}

/// Tabs with the red bar above the selected one.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.labels, required this.onSelect});
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: SceneColors.line, width: 2)),
    ),
    child: Row(
      children: [
        for (final (i, label) in labels.indexed)
          Flexible(
            child: Semantics(
              selected: i == selected,
              button: true,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: i == selected ? SceneColors.red : Colors.transparent, width: 4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: i == selected ? SceneColors.ink : SceneColors.sage),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _MoreLikeThis extends StatelessWidget {
  const _MoreLikeThis({required this.films});
  final List<Film> films;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = (c.maxWidth - 16) / 3;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in films)
            Semantics(
              button: true,
              label: '${f.title}, ${f.year}. Open.',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => openTitle(context, f, 'more-like-this'),
                  child: Poster(f, width: w, height: w * 1.45),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Why It Fits: the three-part explanation (RFC §8), the reading's age and a
/// new check-in, the weights that went in, and feedback.
class _WhyItFits extends StatelessWidget {
  const _WhyItFits({required this.r, required this.picks});
  final Recommendation r;
  final Picks picks;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = picks.explanation(r, withRank: true);
    final w = r.weights;
    final CurrentState? state = w.usesState ? picks.state : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Why this movie?', style: t.headlineSmall),
        const SizedBox(height: 8),
        Text(e.headline, style: t.bodyLarge),
        const SizedBox(height: 18),
        _Reason(icon: Icons.person_outline, title: 'Your taste', text: e.taste),
        _Reason(
          icon: Icons.favorite_border,
          title: 'Right now',
          text: e.rightNow ?? 'No current state or choice of evening was used for this pick.',
          extra: state == null
              ? const []
              : [
                  if (state.isLowConfidence) const LowConfidenceTag(),
                  if (state.capturedAt != null)
                    Text(
                      'Reading taken ${ageLabel(state.capturedAt!, context.read<SceneCubit>().now())}',
                      style: t.bodyMedium?.copyWith(color: SceneColors.sage),
                    ),
                ],
        ),
        _Reason(icon: Icons.auto_awesome_outlined, title: 'How that affected this pick', text: e.effect),
        if (state != null) ...[
          const Callout(child: Text('Synheart adds the missing context between what a person generally prefers and what may fit their present moment.')),
          const SizedBox(height: 16),
        ],
        Text('What went into the ranking', style: t.titleLarge),
        const SizedBox(height: 4),
        Text('Weights are tunable defaults, not a validated formula.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 12),
        _Factor(label: 'Taste', weight: w.taste, value: r.taste),
        if (w.usesState) _Factor(label: 'Right now (Synheart HSI)', weight: w.state, value: r.state),
        if (w.usesContext) _Factor(label: 'Your choices for tonight', weight: w.context, value: r.context),
        const SizedBox(height: 20),
        FeedbackPanel(filmId: r.film.id),
      ],
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.text, this.extra = const []});
  final IconData icon;
  final String title;
  final String text;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SceneColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(text, style: t.bodyLarge),
                ...extra,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Factor extends StatelessWidget {
  const _Factor({required this.label, required this.weight, required this.value});
  final String label;
  final double weight;
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('$label · weight ${(weight * 100).round()}%', style: t.bodyMedium)),
              Text(supportLabel(value), style: t.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          // A bar with no number: the RFC keeps percentages for the weights only.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: value, minHeight: 6, backgroundColor: SceneColors.panel, color: SceneColors.red),
          ),
        ],
      ),
    );
  }
}

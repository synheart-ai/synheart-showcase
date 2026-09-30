import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/demo_log.dart';
import '../app/movie_info_store.dart';
import '../app/scene_cubit.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';
import 'tonight_extras.dart';
import 'widgets.dart';

/// Screen 7 — Why This Movie?: *Your taste*, *Right now* and *How that
/// affected this pick*, all from the film's contribution record (RFC §8).
class WhyScreen extends StatelessWidget {
  const WhyScreen({super.key, required this.filmId});

  final String filmId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    context.watch<SceneCubit>();
    final picks = Picks.of(context.read<SceneCubit>());
    final r = picks.score(filmId);

    if (r == null) {
      return Scaffold(appBar: AppBar(), body: const PageBody(children: [Callout(child: Text('That film is not in tonight\'s list.'))]));
    }

    final e = picks.explanation(r, withRank: true);
    final f = r.film;
    final w = r.weights;
    final state = w.usesState ? picks.state : null;

    return LogOnShow(
      event: DemoEvent.explanationViewed,
      fields: {'film': f.id, 'mode': picks.mode.name},
      child: Scaffold(
        appBar: AppBar(title: const Text('Why this movie?')),
        body: PageBody(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Poster(f, width: 96, height: 138),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.title, style: t.headlineSmall),
                      const SizedBox(height: 4),
                      Text('${f.year} · ${f.runtimeMinutes} min', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                      const SizedBox(height: 4),
                      Text(f.genres.map((g) => g.label).join(' · '), style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                      const SizedBox(height: 10),
                      Text(f.logline, style: t.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Synopsis(filmId: f.id),
            Callout(title: r.fitLabel.toUpperCase(), child: Text(e.headline)),
            const SizedBox(height: 20),
            _Reason(icon: Icons.person_outline, title: 'Your taste', text: e.taste),
            _Reason(
              icon: Icons.favorite_border,
              title: 'Right now',
              text: e.rightNow ?? 'No current state or choice of evening was used for this pick.',
              // RFC §8: show the snapshot's age and offer a new check-in.
              extra: state == null
                  ? const []
                  : [
                      if (state.isLowConfidence) const LowConfidenceTag(),
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                        if (state.capturedAt != null)
                          Text('Reading taken ${ageLabel(state.capturedAt!, context.read<SceneCubit>().now())}',
                              style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
                        TextButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Check in again')),
                      ]),
                    ],
            ),
            _Reason(icon: Icons.auto_awesome_outlined, title: 'How that affected this pick', text: e.effect),
            // The plan's closing message (§10), where the demo story ends.
            if (state != null) ...[
              const Callout(
                child: Text('Synheart adds the missing context between what a person generally prefers and what may fit their present moment.'),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 12),
            Text('What went into the ranking', style: t.titleLarge),
            const SizedBox(height: 4),
            Text('Weights are tunable defaults, not a validated formula.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
            const SizedBox(height: 12),
            _Factor(label: 'Taste', weight: w.taste, value: r.taste),
            if (w.usesState) _Factor(label: 'Right now (Synheart HSI)', weight: w.state, value: r.state),
            if (w.usesContext) _Factor(label: 'Your choices for tonight', weight: w.context, value: r.context),
            const SizedBox(height: 28),
            FeedbackPanel(filmId: f.id),
          ],
        ),
      ),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              const SizedBox(height: 2),
              Text(text, style: t.bodyLarge),
              ...extra,
            ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$label · weight ${(weight * 100).round()}%', style: t.bodyMedium)),
          Text(supportLabel(value), style: t.titleMedium),
        ]),
        const SizedBox(height: 6),
        // A bar with no number: the RFC keeps percentages for the weights only.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: SceneColors.panel, color: SceneColors.ink),
        ),
      ]),
    );
  }
}

/// TMDB's synopsis and trailer, when available, with the attribution TMDB
/// requires. Nothing here affects the ranking.
class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.filmId});
  final String filmId;

  @override
  Widget build(BuildContext context) {
    final info = context.watch<MovieInfoStore>()[filmId];
    if (info == null) return const SizedBox(height: 20);
    final t = Theme.of(context).textTheme;
    final trailer = info.trailerUrl;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.overview != null) ...[
            Text('Synopsis', style: t.titleMedium),
            const SizedBox(height: 4),
            Text(info.overview!, style: t.bodyLarge),
            const SizedBox(height: 10),
          ],
          if (trailer != null)
            OutlinedButton.icon(
              onPressed: () {
                context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': filmId, 'from': 'trailer'});
                launchUrl(trailer, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Watch trailer'),
            ),
          const SizedBox(height: 6),
          const TmdbCredit(lead: 'Film data from TMDB.'),
        ],
      ),
    );
  }
}

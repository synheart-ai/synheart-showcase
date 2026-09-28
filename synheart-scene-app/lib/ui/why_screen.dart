import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/scene_cubit.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'poster.dart';
import 'theme.dart';
import 'tonight_extras.dart';
import 'widgets.dart';

/// Screen 7 — Why This Movie?: how the baseline and the current state shaped
/// the pick, with the score split into the plan's three inputs (plan §5, §8).
class WhyScreen extends StatelessWidget {
  const WhyScreen({super.key, required this.filmId});

  final String filmId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<SceneCubit>().state;
    final r = scoreFor(s, filmId);

    if (r == null) {
      return Scaffold(appBar: AppBar(), body: const PageBody(children: [Callout(child: Text('That film is not in tonight\'s list.'))]));
    }

    final e = explanationFor(s, r);
    final f = r.film;
    final withState = s.mode == RecommendationMode.tastePlusState && s.current != null;

    return Scaffold(
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
          Callout(title: f.title.toUpperCase(), child: Text(e.headline)),
          const SizedBox(height: 20),
          _Reason(icon: Icons.person_outline, title: 'Your baseline', text: e.baseline),
          if (e.context != null) _Reason(icon: Icons.favorite_border, title: 'Your current context', text: e.context!),
          _Reason(icon: Icons.auto_awesome_outlined, title: 'The recommendation', text: e.recommendation),
          const SizedBox(height: 12),
          Text('How the match was scored', style: t.titleLarge),
          const SizedBox(height: 12),
          _ScoreBar(label: 'Taste match', weight: withState ? '50%' : '100%', value: r.taste),
          if (withState) ...[
            _ScoreBar(label: 'State fit (Synheart)', weight: '35%', value: r.state),
            _ScoreBar(label: 'Context fit', weight: '15%', value: r.context),
          ],
          const Divider(height: 28),
          Row(children: [
            Expanded(child: Text('Overall match', style: t.titleMedium)),
            Flexible(child: Text(r.fitLabel, style: t.titleMedium, textAlign: TextAlign.end)),
          ]),
          const SizedBox(height: 28),
          FeedbackPanel(filmId: f.id),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

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
            ]),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.weight, required this.value});
  final String label;
  final String weight;
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$label · weight $weight', style: t.bodyMedium)),
          Text('${(value * 100).round()}%', style: t.titleMedium),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: SceneColors.panel, color: SceneColors.ink),
        ),
      ]),
    );
  }
}

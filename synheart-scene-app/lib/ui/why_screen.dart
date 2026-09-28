import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/scene_cubit.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'poster.dart';
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
          Callout(title: r.fitLabel.toUpperCase(), child: Text(e.headline)),
          const SizedBox(height: 20),
          _Reason(icon: Icons.person_outline, title: 'Your taste', text: e.taste),
          _Reason(
            icon: Icons.favorite_border,
            title: 'Right now',
            text: e.rightNow ?? 'No check-in or choice of evening was used for this pick.',
          ),
          _Reason(icon: Icons.auto_awesome_outlined, title: 'How that affected this pick', text: e.effect),
          const SizedBox(height: 12),
          Text('What went into the ranking', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Weights are tunable defaults, not a validated formula.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 12),
          _Factor(label: 'Taste', weight: w.taste, value: r.taste),
          if (w.usesState) _Factor(label: 'Right now (Synheart check-in)', weight: w.state, value: r.state),
          if (w.usesContext) _Factor(label: 'Your choices for tonight', weight: w.context, value: r.context),
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

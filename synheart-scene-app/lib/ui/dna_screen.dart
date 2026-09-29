import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../domain/taste.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 3 — Movie DNA: the baseline, stated before Synheart is involved,
/// so the demo shows the taste is the user's own (plan §1, §3).
class DnaScreen extends StatelessWidget {
  const DnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final profile = context.select((SceneCubit c) => c.state.profile);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Movie DNA')),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.push(Routes.profile), child: const Text('Build my movie profile')),
          children: const [Callout(child: Text('Build your movie profile first — Scene needs your baseline.'))],
        ),
      );
    }

    final genres = profile.rankedGenres.take(6).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Your Movie DNA'), actions: [
        TextButton(onPressed: () => context.push(Routes.editProfile), child: const Text('Edit')),
        IconButton(
          tooltip: 'Reset demo',
          icon: const Icon(Icons.restart_alt),
          onPressed: () => confirmReset(context, onReset: () {
            context.read<SceneCubit>().reset();
            context.go(Routes.welcome);
          }),
        ),
      ]),
      body: PageBody(
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Start my Synheart check-in')),
          TextButton(onPressed: () => context.push(Routes.tonight), child: const Text("Skip — see tonight's picks")),
        ]),
        children: [
          const Eyebrow('Your baseline'),
          const SizedBox(height: 6),
          Text('This is what you normally enjoy.', style: t.headlineSmall),
          const SizedBox(height: 4),
          Text('Synheart will not change it — it only helps pick what fits tonight.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 10),
          Text(
            _inputs(context.select((SceneCubit c) => c.state.answers)),
            style: t.bodyMedium?.copyWith(color: SceneColors.sage),
          ),
          const SizedBox(height: 24),
          for (final g in genres) _GenreBar(label: g.key.label, value: g.value),
          const SizedBox(height: 24),
          Text('What you respond to', style: t.titleLarge),
          const SizedBox(height: 10),
          for (final line in dnaTraits(profile))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 7, color: SceneColors.sage)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line, style: t.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The user's direct inputs, stated separately from what Scene derived from
/// them (RFC §6).
String _inputs(TasteAnswers a) {
  final notSeen = a.ratings.values.where((r) => r == Rating.notSeen).length;
  final genres = a.preferredGenres.length;
  return 'Derived from ${a.answeredCount} film${a.answeredCount == 1 ? '' : 's'} you rated'
      '${notSeen == 0 ? '' : ' ($notSeen marked "Haven\'t seen", which count for nothing)'}'
      ' and $genres genre${genres == 1 ? '' : 's'} you picked.';
}

/// The qualitative half of Movie DNA, e.g. "thought-provoking stories",
/// "moderate-to-fast pacing", "open to unfamiliar titles".
List<String> dnaTraits(TasteProfile p) {
  final lines = <String>[
    for (final e in p.rankedTraits.take(3))
      if (e.value >= 0.4) _capitalise(e.key.label),
  ];
  lines.add(p.preferredEnergy >= 0.66
      ? 'Fast-paced, high-energy films'
      : p.preferredEnergy >= 0.5
          ? 'Moderate-to-fast pacing'
          : 'Slower, more patient pacing');
  if (p.likesDarkTones >= 0.6) {
    lines.add('Darker, more intense stories');
  } else if (p.likesDarkTones <= 0.3) {
    lines.add('Lighter, warmer stories');
  }
  lines.add(p.discovery >= 0.6
      ? 'Open to unfamiliar titles'
      : p.discovery <= 0.3
          ? 'Prefers familiar favourites'
          : 'A mix of the familiar and the new');
  return lines;
}

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _GenreBar extends StatelessWidget {
  const _GenreBar({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: t.titleMedium)),
            // As in the plan (§3: "Thriller 92%"). The RFC's no-percentage rule
            // (§7) is about the match score, not the taste summary.
            Text('${(value * 100).round()}%', style: t.titleMedium),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: value, minHeight: 10, backgroundColor: SceneColors.panel, color: SceneColors.ink),
          ),
        ],
      ),
    );
  }
}

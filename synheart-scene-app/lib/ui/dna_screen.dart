import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../domain/film.dart';
import '../domain/taste.dart';
import 'nav_bar.dart';
import 'poster.dart';
import 'profile_screen.dart';
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

    final genres = profile.rankedGenres.take(7).toList();
    final answers = context.select((SceneCubit c) => c.state.answers);
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton(onPressed: () => context.push(Routes.editProfile), child: const Text('Edit')),
        IconButton(
          tooltip: 'Reset demo',
          icon: const Icon(Icons.restart_alt),
          onPressed: () => confirmReset(context, onReset: () {
            context.read<SceneCubit>().reset();
            context.go(Routes.welcome);
          }),
        ),
        const SettingsButton(),
      ]),
      body: PageBody(
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SceneColors.red, foregroundColor: Colors.white),
            onPressed: () => context.push(Routes.checkIn),
            child: const Text('Start my Synheart check-in'),
          ),
          TextButton(onPressed: () => context.go(Routes.tonight), child: const Text("Skip — see tonight's picks")),
        ]),
        children: [
          Row(children: [
            const SceneAvatar(size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('YOUR BASELINE', style: t.labelSmall?.copyWith(color: SceneColors.accent)),
                Text('Your Movie DNA', style: t.displaySmall?.copyWith(fontSize: 30)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('This is what you normally enjoy.', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Synheart will not change it — it only helps pick what fits tonight.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 6),
          Text(_inputs(answers), style: t.bodySmall),
          const SizedBox(height: 22),
          if (genres.isNotEmpty) ...[
            Text('Your top genres', style: t.titleLarge),
            const SizedBox(height: 10),
            _GenreTile(genre: genres.first.key, value: genres.first.value, wide: true),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in genres.skip(1)) SizedBox(width: w, child: _GenreTile(genre: g.key, value: g.value)),
              ]);
            }),
          ],
          const SizedBox(height: 26),
          Text('What you respond to', style: t.titleLarge),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final line in dnaTraits(profile))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: SceneColors.panel, borderRadius: BorderRadius.circular(22)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_traitIcon(line), size: 18, color: SceneColors.accent),
                  const SizedBox(width: 8),
                  Flexible(child: Text(line, style: t.bodyLarge?.copyWith(color: SceneColors.ink))),
                ]),
              ),
          ]),
        ],
      ),
    );
  }
}

IconData _traitIcon(String line) {
  final l = line.toLowerCase();
  if (l.contains('pac') || l.contains('energy')) return Icons.speed;
  if (l.contains('dark') || l.contains('intense')) return Icons.dark_mode_outlined;
  if (l.contains('light') || l.contains('warm')) return Icons.wb_sunny_outlined;
  if (l.contains('familiar') || l.contains('new') || l.contains('unfamiliar')) return Icons.explore_outlined;
  return Icons.auto_awesome_outlined;
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

/// A genre as a poster tile: art from a film of that genre, the name, the
/// percentage large, and a thin red bar.
class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.genre, required this.value, this.wide = false});
  final Genre genre;
  final double value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final film = genreFace(genre);
    final pct = '${(value * 100).round()}%';
    return Semantics(
      label: '${genre.label}, $pct',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: wide ? 150 : 112,
            child: LayoutBuilder(builder: (context, c) {
              return Stack(fit: StackFit.expand, children: [
                if (film != null)
                  FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: Poster(film, width: c.maxWidth, height: c.maxWidth * 1.48, radius: 0)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0x66000000), Color(0xF2000000)]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (wide) Text('#1 FOR YOU', style: t.labelSmall?.copyWith(color: SceneColors.accent)),
                    Text(genre.label, style: (wide ? t.headlineSmall : t.titleMedium)?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    // As in the plan (§3: "Thriller 92%"). The RFC's no-percentage
                    // rule (§7) is about the match score, not the taste summary.
                    Text(pct, style: TextStyle(color: Colors.white, fontSize: wide ? 40 : 26, fontWeight: FontWeight.w900, height: 1)),
                    const SizedBox(height: 10),
                  ]),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(value: value, minHeight: 5, backgroundColor: Colors.white24, color: SceneColors.red),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

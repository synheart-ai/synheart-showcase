import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../domain/state.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 8 — "What changed?": the same eligible catalogue ranked on taste
/// only and on taste + current state, with each film's movement and why
/// (RFC §4.8, §9.5). A result with no meaningful change says so (RFC §10).
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    context.watch<SceneCubit>();
    final picks = Picks.of(context.read<SceneCubit>());
    final c = picks.compare();

    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('What changed?')),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Do a Synheart check-in')),
          children: [
            Callout(
              child: Text(picks.isStale
                  ? 'Your last reading is too old to compare with. Connect a source for a new one.'
                  : picks.lacksEvidence
                      ? 'There is not enough signal yet to compare with — Scene is using your taste only.'
                      : 'Scene needs your baseline and a current reading to compare.'),
            ),
          ],
        ),
      );
    }

    final demo = picks.state!.source == StateSource.preset;
    return LogOnShow(
      event: DemoEvent.comparisonViewed,
      fields: {'meaningful': '${c.isMeaningful}', 'new': '${c.newCount}', 'source': picks.state!.source.name},
      child: Scaffold(
        appBar: AppBar(title: const Text('What changed?')),
        body: PageBody(
          bottom: FilledButton(
            onPressed: () {
              context.read<SceneCubit>().setMode(RecommendationMode.tastePlusState);
              context.canPop() ? context.pop() : context.go(Routes.tonight);
            },
            child: const Text('Watch with my current state'),
          ),
          children: [
            if (demo) ...[
              const Eyebrow('Demo data — not a real reading'),
              const SizedBox(height: 8),
            ],
            Text('Taste only', style: t.titleLarge),
            const SizedBox(height: 8),
            for (final (i, r) in c.tasteOnly.indexed)
              _Row(rank: i + 1, title: r.film.title, note: c.dropped.any((d) => d.film.id == r.film.id) ? 'Drops out tonight' : null),
            const SizedBox(height: 18),
            Text('Taste + current state', style: t.titleLarge),
            const SizedBox(height: 8),
            for (final change in c.changes)
              _Row(
                rank: change.after!,
                title: change.film.title,
                badge: _badge(change, c.tasteOnly.length),
                note: _why(picks, change),
                onTap: () {
                  context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': change.film.id, 'from': 'compare'});
                  context.push(Routes.why(change.film.id));
                },
              ),
            const SizedBox(height: 20),
            if (c.isMeaningful) ...[
              const Callout(title: 'Demo line', child: Text("Your preferences haven't changed. Your context has.")),
              const SizedBox(height: 12),
              const Callout(
                title: 'Closing message',
                child: Text('Synheart adds the missing context between what a person generally prefers and what may fit their present moment.'),
              ),
            ] else
              const Callout(
                title: 'No meaningful change tonight',
                child: Text(
                  'Your current context points the same way as your taste, so the same films lead. '
                  'That is a real result, not a failure — Scene does not force a change.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "↑ from #11", "new", "↓ 1", "=".
  static String _badge(RankChange c, int shown) {
    final before = c.before;
    if (before == null) return 'new';
    if (before > shown) return '↑ from #$before';
    if (c.moved > 0) return '↑ ${c.moved}';
    if (c.moved < 0) return '↓ ${-c.moved}';
    return '=';
  }

  /// Why it moved, from its contribution record.
  static String? _why(Picks picks, RankChange c) {
    final r = picks.score(c.film.id);
    if (r == null || c.moved <= 0) return null;
    return '${supportLabel(r.state)} fit for right now · ${supportLabel(r.taste).toLowerCase()} on taste';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.title, this.badge, this.note, this.onTap});

  final int rank;
  final String title;
  final String? badge;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SceneColors.line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 32, child: Text('#$rank', style: t.labelSmall)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.bodyLarge),
                if (note != null) Text(note!, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
              ]),
            ),
            if (badge != null)
              Text(
                badge!,
                semanticsLabel: _spoken(badge!),
                style: t.titleMedium?.copyWith(color: badge!.startsWith('↑') || badge == 'new' ? SceneColors.warm : SceneColors.sage),
              ),
          ],
        ),
      ),
    );
  }
}

/// What a screen reader says for a movement badge.
String _spoken(String badge) {
  if (badge == '=') return 'same place';
  if (badge == 'new') return 'new';
  if (badge.startsWith('↑ from #')) return 'moved up from number ${badge.substring(8)}';
  if (badge.startsWith('↑ ')) return 'up ${badge.substring(2)}';
  if (badge.startsWith('↓ ')) return 'down ${badge.substring(2)}';
  return badge;
}

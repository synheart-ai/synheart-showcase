import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';
import 'picks.dart';
import 'home_rows.dart';
import 'routes.dart';
import 'state_sheet.dart';
import 'theme.dart';
import 'tonight_extras.dart';
import 'nav_bar.dart';
import 'widgets.dart';

/// The home screen — Tonight's Picks as a browse home (a state-aware
/// Netflix, as Resona is a state-aware Spotify): the top pick, tonight's top
/// list and browse rows, under the key demo toggle BASED ON TASTE ⇄ TASTE +
/// CURRENT STATE (plan §5, §6).
class TonightScreen extends StatelessWidget {
  const TonightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SceneCubit>().state;
    final cubit = context.read<SceneCubit>();

    if (s.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tonight's picks")),
        body: PageBody(
          bottom: FilledButton(onPressed: () => context.push(Routes.profile), child: const Text('Build my movie profile')),
          children: const [Callout(child: Text('Scene needs your movie profile first.'))],
        ),
      );
    }

    final picks = Picks.of(cubit);
    final list = picks.list();
    final current = picks.state;
    final at = s.current?.capturedAt;

    // The demo line only when the state really changed the list; a reorder of
    // the same films is said plainly (RFC §10: no forced change).
    final meaningful = picks.withState && (picks.compare()?.isMeaningful ?? false);
    final demoSuffix = [
      if (current?.source == StateSource.preset) ' (Demo data — not a real reading.)',
      if (picks.withState && current!.isLowConfidence) ' Based on a low-confidence reading.',
    ].join();
    final String note;
    if (picks.withState) {
      note = meaningful ? '' : 'Tonight\'s state barely changes your list — your taste already fits it.$demoSuffix';
    } else if (picks.isStale) {
      note = 'Taste only. Your last reading, from ${ageLabel(at!, cubit.now())}, is too old to use.';
    } else if (picks.lacksEvidence) {
      note = 'Taste only. There is not enough signal yet to say what fits right now — this is not a negative result.';
    } else if (current == null) {
      note = 'Taste only. No current state was used — connect a source to see what fits right now.';
    } else {
      note = 'Taste only — the way a conventional recommender would.';
    }

    return LogOnShow(
      event: DemoEvent.recommendationsViewed,
      fields: {'mode': picks.mode.name, 'stale': '${picks.isStale}'},
      child: Scaffold(
        // The logo mark in place of a long title: at 390 pt the back arrow,
        // Settings and the state pill leave little room (a title was once
        // squeezed to 30 pt, 1:1 contrast). Movie DNA is in the bottom bar.
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(children: [
            Image.asset('assets/scene_mark.png', height: 34, semanticLabel: 'Scene'),
            const SizedBox(width: 12),
            const Flexible(child: Text('Tonight', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          actions: const [
            SettingsButton(),
            Padding(padding: EdgeInsets.only(right: 12), child: StatePill()),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: const SceneNavBar(current: SceneTab.home),
        body: PageBody(
          bottom: !picks.hasUsableState
              ? FilledButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Do a Synheart check-in'))
              : OutlinedButton(onPressed: () => context.push(Routes.compare), child: const Text('What changed? Compare side by side')),
          children: [
            // The key demo toggle, as the chip row under a cinema app's header.
            // Only the state chip is disabled without a usable reading; its
            // text stays at 4.5:1 or better.
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ModeChip(label: 'BASED ON TASTE', selected: picks.mode == RecommendationMode.tasteOnly, onTap: () => cubit.setMode(RecommendationMode.tasteOnly)),
              _ModeChip(
                label: 'TASTE + CURRENT STATE',
                selected: picks.mode == RecommendationMode.tastePlusState,
                onTap: picks.hasUsableState ? () => cubit.setMode(RecommendationMode.tastePlusState) : null,
              ),
            ]),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: meaningful
                  ? Callout(
                      key: const ValueKey('changed'),
                      title: "Your preferences haven't changed.",
                      child: Text('Your context has.$demoSuffix'),
                    )
                  : Callout(key: ValueKey(note), child: Text(note)),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Column(
                key: ValueKey('${picks.mode}-$current-${s.viewing}-${s.hiddenFilmIds.length}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (list.isEmpty)
                    const Callout(child: Text('Nothing fits these filters — try removing one.'))
                  else ...[
                    HeroPick(recommendation: list.first, headline: picks.explanation(list.first).headline),
                    const SizedBox(height: 22),
                    Text("Tonight's top ${list.length}", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    TopRow(picks: list),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            const ChooseMyEvening(),
            BrowseRows(withState: picks.withState, exclude: {for (final r in list) r.film.id}),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: onTap == null ? SceneColors.sage : (selected ? SceneColors.paper : SceneColors.ink),
        ),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF808080))),
        onSelected: onTap == null ? null : (_) => onTap!(),
      );
}

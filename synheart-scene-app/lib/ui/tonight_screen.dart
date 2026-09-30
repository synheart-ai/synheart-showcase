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
        // No title: at 390 pt the back arrow, Movie DNA, Settings and the state
        // pill leave a title no room (it was squeezed to 30 pt, 1:1 contrast).
        // The page itself starts with "#1 TONIGHT".
        appBar: AppBar(
          actions: [
            IconButton(tooltip: 'Movie DNA', icon: const Icon(Icons.person_outline), onPressed: () => context.push(Routes.dna)),
            const SettingsButton(),
            const Padding(padding: EdgeInsets.only(right: 12), child: StatePill()),
          ],
        ),
        body: PageBody(
          bottom: !picks.hasUsableState
              ? FilledButton(onPressed: () => context.push(Routes.checkIn), child: const Text('Do a Synheart check-in'))
              : OutlinedButton(onPressed: () => context.push(Routes.compare), child: const Text('What changed? Compare side by side')),
          children: [
            SegmentedButton<RecommendationMode>(
              showSelectedIcon: false,
              // Disabled text stays at 4.5:1 (sage), so it is still readable.
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.disabled) ? SceneColors.sage : null),
              ),
              segments: [
                const ButtonSegment(value: RecommendationMode.tasteOnly, label: Text('BASED ON TASTE')),
                ButtonSegment(value: RecommendationMode.tastePlusState, label: const Text('TASTE + CURRENT STATE'), enabled: picks.hasUsableState),
              ],
              selected: {picks.mode},
              // Only the state segment is disabled without a usable reading, so
              // the active one keeps full contrast.
              onSelectionChanged: (m) => cubit.setMode(m.first),
            ),
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

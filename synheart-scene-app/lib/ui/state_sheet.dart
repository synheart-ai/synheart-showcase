import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../app/state_engine.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import 'routes.dart';
import 'theme.dart';

/// The state pill and sheet, as in Resona: the current state stays one tap
/// away from browsing, and source setup lives in Settings (RFC §4.5).
class StatePill extends StatelessWidget {
  const StatePill({super.key});

  @override
  Widget build(BuildContext context) {
    final view = StateView.of(context);
    return Semantics(
      button: true,
      label: 'Current state: ${view.label}. Opens details.',
      child: ExcludeSemantics(
        child: ActionChip(
          avatar: Icon(view.icon, size: 16, color: SceneColors.ink),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(view.pill, overflow: TextOverflow.ellipsis),
          ),
          onPressed: () => showStateSheet(context),
        ),
      ),
    );
  }
}

Future<void> showStateSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StateSheet(),
    );

/// What to say about the current state, from the cubit's reading and the
/// engine's live status.
class StateView {
  StateView({required this.label, String? pill, required this.headline, required this.message, required this.icon, this.reading, this.stale = false})
      : pill = pill ?? label;

  final String label;

  /// One or two words for the pill, so the app-bar title keeps its room.
  final String pill;
  final String headline;
  final String message;
  final IconData icon;

  /// The reading Scene is ranking with, if any.
  final CurrentState? reading;
  final bool stale;

  static StateView of(BuildContext context) {
    final cubit = context.watch<SceneCubit>();
    final engine = context.watch<SceneStateEngine>();
    final current = cubit.state.current;
    final fresh = cubit.freshState;

    if (engine.display == DisplayState.settling) {
      return StateView(
          label: 'Signal settling',
          pill: 'Settling',
          headline: 'Your signal is settling',
          message: 'Movement is affecting the reading. Stay still for a moment.',
          icon: Icons.hourglass_empty,
          reading: fresh);
    }
    if (fresh != null && fresh.hasEvidence) {
      final need = fresh.suggestedExperience;
      return need == null
          ? StateView(
              label: 'No clear need',
              pill: 'No clear need',
              headline: 'Nothing stands out tonight',
              message: 'Your picks follow your taste, nudged a little by what Synheart sees.',
              icon: Icons.remove_red_eye_outlined,
              reading: fresh)
          : StateView(label: need.label, headline: need.headline, message: need.message, icon: Icons.favorite, reading: fresh);
    }
    return switch (engine.display) {
      DisplayState.listening => StateView(
          label: 'Listening', headline: 'We’re listening to your rhythm', message: 'Scene is learning your current rhythm.', icon: Icons.graphic_eq),
      DisplayState.notEnoughEvidence || DisplayState.noClearNeed => StateView(
          label: 'Not enough signal',
          pill: 'Weak signal',
          headline: 'Not enough signal yet',
          message: 'Scene will use your taste until the reading is clearer. This is not a negative result.',
          icon: Icons.signal_cellular_alt_1_bar),
      _ => current != null && current.hasEvidence
          ? StateView(
              label: 'Reading too old',
              pill: 'Too old',
              headline: 'Your last reading is too old to use',
              message: 'Picks are on taste only. Connect a source or use demo data for a new reading.',
              icon: Icons.history,
              reading: current,
              stale: true)
          : StateView(
              label: current != null ? 'Not enough signal' : 'No current state',
              pill: current != null ? 'Weak signal' : 'No state',
              headline: current != null ? 'Not enough signal' : 'No current state',
              message: current != null
                  ? 'The reading was not confident enough to use. Picks are on taste only.'
                  : 'Picks are on taste only. Connect a wearable in Settings, or use demo data.',
              icon: Icons.favorite_border),
    };
  }
}

/// Words for an axis value — never a raw number (Resona: no medical scores).
String levelWord(double v) => v < 0.36 ? 'lower' : (v < 0.66 ? 'moderate' : 'higher');

class _StateSheet extends StatelessWidget {
  const _StateSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final view = StateView.of(context);
    final cubit = context.read<SceneCubit>();
    final engine = context.watch<SceneStateEngine>();
    final viewing = context.select((SceneCubit c) => c.state.viewing);
    final reading = view.reading;
    final suggested = view.stale ? null : reading?.suggestedExperience?.suggestedIntent;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text('CURRENT STATE', style: t.labelSmall)),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.settings);
                },
              ),
            ]),
            Icon(view.icon, size: 40, color: SceneColors.ink),
            const SizedBox(height: 10),
            Text(view.headline, style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(view.message, style: t.bodyLarge?.copyWith(color: SceneColors.sage), textAlign: TextAlign.center),
            if (reading != null) ...[
              const SizedBox(height: 14),
              Text(
                '${reading.source.label}${reading.capturedAt == null ? '' : ' · ${ageLabel(reading.capturedAt!, cubit.now())}'}',
                style: t.bodyMedium?.copyWith(color: view.stale ? SceneColors.warm : SceneColors.sage),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    for (final a in HsiAxis.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(child: Text(a.label, style: t.titleMedium)),
                          Text(
                            reading.valueOf(a) == null ? 'not available' : levelWord(reading.valueOf(a)!),
                            style: t.titleMedium?.copyWith(color: SceneColors.sage),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
            ],
            if (engine.isLive && engine.heartRate != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Chip(avatar: const Icon(Icons.favorite, size: 16), label: Text('${engine.heartRate!.round()} BPM · live')),
              ),
            ],
            const SizedBox(height: 18),
            Text('What kind of evening?', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              suggested == null
                  ? 'Choose one, or leave it to your taste.'
                  : 'Suggested: ${suggested.label}. Your choice always wins over the suggestion — or skip it.',
              style: t.bodyMedium?.copyWith(color: SceneColors.sage),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final intent in EveningIntent.values)
                ChoiceChip(
                  label: Text(intent == suggested ? '${intent.label} (suggested)' : intent.label),
                  selected: viewing.intent == intent,
                  onSelected: (on) => cubit.setIntent(on ? intent : null),
                ),
              ChoiceChip(label: const Text('No preference'), selected: viewing.intent == null, onSelected: (_) => cubit.setIntent(null)),
            ]),
            const SizedBox(height: 18),
            Text(
              'Focus, stress, arousal and capacity are computed on this device by Synheart. They are not a diagnosis.',
              style: t.bodyMedium?.copyWith(color: SceneColors.sage),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text("See tonight's picks")),
          ],
        ),
      ),
    );
  }
}

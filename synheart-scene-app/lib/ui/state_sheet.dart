import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../app/state_engine.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import 'check_in_parts.dart';
import 'routes.dart';
import 'state_card.dart';
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
      // A thin reading keeps its short pill, but says so to screen readers and
      // in the sheet (RFC §8: tentative about inferred context).
      final low = fresh.isLowConfidence ? ' (low confidence)' : '';
      final lowNote = fresh.isLowConfidence ? ' Synheart is not sure about this reading, so treat it lightly.' : '';
      return need == null
          ? StateView(
              label: 'Balanced$low',
              pill: 'Balanced',
              headline: 'You seem balanced',
              message: 'Nothing stands out right now, so your picks follow your taste, nudged a little by what Synheart sees.$lowNote',
              icon: Icons.remove_red_eye_outlined,
              reading: fresh)
          : StateView(
              label: '${need.label}$low',
              pill: need.label,
              headline: need.headline,
              message: '${need.message}$lowNote',
              icon: Icons.favorite,
              reading: fresh);
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

class _StateSheet extends StatelessWidget {
  const _StateSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final view = StateView.of(context);
    final cubit = context.read<SceneCubit>();
    final engine = context.watch<SceneStateEngine>();
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
              StateCard(reading: reading),
            ],
            if (engine.isLive && engine.heartRate != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Chip(avatar: const Icon(Icons.favorite, size: 16), label: Text('${engine.heartRate!.round()} BPM · live')),
              ),
            ],
            const SizedBox(height: 18),
            IntentChoice(suggested: suggested),
            const SizedBox(height: 18),
            Text(
              'Computed on this device by Synheart. These are contextual signals, not a diagnosis.',
              style: t.bodyMedium?.copyWith(color: SceneColors.sage),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.checkIn);
              },
              child: Text(view.reading == null || view.stale ? 'Do a Synheart check-in' : 'Check in again'),
            ),
            const SizedBox(height: 6),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text("See tonight's picks")),
          ],
        ),
      ),
    );
  }
}

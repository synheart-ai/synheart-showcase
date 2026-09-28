import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/demo_log.dart';
import '../app/scene_cubit.dart';
import '../domain/state.dart';
import '../engine/collections.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';

/// "Choose My Evening" — explicit intent plus the 90-minute filter, in both
/// modes. The user's choice takes precedence over the check-in (RFC §4).
class ChooseMyEvening extends StatelessWidget {
  const ChooseMyEvening({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final viewing = context.select((SceneCubit c) => c.state.viewing);
    final cubit = context.read<SceneCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose my evening', style: t.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final intent in EveningIntent.values)
              ChoiceChip(
                label: Text(intent.label),
                selected: viewing.intent == intent,
                onSelected: (on) => cubit.setIntent(on ? intent : null),
              ),
            FilterChip(
              label: const Text('90 minutes or less'),
              selected: viewing.maxRuntimeMinutes != null,
              onSelected: cubit.setShortOnly,
            ),
          ],
        ),
      ],
    );
  }
}

/// The state-aware collections as horizontal rows of posters (§7).
class StateCollections extends StatelessWidget {
  const StateCollections({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<SceneCubit>().state;
    final profile = s.profile;
    final current = context.read<SceneCubit>().freshState;
    if (profile == null || current == null) return const SizedBox.shrink();

    final collections = buildCollections(profile, state: current, context: s.viewing, hidden: s.hiddenFilmIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in collections.entries)
          if (entry.value.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(entry.key.title, style: t.titleLarge),
            Text(entry.key.subtitle, style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
            const SizedBox(height: 10),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entry.value.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final f = entry.value[i];
                  return Semantics(
                    button: true,
                    label: '${f.title}, ${f.year}. Why this movie?',
                    child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      context.read<SceneCubit>().log.record(DemoEvent.filmSelected, {'film': f.id, 'from': entry.key.name});
                      context.push(Routes.why(f.id));
                    },
                    child: Poster(f, width: 88, height: 128),
                  ),
                  );
                },
              ),
            ),
          ],
      ],
    );
  }
}

/// Lightweight feedback after a recommendation, with optional reasons (§7).
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.filmId});

  final String filmId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final given = context.select((SceneCubit c) => c.state.feedback[filmId]);
    final cubit = context.read<SceneCubit>();
    final negative = given != null && (given.$1 == Feedback.notReally || given.$1 == Feedback.wrongForMe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How was this pick?', style: t.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in Feedback.values)
              ChoiceChip(
                label: Text(f.label),
                selected: given?.$1 == f,
                onSelected: (_) => cubit.giveFeedback(filmId, f, reasons: given?.$1 == f ? given!.$2 : const {}),
              ),
          ],
        ),
        if (negative) ...[
          const SizedBox(height: 14),
          Text('Anything specific? (optional)', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in feedbackReasons)
                FilterChip(
                  label: Text(reason),
                  selected: given.$2.contains(reason),
                  onSelected: (on) {
                    final reasons = {...given.$2};
                    on ? reasons.add(reason) : reasons.remove(reason);
                    cubit.giveFeedback(filmId, given.$1, reasons: reasons);
                  },
                ),
            ],
          ),
        ],
        if (given != null) ...[
          const SizedBox(height: 12),
          Text(
            context.read<SceneCubit>().state.hiddenFilmIds.contains(filmId)
                ? 'Thanks — Scene will not suggest this film again.'
                : 'Thanks — noted.',
            style: t.bodyMedium?.copyWith(color: SceneColors.sage),
          ),
        ],
      ],
    );
  }
}

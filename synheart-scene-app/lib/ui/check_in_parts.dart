import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/scene_cubit.dart';
import '../domain/state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Consent before any collection (RFC §4.4, §6), shared by the check-in and
/// Settings. The wording claims only what the configuration guarantees.
class ConsentCard extends StatelessWidget {
  const ConsentCard({super.key, required this.onAgree, required this.onSkip, this.busy = false, this.error});

  final VoidCallback onAgree;
  final VoidCallback onSkip;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('Before we start'),
        const SizedBox(height: 6),
        Text('Let Scene read your current state', style: t.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Synheart reads your heart rate and how you use your phone to suggest films that may fit right now. '
          'Nothing is collected until you agree.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 16),
        const _Point(icon: Icons.favorite_border, title: 'What is read', text: 'Heart rate from the one source you choose, and heart-rate variability when it provides it. The Galaxy Watch sends heart rate only.'),
        const _Point(
          icon: Icons.touch_app_outlined,
          title: 'How you use your phone',
          text: 'Taps, scrolls and swipes in Scene; when you switch apps; notification and call events (never their content, sender or number); and phone motion. No typing, no text.',
        ),
        const _Point(
          icon: Icons.timer_outlined,
          title: 'When',
          text: 'All the time after you agree, also when Scene is in the background, with an ongoing notification. Withdraw consent in Settings to stop.',
        ),
        const _Point(
          icon: Icons.phone_iphone,
          title: 'Where',
          text: 'Synheart computes your state on this device. Cloud upload is off.',
        ),
        const _Point(
          icon: Icons.visibility_outlined,
          title: 'What you see',
          text: 'Plain words — energy, mental load, engagement — not medical scores. Uncertain readings are marked low confidence.',
        ),
        const _Point(icon: Icons.history, title: 'What is kept', text: 'Only the result and its time, until you reset the demo.'),
        const _Point(
          icon: Icons.movie_outlined,
          title: 'Film data',
          text: 'Posters, synopses and trailers come from TMDB and YouTube over the internet. No health data is sent with them.',
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Callout(title: 'Synheart could not start', child: Text(error!)),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: busy ? null : onAgree, child: Text(busy ? 'Starting Synheart…' : 'I agree — continue')),
        TextButton(onPressed: onSkip, child: const Text('Not now — use my taste only')),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SceneColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium),
              Text(text, style: t.bodyMedium),
            ]),
          ),
        ],
      ),
    );
  }
}

/// "What kind of evening?" — the suggested intent to accept, change or skip
/// (RFC §4.5). The user's choice always wins over the suggestion.
class IntentChoice extends StatelessWidget {
  const IntentChoice({super.key, this.suggested});

  final EveningIntent? suggested;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<SceneCubit>();
    final viewing = context.select((SceneCubit c) => c.state.viewing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What kind of evening?', style: t.titleLarge),
        const SizedBox(height: 4),
        Text(
          suggested == null
              ? 'Choose one, or leave it to your taste.'
              : 'Suggested: ${suggested!.label}. Your choice always wins over the suggestion — or skip it.',
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
      ],
    );
  }
}

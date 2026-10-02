import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/scene_cubit.dart';
import '../data/catalogue.dart';
import '../domain/taste.dart';
import 'profile_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Edit the baseline without starting over (RFC §4.3, §9.2). These are the
/// user's direct inputs; the Movie DNA is rebuilt from them on every change.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ratings = context.select((SceneCubit c) => c.state.answers.ratings);
    final cubit = context.read<SceneCubit>();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit your baseline')),
      body: PageBody(
        bottom: FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Done')),
        children: [
          Text('Your ratings', style: t.titleLarge),
          const SizedBox(height: 4),
          Text('Tap a rating again to clear it. "Haven\'t seen" never counts against a film.',
              style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
          const SizedBox(height: 12),
          for (final f in onboardingFilms) ...[
            Text('${f.title} (${f.year})', style: t.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in Rating.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: ratings[f.id] == r,
                    onSelected: (on) => on ? cubit.rate(f.id, r) : cubit.clearRating(f.id),
                  ),
              ],
            ),
            const Divider(height: 24),
          ],
          const SizedBox(height: 8),
          const PreferenceControls(),
        ],
      ),
    );
  }
}

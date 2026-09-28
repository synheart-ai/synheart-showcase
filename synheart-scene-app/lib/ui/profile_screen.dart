import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../app/scene_cubit.dart';
import '../data/catalogue.dart';
import '../domain/film.dart';
import '../domain/taste.dart';
import 'poster.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Screen 2 — Build Movie Profile: rate a curated set of films, then pick
/// favourite genres and set Familiar ↔ Surprise me (plan §3).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _index = 0;

  bool get _rating => _index < onboardingFilms.length;

  void _answer(Rating r) {
    context.read<SceneCubit>().rate(onboardingFilms[_index].id, r);
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _index == 0 ? context.go(Routes.welcome) : setState(() => _index--),
        ),
        title: Text(_rating ? 'Build your movie profile' : 'Your preferences'),
      ),
      body: _rating
          ? _RateFilm(
              index: _index,
              onAnswer: _answer,
              onSkipFilm: () {
                context.read<SceneCubit>().clearRating(onboardingFilms[_index].id);
                setState(() => _index++);
              },
              onSkipRest: () => setState(() => _index = onboardingFilms.length),
            )
          : const _Preferences(),
    );
  }
}

class _RateFilm extends StatelessWidget {
  const _RateFilm({required this.index, required this.onAnswer, required this.onSkipFilm, required this.onSkipRest});

  final int index;
  final ValueChanged<Rating> onAnswer;
  final VoidCallback onSkipFilm;
  final VoidCallback onSkipRest;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final film = onboardingFilms[index];
    final answered = context.select((SceneCubit c) => c.state.answers.answeredCount);
    final total = onboardingFilms.length;

    return PageBody(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _AnswerButton(Rating.love, onAnswer, icon: Icons.favorite)),
              const SizedBox(width: 10),
              Expanded(child: _AnswerButton(Rating.like, onAnswer, icon: Icons.thumb_up_alt_outlined)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _AnswerButton(Rating.notForMe, onAnswer, icon: Icons.thumb_down_alt_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _AnswerButton(Rating.notSeen, onAnswer, icon: Icons.visibility_off_outlined)),
            ],
          ),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: onSkipFilm, child: const Text('Skip this film'))),
              Expanded(
                child: TextButton(
                  onPressed: onSkipRest,
                  child: Text(answered >= 8 ? 'That\'s enough — $answered rated' : 'Skip the rest'),
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        Text('${index + 1} of $total', style: t.labelSmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: index / total, minHeight: 4, backgroundColor: SceneColors.line, color: SceneColors.ink),
        ),
        const SizedBox(height: 28),
        Center(child: Poster(film, width: 180, height: 260)),
        const SizedBox(height: 20),
        Text(film.title, style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('${film.year} · ${film.genres.map((g) => g.label).join(' · ')}', style: t.bodyMedium?.copyWith(color: SceneColors.sage), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(film.logline, style: t.bodyLarge, textAlign: TextAlign.center),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton(this.rating, this.onAnswer, {required this.icon});

  final Rating rating;
  final ValueChanged<Rating> onAnswer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final primary = rating == Rating.love || rating == Rating.like;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        // Flexible: "Haven't seen" overflowed at 390 pt phone width.
        Flexible(child: Text(rating.label, textAlign: TextAlign.center)),
      ],
    );
    return primary
        ? FilledButton(onPressed: () => onAnswer(rating), child: child)
        : OutlinedButton(onPressed: () => onAnswer(rating), child: child);
  }
}

class _Preferences extends StatelessWidget {
  const _Preferences();

  @override
  Widget build(BuildContext context) {
    final answers = context.select((SceneCubit c) => c.state.answers);
    final cubit = context.read<SceneCubit>();

    return PageBody(
      bottom: FilledButton(
        // Every preference is optional (RFC §9.1): the baseline is built from
        // whatever was answered.
        onPressed: () {
          cubit.completeProfile();
          context.go(Routes.dna);
        },
        child: const Text('See my Movie DNA'),
      ),
      children: [
        const PreferenceControls(),
        if (answers.answeredCount == 0 && answers.preferredGenres.isEmpty) ...[
          const SizedBox(height: 20),
          const Callout(
            child: Text('You have not rated any films or picked genres, so your baseline will be broad. You can edit it later from Movie DNA.'),
          ),
        ],
      ],
    );
  }
}

/// Favourite genres and Familiar ↔ Surprise me — used in onboarding and when
/// editing the baseline.
class PreferenceControls extends StatelessWidget {
  const PreferenceControls({super.key});

  static const _pickable = [
    Genre.thriller, Genre.mystery, Genre.crime, Genre.sciFi, Genre.drama, Genre.comedy,
    Genre.action, Genre.adventure, Genre.romance, Genre.horror, Genre.animation, Genre.documentary,
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final answers = context.select((SceneCubit c) => c.state.answers);
    final cubit = context.read<SceneCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Which genres do you usually reach for?', style: t.titleLarge),
        const SizedBox(height: 4),
        Text('Pick as many as you like — or none.', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in _pickable)
              FilterChip(label: Text(g.label), selected: answers.preferredGenres.contains(g), onSelected: (_) => cubit.toggleGenre(g)),
          ],
        ),
        const SizedBox(height: 32),
        Text('Familiar or surprising?', style: t.titleLarge),
        const SizedBox(height: 4),
        Text('How far should Scene stray from what you already know?', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        Slider(
          value: answers.discovery,
          onChanged: cubit.setDiscovery,
          divisions: 4,
          label: _discoveryLabel(answers.discovery),
          semanticFormatterCallback: _discoveryLabel,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Familiar', style: t.bodyMedium),
            Text('Surprise me', style: t.bodyMedium),
          ],
        ),
      ],
    );
  }

  static String _discoveryLabel(double v) => v < 0.25
      ? 'Familiar'
      : v < 0.5
          ? 'Mostly familiar'
          : v < 0.75
              ? 'A bit of both'
              : 'Surprise me';
}

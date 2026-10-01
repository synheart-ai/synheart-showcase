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

  void _leave(BuildContext context) => context.canPop() ? context.pop() : context.go(Routes.welcome);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _index == 0 ? _leave(context) : setState(() => _index--),
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

/// One film at a time, as a streaming app's "rate what you've seen": the
/// poster large, then Not for me / Like it / Love it as round thumbs, and
/// Haven't seen it.
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
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Thumb(Rating.notForMe, onAnswer, icon: Icons.thumb_down_alt_outlined)),
            Expanded(child: _Thumb(Rating.like, onAnswer, icon: Icons.thumb_up_alt_outlined)),
            Expanded(child: _Thumb(Rating.love, onAnswer, icon: Icons.favorite, highlight: true)),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => onAnswer(Rating.notSeen),
            icon: const Icon(Icons.visibility_off_outlined),
            label: Text(Rating.notSeen.label),
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
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: index / total, minHeight: 4, backgroundColor: SceneColors.line, color: SceneColors.red),
            ),
          ),
          const SizedBox(width: 12),
          Text('${index + 1} of $total', style: t.labelSmall),
        ]),
        const SizedBox(height: 22),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x99DC1929), blurRadius: 40, spreadRadius: -12)],
            ),
            child: Poster(film, width: 200, height: 296, radius: 10),
          ),
        ),
        const SizedBox(height: 20),
        Text(film.title, style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('${film.year}  ·  ${film.genres.map((g) => g.label).join(', ')}', style: t.bodyMedium?.copyWith(color: SceneColors.sage), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(film.logline, style: t.bodyLarge, textAlign: TextAlign.center),
      ],
    );
  }
}

/// A round thumb with its label under it.
class _Thumb extends StatelessWidget {
  const _Thumb(this.rating, this.onAnswer, {required this.icon, this.highlight = false});

  final Rating rating;
  final ValueChanged<Rating> onAnswer;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: rating.label,
        child: ExcludeSemantics(
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onAnswer(rating),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: highlight ? SceneColors.red : SceneColors.panel,
                    border: Border.all(color: highlight ? SceneColors.red : const Color(0xFF555555), width: 1.5),
                  ),
                  child: Icon(icon, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(rating.label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
              ]),
            ),
          ),
        ),
      );
}

class _Preferences extends StatelessWidget {
  const _Preferences();

  @override
  Widget build(BuildContext context) {
    final answers = context.select((SceneCubit c) => c.state.answers);
    final cubit = context.read<SceneCubit>();

    return PageBody(
      bottom: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: SceneColors.red, foregroundColor: Colors.white),
        // Every preference is optional (RFC §9.1): the baseline is built from
        // whatever was answered.
        onPressed: () {
          cubit.completeProfile();
          // Replace: Back from Movie DNA goes to Welcome, not into the ratings.
          context.pushReplacement(Routes.dna);
        },
        child: const Text('See my Movie DNA'),
      ),
      children: [
        // Before the picks, so it is read first.
        if (answers.answeredCount == 0 && answers.preferredGenres.isEmpty) ...[
          const Callout(
            child: Text('You have not rated any films or picked genres, so your baseline will be broad. You can edit it later from Movie DNA.'),
          ),
          const SizedBox(height: 20),
        ],
        const PreferenceControls(),
      ],
    );
  }
}

/// A film that stands for a genre on its tile: the first catalogue film
/// whose first genre it is, else any film with it.
Film? genreFace(Genre g) {
  for (final f in candidateFilms) {
    if (f.genres.first == g) return f;
  }
  for (final f in allFilms) {
    if (f.genres.contains(g)) return f;
  }
  return null;
}

/// Favourite genres as poster tiles (a red border and check when picked) and
/// Familiar ↔ Surprise me — used in onboarding and when editing the
/// baseline.
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
    final picked = answers.preferredGenres.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Which genres do you usually reach for?', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text(picked == 0 ? 'Pick as many as you like — or none.' : '$picked picked', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 16) / 3;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in _pickable) _GenreTile(genre: g, film: genreFace(g), width: w, selected: answers.preferredGenres.contains(g), onTap: () => cubit.toggleGenre(g)),
          ]);
        }),
        const SizedBox(height: 32),
        Text('Familiar or surprising?', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('How far should Scene stray from what you already know?', style: t.bodyMedium?.copyWith(color: SceneColors.sage)),
        const SizedBox(height: 14),
        Center(child: Text(_discoveryLabel(answers.discovery), style: t.titleLarge?.copyWith(color: SceneColors.accent))),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: SceneColors.red,
            inactiveTrackColor: SceneColors.line,
            thumbColor: Colors.white,
            overlayColor: SceneColors.red.withValues(alpha: 0.2),
            activeTickMarkColor: Colors.white54,
            inactiveTickMarkColor: Colors.white24,
            trackHeight: 4,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: answers.discovery,
            onChanged: cubit.setDiscovery,
            divisions: 4,
            semanticFormatterCallback: _discoveryLabel,
          ),
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

class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.genre, required this.film, required this.width, required this.selected, required this.onTap});

  final Genre genre;
  final Film? film;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.25;
    return Semantics(
      button: true,
      selected: selected,
      label: genre.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? SceneColors.red : Colors.transparent, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(fit: StackFit.expand, children: [
                if (film != null) FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: Poster(film!, width: width, height: width * 1.48, radius: 0)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: selected ? 0.15 : 0.35), Colors.black.withValues(alpha: 0.92)],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(genre.label, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(radius: 13, backgroundColor: SceneColors.red, child: Icon(Icons.check, size: 18, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

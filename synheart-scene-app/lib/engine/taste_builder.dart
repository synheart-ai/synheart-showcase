import '../data/catalogue.dart';
import '../domain/film.dart';
import '../domain/taste.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// Builds the user's baseline ("Movie DNA") from their onboarding answers.
///
/// Rules, kept deliberately simple and explainable:
/// * **Genre affinity** — each rated film votes for its genres with the
///   rating's weight (Love +1, Like +0.6, Not for me −0.8). A genre's mean
///   vote is blended with a prior (higher for genres the user picked),
///   trusted fully only once three films informed it, and picked genres get
///   a small boost. Capped below 100% — a baseline is never certain.
/// * **Traits** — the same votes, normalised to the strongest trait.
/// * **Preferred intensity / cognitive load / energy** — the weighted average
///   of the films the user loved or liked.
/// * **Dark tones** — the share of positive votes that went to dark, tense or
///   heavy films.
/// A genre's affinity with no evidence either way: not picked, no rated
/// film. Movie DNA shows only genres above it.
const neutralGenreAffinity = 0.4;

TasteProfile buildTasteProfile(TasteAnswers answers, {List<Film> films = onboardingFilms}) {
  final byId = {for (final f in films) f.id: f};
  final genreVotes = <Genre, List<double>>{};
  final traitVotes = <Trait, double>{};
  var positiveWeight = 0.0;
  var darkWeight = 0.0;
  var intensitySum = 0.0, cognitiveSum = 0.0, energySum = 0.0;

  answers.ratings.forEach((id, rating) {
    final film = byId[id];
    final w = rating.weight;
    if (film == null || w == 0) return;
    for (final g in film.genres) {
      genreVotes.putIfAbsent(g, () => []).add(w);
    }
    for (final t in film.traits) {
      traitVotes[t] = (traitVotes[t] ?? 0) + w;
    }
    if (w > 0) {
      positiveWeight += w;
      intensitySum += film.intensity * w;
      cognitiveSum += film.cognitiveLoad * w;
      energySum += film.energy * w;
      if (film.tone == Tone.dark || film.tone == Tone.tense || film.tone == Tone.heavy) darkWeight += w;
    }
  });

  final genreAffinity = <Genre, double>{};
  for (final g in Genre.values) {
    final picked = answers.preferredGenres.contains(g);
    final prior = picked ? 0.55 : neutralGenreAffinity;
    final votes = genreVotes[g] ?? const [];
    var affinity = prior;
    if (votes.isNotEmpty) {
      final mean = votes.reduce((a, b) => a + b) / votes.length; // −0.8 … 1
      // Three or more films make a genre's vote fully trusted; fewer lean on the prior.
      final confidence = (votes.length / 3).clamp(0.0, 1.0);
      affinity = prior * (1 - confidence) + (0.5 + 0.45 * mean) * confidence;
    }
    if (picked) affinity += 0.05;
    genreAffinity[g] = affinity.clamp(0.0, 0.98);
  }

  final maxTrait = traitVotes.values.fold<double>(0, (m, v) => v > m ? v : m);
  final traitAffinity = <Trait, double>{
    for (final t in Trait.values) t: maxTrait <= 0 ? 0 : _clamp01((traitVotes[t] ?? 0) / maxTrait),
  };

  double avg(double sum) => positiveWeight == 0 ? 0.5 : sum / positiveWeight;

  return TasteProfile(
    genreAffinity: genreAffinity,
    traitAffinity: traitAffinity,
    preferredIntensity: avg(intensitySum),
    preferredCognitiveLoad: avg(cognitiveSum),
    preferredEnergy: avg(energySum),
    likesDarkTones: positiveWeight == 0 ? 0.5 : darkWeight / positiveWeight,
    discovery: answers.discovery,
    seenFilmIds: {
      for (final e in answers.ratings.entries)
        if (e.value != Rating.notSeen) e.key,
    },
    hasTaste: answers.preferredGenres.isNotEmpty || answers.ratings.values.any((r) => r != Rating.notSeen),
  );
}

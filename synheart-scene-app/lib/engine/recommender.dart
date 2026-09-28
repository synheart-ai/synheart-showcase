import '../data/catalogue.dart';
import '../domain/film.dart';
import '../domain/state.dart';
import '../domain/taste.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _closeness(double a, double b) => 1 - (a - b).abs();
bool _isDark(Tone t) => t == Tone.dark || t == Tone.tense || t == Tone.heavy;

/// The plan's MVP weights (§8).
const tasteWeight = 0.50;
const stateWeight = 0.35;
const contextWeight = 0.15;

enum RecommendationMode {
  /// Conventional: taste only.
  tasteOnly('Based on taste'),

  /// Taste + current state + context (the Synheart-enhanced list).
  tastePlusState('Taste + current state');

  const RecommendationMode(this.label);
  final String label;
}

/// What the current state asks of a film — derived, then shown to the user.
class StateTargets {
  const StateTargets({required this.intensity, required this.cognitiveLoad, required this.energy, required this.prefersLightTone});

  final double intensity;
  final double cognitiveLoad;
  final double energy;

  /// High mental load → lighter tones fit better right now.
  final bool prefersLightTone;

  factory StateTargets.from(CurrentState s) => StateTargets(
        intensity: _clamp01(0.8 - 0.6 * s.mentalLoad + 0.1 * (s.energy - 0.5)),
        // Moderate engagement still wants something involving (~0.5), just not demanding.
        cognitiveLoad: _clamp01(0.4 + 0.4 * s.engagement - 0.15 * s.mentalLoad),
        energy: _clamp01(0.3 + 0.55 * s.energy),
        prefersLightTone: s.mentalLoad >= 0.6,
      );
}

/// One scored film, with the pieces of the score kept for "Why this movie?".
class Recommendation {
  const Recommendation({
    required this.film,
    required this.score,
    required this.taste,
    required this.state,
    required this.context,
    required this.matchedGenres,
    required this.matchedTraits,
  });

  final Film film;

  /// The score used for ranking in the chosen mode (0–1).
  final double score;
  final double taste;
  final double state;
  final double context;

  /// The film's genres the user likes most, strongest first.
  final List<Genre> matchedGenres;

  /// The film's traits the user responds to, strongest first.
  final List<Trait> matchedTraits;

  int get matchPercent => (score * 100).round();
}

/// Scores films against a taste profile, and optionally a current state and
/// viewing context. Pure and deterministic, so the demo is repeatable.
class Recommender {
  const Recommender({this.pool = candidateFilms});

  final List<Film> pool;

  /// Taste match (0–1): does this film fit who the user is?
  double tasteMatch(Film f, TasteProfile p) {
    final affinities = f.genres.map(p.affinityFor).toList()..sort((a, b) => b.compareTo(a));
    final genre = affinities.first * 0.6 + (affinities.reduce((a, b) => a + b) / affinities.length) * 0.4;
    final trait = f.traits.isEmpty
        ? 0.4
        : f.traits.map((t) => p.traitAffinity[t] ?? 0).reduce((a, b) => a + b) / f.traits.length;
    final tone = _isDark(f.tone) ? p.likesDarkTones : 1 - 0.6 * p.likesDarkTones;
    final feel = (_closeness(f.intensity, p.preferredIntensity) + _closeness(f.cognitiveLoad, p.preferredCognitiveLoad)) / 2;
    // Familiar (0) wants well-known films; Surprise me (1) wants less-known ones.
    final discovery = _closeness(f.familiarity, 1 - p.discovery);
    return _clamp01(0.55 * genre + 0.15 * trait + 0.15 * tone + 0.10 * feel + 0.05 * discovery);
  }

  /// State fit (0–1): does this film suit the moment?
  double stateFit(Film f, CurrentState s) {
    final t = StateTargets.from(s);
    final tone = t.prefersLightTone ? (f.tone.isLight ? 1.0 : (_isDark(f.tone) ? 0.15 : 0.55)) : 0.7;
    return _clamp01(0.40 * _closeness(f.intensity, t.intensity) +
        0.25 * _closeness(f.cognitiveLoad, t.cognitiveLoad) +
        0.15 * _closeness(f.energy, t.energy) +
        0.20 * tone);
  }

  /// Context fit (0–1): does it fit the evening the user asked for?
  double contextFit(Film f, ViewingContext c) => switch (c.intent) {
        EveningIntent.unwind => _clamp01(0.6 * (1 - f.intensity) + 0.4 * (f.tone.isLight ? 1 : 0.3)),
        EveningIntent.engaging => _clamp01(0.7 * f.cognitiveLoad + 0.3 * f.energy),
        EveningIntent.entertain => _clamp01(0.6 * f.energy + 0.4 * (f.tone.isLight ? 1 : 0.4)),
        null => 0.6,
      };

  Recommendation score(Film f, TasteProfile p, {CurrentState? state, ViewingContext context = const ViewingContext(), RecommendationMode mode = RecommendationMode.tastePlusState}) {
    final taste = tasteMatch(f, p);
    final st = state == null ? 0.5 : stateFit(f, state);
    final ctx = contextFit(f, context);
    final total = mode == RecommendationMode.tasteOnly || state == null
        ? taste
        : tasteWeight * taste + stateWeight * st + contextWeight * ctx;

    final genres = f.genres.toList()..sort((a, b) => p.affinityFor(b).compareTo(p.affinityFor(a)));
    final traits = f.traits.where((t) => (p.traitAffinity[t] ?? 0) >= 0.4).toList()
      ..sort((a, b) => (p.traitAffinity[b] ?? 0).compareTo(p.traitAffinity[a] ?? 0));

    return Recommendation(
      film: f,
      score: total,
      taste: taste,
      state: st,
      context: ctx,
      matchedGenres: genres.where((g) => p.affinityFor(g) >= 0.55).toList(),
      matchedTraits: traits,
    );
  }

  /// Ranked recommendations. Films the user has already seen, films they
  /// asked not to see again ([hidden]) and films over the runtime limit are
  /// left out.
  List<Recommendation> recommend(
    TasteProfile p, {
    CurrentState? state,
    ViewingContext context = const ViewingContext(),
    RecommendationMode mode = RecommendationMode.tastePlusState,
    int limit = 5,
    Set<String> hidden = const {},
  }) {
    final max = context.maxRuntimeMinutes;
    final ranked = pool
        .where((f) => !p.seenFilmIds.contains(f.id) && !hidden.contains(f.id))
        .where((f) => max == null || f.runtimeMinutes <= max)
        .map((f) => score(f, p, state: state, context: context, mode: mode))
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.film.title.compareTo(b.film.title);
      });
    return ranked.take(limit).toList();
  }
}

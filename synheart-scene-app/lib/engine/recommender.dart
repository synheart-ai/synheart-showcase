import '../data/catalogue.dart';
import '../domain/film.dart';
import '../domain/state.dart';
import '../domain/taste.dart';

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _closeness(double a, double b) => 1 - (a - b).abs();
bool _isDark(Tone t) => t == Tone.dark || t == Tone.tense || t == Tone.heavy;

/// The plan's MVP weights (§8) — tunable defaults, not a validated formula
/// (RFC §7).
const tasteWeight = 0.50;
const stateWeight = 0.35;
const contextWeight = 0.15;

/// The weights actually applied to one ranking — part of each film's
/// contribution record, so explanations cite what was really used.
class Weights {
  const Weights(this.taste, this.state, this.context);
  final double taste;
  final double state;
  final double context;

  /// Taste only; an explicit intent still counts, because it is the user's
  /// own choice rather than a Synheart inference.
  static Weights tasteOnly({required bool hasIntent}) => hasIntent ? const Weights(0.7, 0, 0.3) : const Weights(1, 0, 0);

  /// Taste + state. An explicit intent takes precedence over the inferred
  /// need (RFC §4), so it swaps shares with the state: 50 / 15 / 35.
  static Weights withState({required bool hasIntent}) =>
      hasIntent ? const Weights(tasteWeight, contextWeight, stateWeight) : const Weights(tasteWeight, stateWeight, contextWeight);

  bool get usesState => state > 0;
  bool get usesContext => context > 0;
}

/// Descriptive fit instead of a numerical "94% match" (RFC §7).
enum Fit {
  strong('Strong fit'),
  good('Good fit'),
  possible('Possible fit');

  const Fit(this.label);
  final String label;

  static Fit of(double score) => score >= 0.72 ? strong : (score >= 0.6 ? good : possible);
}

/// How strongly one input supported a pick, in words.
String supportLabel(double v) => v >= 0.75 ? 'Strong' : v >= 0.6 ? 'Good' : v >= 0.45 ? 'Partial' : 'Weak';

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
    required this.weights,
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

  /// The weights this score was made with.
  final Weights weights;

  Fit get fit => Fit.of(score);

  /// "Strong fit for tonight" / "Good fit for your taste".
  String get fitLabel => '${fit.label} ${weights.usesState || weights.usesContext ? 'for tonight' : 'for your taste'}';
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
    final hasIntent = context.intent != null;
    final w = mode == RecommendationMode.tasteOnly || state == null
        ? Weights.tasteOnly(hasIntent: hasIntent)
        : Weights.withState(hasIntent: hasIntent);
    final total = w.taste * taste + w.state * st + w.context * ctx;

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
      weights: w,
    );
  }

  /// Ranked recommendations. Films the user has already seen (including
  /// those rated "Not for me"), films they asked not to see again ([hidden])
  /// and films over the runtime limit are left out. Both modes rank this same
  /// eligible catalogue (RFC §9.5). A null [limit] returns the whole ranking.
  List<Recommendation> recommend(
    TasteProfile p, {
    CurrentState? state,
    ViewingContext context = const ViewingContext(),
    RecommendationMode mode = RecommendationMode.tastePlusState,
    int? limit = 5,
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
    return limit == null ? ranked : ranked.take(limit).toList();
  }
}

/// How one film's place changed between the taste-only ranking and the
/// taste + state ranking (RFC §4.8).
class RankChange {
  const RankChange({required this.film, required this.before, required this.after});

  final Film film;

  /// 1-based rank in the taste-only list; null if not eligible there.
  final int? before;

  /// 1-based rank in the taste + state list; null if not eligible there.
  final int? after;

  /// Positive = moved up.
  int get moved => (before ?? 0) - (after ?? 0);
}

/// The comparison behind "What changed?".
class Comparison {
  const Comparison({required this.tasteOnly, required this.withState, required this.changes, required this.dropped});

  final List<Recommendation> tasteOnly;
  final List<Recommendation> withState;

  /// One entry per taste + state pick, in its order.
  final List<RankChange> changes;

  /// Taste-only picks that are no longer in the top list.
  final List<RankChange> dropped;

  /// Films in the taste + state list that were not in the taste-only list.
  int get newCount => changes.where((c) => c.before == null || c.before! > tasteOnly.length).length;

  /// A meaningful change: at least two films in the list are new, or the new
  /// top pick was outside the taste-only top three. Reordering the same films
  /// is reported honestly as "no meaningful change" rather than dressed up
  /// (RFC §10).
  bool get isMeaningful {
    if (changes.isEmpty) return false;
    final top = changes.first.before;
    return newCount >= 2 || top == null || top > 3;
  }
}

Comparison compareRankings(
  Recommender engine,
  TasteProfile p, {
  required CurrentState state,
  ViewingContext context = const ViewingContext(),
  Set<String> hidden = const {},
  int limit = 5,
}) {
  final fullTaste = engine.recommend(p, context: context, mode: RecommendationMode.tasteOnly, limit: null, hidden: hidden);
  final fullState = engine.recommend(p, state: state, context: context, limit: null, hidden: hidden);
  int? rankIn(List<Recommendation> list, String id) {
    final i = list.indexWhere((r) => r.film.id == id);
    return i < 0 ? null : i + 1;
  }

  final tasteTop = fullTaste.take(limit).toList();
  final stateTop = fullState.take(limit).toList();
  final stateIds = stateTop.map((r) => r.film.id).toSet();
  return Comparison(
    tasteOnly: tasteTop,
    withState: stateTop,
    changes: [
      for (final (i, r) in stateTop.indexed) RankChange(film: r.film, before: rankIn(fullTaste, r.film.id), after: i + 1),
    ],
    dropped: [
      for (final (i, r) in tasteTop.indexed)
        if (!stateIds.contains(r.film.id)) RankChange(film: r.film, before: i + 1, after: rankIn(fullState, r.film.id)),
    ],
  );
}

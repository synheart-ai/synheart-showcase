import '../app/scene_cubit.dart';
import '../domain/state.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';

const _engine = Recommender();

/// Everything a screen needs to show picks honestly. [state] is the fresh
/// reading or null: a missing or stale reading, or one with no confident
/// axis, means taste only, and the screens say so (RFC §8).
class Picks {
  Picks(this.s, this.state);

  factory Picks.of(SceneCubit cubit) => Picks(cubit.state, cubit.freshState);

  final SceneState s;
  final CurrentState? state;

  /// A snapshot exists but is too old to use.
  bool get isStale => s.current != null && state == null;

  /// A fresh reading exists, but no axis is confident enough to use.
  bool get lacksEvidence => state != null && !state!.hasEvidence;

  /// A fresh reading Scene can rank with.
  bool get hasUsableState => state != null && state!.hasEvidence;

  /// The mode actually in effect: taste + state needs a usable reading.
  RecommendationMode get mode => hasUsableState ? s.mode : RecommendationMode.tasteOnly;

  bool get withState => mode == RecommendationMode.tastePlusState;

  List<Recommendation> list({RecommendationMode? mode, int limit = 5}) {
    final p = s.profile;
    if (p == null) return const [];
    final m = mode ?? this.mode;
    return _engine.recommend(
      p,
      state: m == RecommendationMode.tasteOnly ? null : state,
      context: s.viewing,
      mode: m,
      limit: limit,
      hidden: s.hiddenFilmIds,
    );
  }

  /// One film scored the same way the list scored it.
  Recommendation? score(String filmId) {
    final p = s.profile;
    if (p == null) return null;
    for (final f in _engine.pool) {
      if (f.id == filmId) return _engine.score(f, p, state: withState ? state : null, context: s.viewing, mode: mode);
    }
    return null;
  }

  Comparison? compare() {
    final p = s.profile;
    final st = state;
    if (p == null || st == null || !st.hasEvidence) return null;
    return compareRankings(_engine, p, state: st, context: s.viewing, hidden: s.hiddenFilmIds);
  }

  /// The film's place on taste alone, for "How that affected this pick".
  int? tasteOnlyRank(String filmId) {
    final p = s.profile;
    if (p == null) return null;
    final all = _engine.recommend(p, context: s.viewing, mode: RecommendationMode.tasteOnly, limit: null, hidden: s.hiddenFilmIds);
    final i = all.indexWhere((r) => r.film.id == filmId);
    return i < 0 ? null : i + 1;
  }

  Explanation explanation(Recommendation r, {bool withRank = false}) => explain(
        r,
        state: withState ? state : null,
        viewing: s.viewing,
        usualIntensity: s.profile?.preferredIntensity,
        tasteOnlyRank: withRank && withState ? tasteOnlyRank(r.film.id) : null,
      );
}

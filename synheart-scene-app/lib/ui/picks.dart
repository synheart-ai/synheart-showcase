import '../app/scene_cubit.dart';
import '../engine/explain.dart';
import '../engine/recommender.dart';

const _engine = Recommender();

/// Tonight's list for the app's current mode.
List<Recommendation> picksFor(SceneState s, {RecommendationMode? mode, int limit = 5}) {
  final p = s.profile;
  if (p == null) return const [];
  final m = mode ?? s.mode;
  return _engine.recommend(
    p,
    state: m == RecommendationMode.tasteOnly ? null : s.current,
    context: s.viewing,
    mode: m,
    limit: limit,
    hidden: s.hiddenFilmIds,
  );
}

/// One film scored the same way the list scored it.
Recommendation? scoreFor(SceneState s, String filmId, {RecommendationMode? mode}) {
  final p = s.profile;
  if (p == null) return null;
  for (final f in _engine.pool) {
    if (f.id == filmId) {
      final m = mode ?? s.mode;
      return _engine.score(f, p, state: m == RecommendationMode.tasteOnly ? null : s.current, context: s.viewing, mode: m);
    }
  }
  return null;
}

Explanation explanationFor(SceneState s, Recommendation r) => explain(
      r,
      state: s.mode == RecommendationMode.tasteOnly ? null : s.current,
      viewing: s.viewing,
      mode: s.current == null ? RecommendationMode.tasteOnly : s.mode,
      usualIntensity: s.profile?.preferredIntensity,
    );

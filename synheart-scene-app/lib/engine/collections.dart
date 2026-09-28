import '../domain/film.dart';
import '../domain/state.dart';
import '../domain/taste.dart';
import 'recommender.dart';

/// The plan's state-aware collections (§7).
enum Collection {
  switchOff('Because you want to switch off', 'Easy watches based on your taste.'),
  keepEngaged('Keep me engaged', 'Films at the level of engagement you are up for.'),
  familiar('Something familiar', 'Safer choices close to what you already enjoy.'),
  surpriseMe('Surprise me', 'Outside your usual profile, but right for the moment.'),
  under90('90 minutes or less', 'For when time is short.');

  const Collection(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

/// Builds each collection from the same candidate pool and scores as
/// Tonight's Picks. Films the user has seen, or asked not to see again, are
/// left out.
Map<Collection, List<Film>> buildCollections(
  TasteProfile p, {
  required CurrentState state,
  ViewingContext context = const ViewingContext(),
  Set<String> hidden = const {},
  Recommender engine = const Recommender(),
  int perCollection = 6,
}) {
  final pool = engine.pool.where((f) => !p.seenFilmIds.contains(f.id) && !hidden.contains(f.id)).toList();
  double taste(Film f) => engine.tasteMatch(f, p);
  double fit(Film f) => engine.stateFit(f, state);
  double full(Film f) => engine.score(f, p, state: state, context: context).score;
  final targets = StateTargets.from(state);

  List<Film> top(Iterable<Film> films, double Function(Film) by) =>
      (films.toList()..sort((a, b) => by(b).compareTo(by(a)))).take(perCollection).toList();

  double topGenre(Film f) => f.genres.map(p.affinityFor).reduce((a, b) => a > b ? a : b);

  return {
    Collection.switchOff: top(pool.where((f) => f.intensity <= 0.45 && f.cognitiveLoad <= 0.5), taste),
    Collection.keepEngaged: top(
      pool.where((f) => f.cognitiveLoad >= 0.55 && f.intensity <= (targets.intensity ?? 1) + 0.25),
      (f) => 0.6 * taste(f) + 0.4 * f.cognitiveLoad,
    ),
    Collection.familiar: top(pool.where((f) => f.familiarity >= 0.75 && taste(f) >= 0.6), taste),
    Collection.surpriseMe: top(pool.where((f) => topGenre(f) < 0.6), fit),
    Collection.under90: top(pool.where((f) => f.runtimeMinutes <= 90), full),
  };
}

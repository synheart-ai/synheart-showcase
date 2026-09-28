import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/domain/film.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/domain/taste.dart';
import 'package:scene/engine/recommender.dart';
import 'package:scene/engine/taste_builder.dart';

List<String> ids(List<Recommendation> r) => r.map((x) => x.film.id).toList();

void main() {
  final persona = buildTasteProfile(demoPersonaAnswers);
  const engine = Recommender();

  group('Movie DNA (taste builder)', () {
    test('the demo persona reads as thriller / crime / mystery / sci-fi first', () {
      final top = persona.rankedGenres.take(4).map((e) => e.key).toSet();
      expect(top, {Genre.thriller, Genre.crime, Genre.mystery, Genre.sciFi});
    });

    test('affinities are spread out and never 100% (plan: "Thriller 92% …")', () {
      final values = persona.genreAffinity.values;
      expect(values.every((v) => v < 1), isTrue);
      expect(persona.affinityFor(Genre.thriller), greaterThan(persona.affinityFor(Genre.comedy) + 0.3));
    });

    test('films rated "Not for me" pull their genres down', () {
      final base = buildTasteProfile(const TasteAnswers(ratings: {'superbad': Rating.love}));
      final disliked = buildTasteProfile(const TasteAnswers(ratings: {'superbad': Rating.notForMe}));
      expect(disliked.affinityFor(Genre.comedy), lessThan(base.affinityFor(Genre.comedy)));
    });

    test('"Haven\'t seen it" says nothing about taste and is not "seen"', () {
      final p = buildTasteProfile(const TasteAnswers(ratings: {'toy-story': Rating.notSeen}));
      expect(p.seenFilmIds, isEmpty);
      expect(p.affinityFor(Genre.animation), closeTo(0.4, 1e-9));
    });

    test('dark-tone preference comes from what the user liked', () {
      expect(persona.likesDarkTones, greaterThan(0.7));
    });
  });

  group('recommendations — the plan\'s "What changed?" story (§6)', () {
    final tasteOnly = ids(engine.recommend(persona, mode: RecommendationMode.tasteOnly));
    final withState = ids(engine.recommend(persona, state: CurrentState.planExample));

    test('taste only: the dark thrillers lead', () {
      expect(tasteOnly, containsAll(['se7en', 'prisoners', 'shutter-island', 'gone-girl']));
    });

    test('taste + state (high mental load → Unwind): lighter films from the same taste', () {
      const planList = ['knives-out', 'nice-guys', 'catch-me', 'grand-budapest', 'oceans-eleven'];
      expect(withState.where(planList.contains).length, greaterThanOrEqualTo(4));
      expect(withState, isNot(contains('se7en')));
      expect(withState, isNot(contains('prisoners')));
    });

    test('the lists differ although the taste profile is the same', () {
      expect(withState.toSet().intersection(tasteOnly.toSet()), isEmpty);
    });

    test('every taste + state pick is still true to taste', () {
      for (final r in engine.recommend(persona, state: CurrentState.planExample)) {
        expect(r.matchedGenres, isNotEmpty, reason: r.film.title);
        expect(r.taste, greaterThan(0.55), reason: r.film.title);
      }
    });
  });

  group('rules', () {
    test('weights are the plan\'s 50 / 35 / 15', () {
      expect(tasteWeight + stateWeight + contextWeight, closeTo(1, 1e-9));
      final f = filmById('knives-out')!;
      final r = engine.score(f, persona, state: CurrentState.planExample);
      expect(r.score, closeTo(0.5 * r.taste + 0.35 * r.state + 0.15 * r.context, 1e-9));
    });

    test('films the user has seen are never recommended back', () {
      final seen = buildTasteProfile(demoPersonaAnswers.copyWith(
        ratings: {...demoPersonaAnswers.ratings},
      ));
      final pool = Recommender(pool: allFilms);
      expect(ids(pool.recommend(seen, limit: 50)), isNot(contains('dark-knight')));
    });

    test('"90 minutes or less" filters by runtime', () {
      final r = engine.recommend(persona, state: CurrentState.planExample, context: const ViewingContext(maxRuntimeMinutes: 90), limit: 20);
      expect(r, isNotEmpty);
      expect(r.every((x) => x.film.runtimeMinutes <= 90), isTrue);
    });

    test('a lively state lifts energetic films above quiet ones', () {
      const lively = CurrentState(energy: 0.9, mentalLoad: 0.2, engagement: 0.6, source: StateSource.preset);
      final energetic = engine.stateFit(filmById('baby-driver')!, lively);
      final quiet = engine.stateFit(filmById('octopus-teacher')!, lively);
      expect(energetic, greaterThan(quiet));
    });

    test('Choose My Evening: "Help me unwind" favours gentle films', () {
      final ctx = const ViewingContext(intent: EveningIntent.unwind);
      expect(engine.contextFit(filmById('chef')!, ctx), greaterThan(engine.contextFit(filmById('se7en')!, ctx)));
    });

    test('suggested experience follows the plan\'s example card', () {
      expect(CurrentState.planExample.suggestedExperience, Experience.unwind);
      expect(CurrentState.planExample.energyLevel, Level.moderate);
      expect(CurrentState.planExample.mentalLoadLevel, Level.high);
    });
  });
}

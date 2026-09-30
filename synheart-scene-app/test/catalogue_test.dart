import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/catalogue.dart';
import 'package:scene/domain/film.dart';

void main() {
  group('catalogue', () {
    test('ids are unique across onboarding and candidates', () {
      final ids = allFilms.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('onboarding has 12–20 recognisable films (plan §3)', () {
      expect(onboardingFilms.length, inInclusiveRange(12, 20));
    });

    test('onboarding spans the genres the plan lists', () {
      final covered = onboardingFilms.expand((f) => f.genres).toSet();
      for (final g in [
        Genre.comedy, Genre.drama, Genre.thriller, Genre.horror, Genre.sciFi,
        Genre.romance, Genre.action, Genre.documentary, Genre.animation,
      ]) {
        expect(covered, contains(g), reason: '${g.label} missing from onboarding');
      }
    });

    test("the plan's worked example films are all recommendable", () {
      const planFilms = [
        'Se7en', 'Prisoners', 'Gone Girl', 'Shutter Island', 'Knives Out',
        'The Nice Guys', 'Catch Me If You Can', 'The Grand Budapest Hotel', "Ocean's Eleven",
      ];
      final titles = candidateFilms.map((f) => f.title).toSet();
      for (final t in planFilms) {
        expect(titles, contains(t));
      }
    });

    test('every attribute is in range and every film has a genre', () {
      for (final f in allFilms) {
        for (final v in [f.intensity, f.cognitiveLoad, f.energy, f.familiarity]) {
          expect(v, inInclusiveRange(0, 1), reason: f.title);
        }
        expect(f.genres, isNotEmpty, reason: f.title);
        expect(f.runtimeMinutes, inInclusiveRange(60, 200), reason: f.title);
      }
    });

    test('filmById finds a film and returns null for unknown ids', () {
      expect(filmById('knives-out')?.title, 'Knives Out');
      expect(filmById('nope'), isNull);
    });
  });
}

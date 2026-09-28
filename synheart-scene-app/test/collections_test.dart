import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/domain/state.dart';
import 'package:scene/engine/collections.dart';
import 'package:scene/engine/taste_builder.dart';

void main() {
  final persona = buildTasteProfile(demoPersonaAnswers);
  final c = buildCollections(persona, state: CurrentState.planExample);

  test('every collection has films', () {
    for (final col in Collection.values) {
      expect(c[col], isNotEmpty, reason: col.title);
    }
  });

  test('switch off is gentle, 90 minutes or less is short', () {
    expect(c[Collection.switchOff]!.every((f) => f.intensity <= 0.45), isTrue);
    expect(c[Collection.under90]!.every((f) => f.runtimeMinutes <= 90), isTrue);
  });

  test('something familiar is well known; surprise me is outside the usual profile', () {
    expect(c[Collection.familiar]!.every((f) => f.familiarity >= 0.75), isTrue);
    for (final f in c[Collection.surpriseMe]!) {
      final best = f.genres.map(persona.affinityFor).reduce((a, b) => a > b ? a : b);
      expect(best, lessThan(0.6), reason: f.title);
    }
  });

  test('hidden films are left out', () {
    final first = c[Collection.familiar]!.first.id;
    final again = buildCollections(persona, state: CurrentState.planExample, hidden: {first});
    for (final list in again.values) {
      expect(list.map((f) => f.id), isNot(contains(first)));
    }
  });
}

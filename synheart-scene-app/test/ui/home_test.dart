import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/engine/collections.dart';
import 'package:scene/engine/taste_builder.dart';
import 'package:scene/main.dart';

import '../support/fake_signals.dart';
import 'helpers.dart';

void main() {
  Future<void> toHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(signals: FakeSignals()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
  }

  Finder page() => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

  testWidgets('taste only: the hero is the top pick, then the top five and "Because you like" rows', (tester) async {
    await toHome(tester);
    expect(appBarSettings(), findsOneWidget);
    expect(find.text('#1 TONIGHT'), findsOneWidget);
    expect(find.descendant(of: find.byType(Card).first, matching: find.text('Se7en')), findsWidgets); // poster art + title
    await tester.scrollUntilVisible(find.text("Tonight's top 5"), 300, scrollable: page());
    for (var i = 1; i <= 5; i++) {
      expect(find.text('#$i'), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Choose my evening'), 300, scrollable: page());
    await tester.drag(page(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Because you like'), findsWidgets);
    expect(find.text('Because you want to switch off'), findsNothing);
  });

  testWidgets('with a reading in use, the state-aware collections replace the taste rows', (tester) async {
    await toHome(tester);
    await useDemo(tester, 'Busy day');
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Card).first, matching: find.text('Se7en')), findsNothing);
    await tester.scrollUntilVisible(find.text('Because you want to switch off'), 300, scrollable: page());
    expect(find.text('Because you want to switch off'), findsOneWidget);
    expect(find.textContaining('Because you like'), findsNothing);
  });

  test('taste rows follow the top genres and skip what is already on the list', () {
    final p = buildTasteProfile(demoPersonaAnswers);
    final rows = tasteRows(p, exclude: {'se7en'});
    expect(rows.map((r) => r.$1), p.rankedGenres.take(2).map((e) => e.key));
    for (final (g, films) in rows) {
      expect(films, isNotEmpty);
      expect(films.every((f) => f.genres.contains(g)), isTrue);
      expect(films.map((f) => f.id), isNot(contains('se7en')));
    }
  });
}

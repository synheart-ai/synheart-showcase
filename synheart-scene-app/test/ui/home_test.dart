import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/data/demo_persona.dart';
import 'package:scene/engine/collections.dart';
import 'package:scene/engine/taste_builder.dart';
import 'package:scene/main.dart';

import '../support/fake_signals.dart';
import 'helpers.dart';

/// Home is a state-aware cinema home (2026-10-01): no taste-only switch and
/// no comparison screen — the picks use the current state whenever one is
/// usable, and say so.
void main() {
  Future<void> toHome(WidgetTester tester, {String? scenario, DateTime Function()? clock}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(signals: FakeSignals(), clock: clock));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
    if (scenario != null) await useDemo(tester, scenario);
  }

  Finder page() => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  Finder hero(String title) => find.descendant(of: find.byType(Card).first, matching: find.text(title));

  Future<void> scrollTo(WidgetTester tester, Finder f, {double by = 300}) async {
    await tester.scrollUntilVisible(f, by, scrollable: page());
    await tester.pumpAndSettle();
  }

  Future<void> openHero(WidgetTester tester, String title) async {
    await tester.tap(hero(title).last); // the title, not the poster's placeholder art under it
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
  }

  testWidgets('no reading: taste picks, and the banner offers to connect the watch', (tester) async {
    await toHome(tester);
    expect(appBarSettings(), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(hero('Se7en'), findsWidgets);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text("Today's Top Picks for You"), findsOneWidget);
    expect(find.text('TASTE + CURRENT STATE'), findsNothing, reason: 'no toggle any more');
    await scrollTo(tester, find.text('Connect your watch'));
    expect(find.text('Picks that fit your state'), findsOneWidget);
    await scrollTo(tester, find.text('Top 10 for You Today'));
    await scrollTo(tester, find.textContaining('Because you loved'));
    expect(find.text('Because you want to switch off'), findsNothing);
  });

  testWidgets('with a reading: the state banner, state rows and a state-aware hero', (tester) async {
    await toHome(tester, scenario: 'Busy day');
    expect(hero('Se7en'), findsNothing);
    expect(hero('Glass Onion'), findsWidgets);
    expect(find.text('Strong fit for tonight'), findsWidgets);
    expect(find.text('Top Picks for Right Now'), findsOneWidget);
    await scrollTo(tester, find.text('RIGHT NOW · DEMO DATA'));
    expect(find.text('Unwind'), findsWidgets);
    expect(find.text('Watch'), findsWidgets);
    await scrollTo(tester, find.text('Because you want to switch off'));
  });

  testWidgets('the title page: Why It Fits (taste, right now, effect) and More Like This', (tester) async {
    await toHome(tester, scenario: 'Busy day');
    await openHero(tester, 'Glass Onion');
    final title = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Right now'), 200, scrollable: title);
    expect(find.text('Your taste'), findsOneWidget);
    expect(find.textContaining('The demo data suggests this may be'), findsOneWidget);
    expect(find.textContaining('Reading taken'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('On taste alone it was #'), 200, scrollable: title);
    const closing = 'Synheart adds the missing context between what a person generally prefers and what may fit their present moment.';
    await tester.scrollUntilVisible(find.text(closing), 200, scrollable: title);
    await tester.scrollUntilVisible(find.text('More Like This'), -200, scrollable: title);
    await tester.tap(find.text('More Like This'));
    await tester.pumpAndSettle();
    expect(find.text('Your taste'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'\. Open\.$')), findsWidgets);
  });

  testWidgets('a stale reading falls back to taste and says so (RFC §8)', (tester) async {
    var now = DateTime(2026, 9, 28, 19);
    await toHome(tester, scenario: 'Busy day', clock: () => now);
    expect(hero('Glass Onion'), findsWidgets);
    now = now.add(const Duration(hours: 3));
    await tester.tap(find.text('Movies')); // any rebuild
    await tester.pumpAndSettle();
    expect(hero('Se7en'), findsWidgets);
    await scrollTo(tester, find.text('Reading too old'));
    expect(find.textContaining('from 3 h ago, is too old to use'), findsOneWidget);
    expect(find.text('Connect your watch'), findsOneWidget);
  });

  testWidgets('Categories: an intent leads the ranking and is named on the title page (RFC §9.6)', (tester) async {
    await toHome(tester);
    await tester.ensureVisible(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help me unwind'));
    await tester.pumpAndSettle();
    expect(find.text('Help me unwind'), findsOneWidget, reason: 'shown as a selected chip');
    await tester.tap(find.descendant(of: find.byType(Card).first, matching: find.byType(Text)).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('You chose "Help me unwind".'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Ranked on taste (70%) and your choice of evening (30%)'), findsOneWidget);
  });

  testWidgets('Categories: a genre filters Home', (tester) async {
    await toHome(tester);
    await tester.ensureVisible(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Comedy'), 200, scrollable: find.byType(Scrollable).last);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comedy'));
    await tester.pumpAndSettle();
    expect(find.text('Comedy'), findsOneWidget);
    expect(find.text('Movies'), findsNothing);
    await scrollTo(tester, find.text('Movies That Make You Laugh'));
  });

  testWidgets('+ My List saves a film to My Scene', (tester) async {
    await toHome(tester);
    await tester.tap(find.descendant(of: find.byType(Card).first, matching: find.text('My List')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsWidgets);
    await tester.tap(find.text('My Scene'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Se7en, ')), findsOneWidget);
    expect(find.text("Movies You've Loved"), findsOneWidget);
  });

  testWidgets('"Wrong for me" hides a film from Home', (tester) async {
    await toHome(tester, scenario: 'Busy day');
    await openHero(tester, 'Glass Onion');
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong for me').last);
    await tester.pumpAndSettle();
    expect(find.text('Thanks — Scene will not suggest this film again.'), findsWidgets);
    await tester.tapAt(const Offset(20, 40)); // close the sheet
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(hero('Glass Onion'), findsNothing);
  });

  testWidgets('Search and Clips follow the same state-aware order', (tester) async {
    await toHome(tester, scenario: 'Busy day');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended for You Right Now'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'knives');
    await tester.pumpAndSettle();
    expect(find.text('1 match'), findsOneWidget);
    expect(find.text('Knives Out'), findsWidgets);
    await tester.tap(find.text('Clips'));
    await tester.pumpAndSettle();
    expect(find.text('#1 FOR YOU RIGHT NOW'), findsOneWidget);
    expect(find.text('Glass Onion'), findsWidgets);
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

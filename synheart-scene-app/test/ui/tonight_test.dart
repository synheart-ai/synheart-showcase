import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_signals.dart';
import 'package:scene/main.dart';

import 'helpers.dart';

void main() {
  Future<void> toTonight(WidgetTester tester, {String scenario = 'Busy day', DateTime Function()? clock}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(signals: FakeSignals(), clock: clock));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
    await useDemo(tester, scenario);
  }

  Finder pickCard(String title) => find.descendant(of: find.byType(Card), matching: find.text(title)).first;

  testWidgets('the live demo story: taste first, then toggle, then why', (tester) async {
    await toTonight(tester);

    // Starts on taste only, and says so.
    expect(pickCard('Se7en'), findsOneWidget);
    expect(find.text('Taste only — the way a conventional recommender would.'), findsOneWidget);
    expect(find.text('Strong fit for your taste'), findsWidgets);

    // Toggle Synheart on: the list changes, the demo line appears, demo data is labelled.
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    expect(find.text("Your preferences haven't changed."), findsOneWidget);
    expect(find.textContaining('Demo data — not a real reading'), findsOneWidget);
    expect(find.descendant(of: find.byType(Card), matching: find.text('Se7en')), findsNothing);
    expect(find.text('Strong fit for tonight'), findsWidgets);

    // Why this movie? — the RFC's three parts, no percentage match.
    await tester.ensureVisible(pickCard('Knives Out'));
    await tester.pumpAndSettle();
    await tester.tap(pickCard('Knives Out'));
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    expect(find.text('Your taste'), findsOneWidget);
    expect(find.text('Right now'), findsOneWidget);
    expect(find.textContaining('The demo data suggests this may be'), findsOneWidget);
    await tester.dragUntilVisible(find.textContaining('On taste alone it was #'), find.byType(ListView).last, const Offset(0, -200));
    expect(find.text('How that affected this pick'), findsOneWidget);
    expect(find.textContaining('On taste alone it was #'), findsOneWidget);

    // RFC §8: the snapshot's age and a new check-in; plan §10: the closing message.
    expect(find.textContaining('Reading taken'), findsOneWidget);
    expect(find.text('Check in again'), findsOneWidget);
    const closing = 'Synheart adds the missing context between what a person generally prefers and what may fit their present moment.';
    await tester.dragUntilVisible(find.text(closing), find.byType(ListView).last, const Offset(0, -200));
    expect(find.text(closing), findsOneWidget);
  });

  testWidgets('Tonight shows the demo line only when the state really changed the list (RFC §10)', (tester) async {
    await toTonight(tester, scenario: 'Rested');
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    expect(find.text("Your preferences haven't changed."), findsNothing);
    expect(find.textContaining("Tonight's state barely changes your list"), findsOneWidget);
  });

  testWidgets('What changed? shows movement and the demo line for a meaningful change', (tester) async {
    await toTonight(tester);
    await tester.tap(find.text('What changed? Compare side by side'));
    await tester.pumpAndSettle();
    expect(find.text('Taste only'), findsOneWidget);
    expect(find.text('Taste + current state'), findsOneWidget);
    expect(find.text('Drops out tonight'), findsWidgets);
    expect(find.textContaining('↑ from #'), findsWidgets);
    await tester.scrollUntilVisible(find.text("Your preferences haven't changed. Your context has."), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text("Your preferences haven't changed. Your context has."), findsOneWidget);
  });

  testWidgets('a no-change scenario is explained honestly, not forced (RFC §10)', (tester) async {
    await toTonight(tester, scenario: 'Rested');
    await tester.tap(find.text('What changed? Compare side by side'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No meaningful change tonight'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('No meaningful change tonight'), findsOneWidget);
    expect(find.text("Your preferences haven't changed. Your context has."), findsNothing);
  });

  testWidgets('a stale reading falls back to taste only and offers a new one (RFC §8)', (tester) async {
    var now = DateTime(2026, 9, 28, 19);
    await toTonight(tester, clock: () => now);
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    expect(find.text("Your preferences haven't changed."), findsOneWidget);

    now = now.add(const Duration(hours: 3));
    await tester.tap(find.text('BASED ON TASTE')); // any rebuild
    await tester.pumpAndSettle();
    expect(find.textContaining('Taste only. Your last reading, from 3 h ago, is too old to use'), findsOneWidget);
    expect(find.text("Your preferences haven't changed."), findsNothing);
    expect(find.text('Do a Synheart check-in'), findsOneWidget);
  });

  testWidgets('an explicit intent works in taste-only mode too, and is named in the reason (RFC §9.6)', (tester) async {
    await toTonight(tester);
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(find.text('Help me unwind'), 300, scrollable: page);
    await tester.ensureVisible(find.text('Help me unwind'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help me unwind'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('#1 TONIGHT'), -300, scrollable: page);
    await tester.ensureVisible(find.text('#1 TONIGHT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#1 TONIGHT'));
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    expect(find.text('You chose "Help me unwind".'), findsOneWidget);
    expect(find.textContaining('Ranked on taste (70%) and your choice of evening (30%)'), findsOneWidget);
  });

  testWidgets('collections appear with the current state; feedback hides a film', (tester) async {
    await toTonight(tester);
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Choose my evening'), 300, scrollable: page);
    expect(find.text('Choose my evening'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Because you want to switch off'), 300, scrollable: page);
    expect(find.text('Because you want to switch off'), findsOneWidget);

    // "Wrong for me" on Knives Out drops it from tonight's list.
    await tester.scrollUntilVisible(find.textContaining("Tonight's top"), -300, scrollable: page);
    await tester.ensureVisible(pickCard('Knives Out'));
    await tester.pumpAndSettle();
    await tester.tap(pickCard('Knives Out'));
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Wrong for me'), find.byType(ListView).last, const Offset(0, -300));
    await tester.ensureVisible(find.text('Wrong for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong for me'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks — Scene will not suggest this film again.'), findsOneWidget);
    expect(find.text('Anything specific? (optional)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Card), matching: find.text('Knives Out')), findsNothing);
  });
}

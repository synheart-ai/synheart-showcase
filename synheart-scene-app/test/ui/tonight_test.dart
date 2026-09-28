import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scene/app/synheart.dart';
import 'package:scene/main.dart';

void main() {
  Future<void> toTonight(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SceneApp(synheart: SynheartService.unavailable()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start my Synheart check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use demo scenario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("See tonight's picks"));
    await tester.pumpAndSettle();
  }

  testWidgets('the live demo story: taste first, then toggle, then why', (tester) async {
    await toTonight(tester);

    // Starts on taste only.
    expect(find.text('Se7en'), findsWidgets);
    expect(find.textContaining('Picked on your taste alone'), findsOneWidget);

    // Toggle Synheart on: the list changes, the demo line appears.
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    expect(find.text("Your preferences haven't changed."), findsOneWidget);
    expect(find.text('Se7en'), findsNothing);
    expect(find.text('Knives Out'), findsWidgets);

    // Why this movie?
    await tester.ensureVisible(find.text('Knives Out').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Knives Out').last);
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    expect(find.text('Your baseline'), findsOneWidget);
    expect(find.text('Your current context'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('State fit (Synheart)'), 200);
    expect(find.textContaining('State fit (Synheart)'), findsOneWidget);
  });

  testWidgets('What changed? shows both lists side by side', (tester) async {
    await toTonight(tester);
    await tester.tap(find.text('What changed? Compare side by side'));
    await tester.pumpAndSettle();
    expect(find.text('Taste only'), findsOneWidget);
    expect(find.text('Taste + current state'), findsOneWidget);
    expect(find.text('Se7en'), findsWidgets);
    expect(find.text('Knives Out'), findsWidgets);
    expect(find.text("Your preferences haven't changed. Your context has."), findsOneWidget);
  });

  testWidgets('Choose My Evening and collections appear with the current state; feedback hides a film', (tester) async {
    await toTonight(tester);
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    expect(find.text('Choose my evening'), findsOneWidget);
    expect(find.text('90 minutes or less'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Because you want to switch off'), 300, scrollable: page);
    expect(find.text('Because you want to switch off'), findsOneWidget);

    // "Wrong for me" on Knives Out drops it from tonight's list.
    await tester.ensureVisible(find.text('Knives Out').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Knives Out').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Wrong for me'), find.text('Your baseline'), const Offset(0, -300));
    await tester.ensureVisible(find.text('Wrong for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrong for me'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks — Scene will not suggest this film again.'), findsOneWidget);
    expect(find.text('Anything specific? (optional)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Knives Out'), findsNothing);
  });
}

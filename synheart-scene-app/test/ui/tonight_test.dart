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
}

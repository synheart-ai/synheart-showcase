import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_signals.dart';
import 'package:scene/main.dart';

import 'helpers.dart';

/// RFC §9.9: readable text, accessible controls and labels, an obvious back path.
void main() {
  Future<void> start(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(SceneApp(signals: FakeSignals()));
    await tester.pumpAndSettle();
  }

  Future<void> toTonight(WidgetTester tester) async {
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
    await useDemo(tester, 'Busy day');
  }

  Future<void> expectGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('every step has a back path, and Back skips finished steps', (tester) async {
    await start(tester);
    await toTonight(tester);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pageBack(); // → Movie DNA (Settings closed itself after demo data)
    await tester.pumpAndSettle();
    expect(find.text('Your Movie DNA'), findsOneWidget);
    await tester.pageBack(); // → Welcome
    await tester.pumpAndSettle();
    expect(find.text('Scene by Synheart'), findsOneWidget);
  });

  testWidgets('Welcome, Tonight, the state sheet, Settings and demo picks meet the tap-target, label and contrast guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await start(tester);
    await expectGuidelines(tester);
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Skip — see tonight's picks"));
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    await tester.tap(sheetSettings());
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    final demo = find.textContaining('Demo data: Busy day');
    await tester.scrollUntilVisible(demo, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(demo);
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    handle.dispose();
  });

  testWidgets('large text (160%) lays out without overflow through the demo', (tester) async {
    await start(tester, textScale: 1.6);
    await toTonight(tester);
    await tester.tap(find.text('TASTE + CURRENT STATE'));
    await tester.pumpAndSettle();
    final card = find.descendant(of: find.byType(Card), matching: find.text('Knives Out'));
    for (var i = 0; i < 12 && card.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(card.first);
    await tester.pumpAndSettle();
    await tester.tap(card.first);
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

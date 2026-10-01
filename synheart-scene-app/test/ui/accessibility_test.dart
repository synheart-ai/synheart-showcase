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
    await tester.ensureVisible(find.text('Try the demo profile')); // Welcome scrolls at large text sizes
    await tester.pumpAndSettle();
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

  testWidgets('onboarding has a back path; Home is the root; a title page goes back to Home', (tester) async {
    await start(tester);
    await tester.tap(find.text('Try the demo profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your Movie DNA'), findsOneWidget);
    await tester.pageBack(); // → Welcome
    await tester.pumpAndSettle();
    expect(find.image(const AssetImage('assets/scene_logo_light.png')), findsOneWidget); // the wordmark
    await tester.tap(find.text("Tonight's picks")); // the profile exists now
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing, reason: 'Home is the root, as in a cinema app');
    await tester.tap(find.descendant(of: find.byType(Card).first, matching: find.text('Se7en')).last);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text("Today's Top Picks for You"), findsOneWidget);
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
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(ActionChip)));
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
    for (final tab in ['Clips', 'Search', 'My Scene']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
    }
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Card).first, matching: find.text('Glass Onion')).last);
    await tester.pumpAndSettle();
    await expectGuidelines(tester); // the title page
    handle.dispose();
  });

  testWidgets('large text (160%) lays out without overflow through the demo', (tester) async {
    await start(tester, textScale: 1.6);
    await toTonight(tester);
    // Home (hero, rows, banner) scrolled end to end, then a title page.
    for (var i = 0; i < 14; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Card).first, matching: find.text('Glass Onion')).last);
    await tester.pumpAndSettle();
    expect(find.text('Why this movie?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Settings button in the current screen's app bar (the state sheet has
/// its own, so a bare `find.byTooltip('Settings')` can match two).
Finder appBarSettings() => find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Settings')).last;

/// The Settings button inside the open state sheet.
Finder sheetSettings() => find.descendant(of: find.byType(BottomSheet), matching: find.byTooltip('Settings'));

/// From any screen with a Settings button: go to Settings and apply a
/// demo-data scenario. Settings closes back to where it was opened.
Future<void> useDemo(WidgetTester tester, String title) async {
  await tester.tap(appBarSettings());
  await tester.pumpAndSettle();
  final button = find.textContaining('Demo data: $title');
  await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

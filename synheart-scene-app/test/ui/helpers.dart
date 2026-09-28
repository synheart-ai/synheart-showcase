import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// From any screen with the state pill: open the sheet, go to Settings and
/// apply a demo-data scenario. Settings closes back to where it was opened.
Future<void> useDemo(WidgetTester tester, String title) async {
  await tester.tap(find.byType(ActionChip).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  final button = find.textContaining('Demo data: $title');
  await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

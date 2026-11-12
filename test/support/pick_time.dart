import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In the date and time dialog: opens the Material clock from the time tile,
/// types [hour] and [minute] with its keyboard mode and confirms it. The date
/// dialog stays open.
Future<void> pickTime(WidgetTester tester, int hour, int minute) async {
  await tester.tap(find.byKey(const Key('dt-time')));
  await tester.pumpAndSettle();
  // The dial has a toggle to type the time instead.
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.text('OK'),
    ),
  );
  await tester.pumpAndSettle();
}

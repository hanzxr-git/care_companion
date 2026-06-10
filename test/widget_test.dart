// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_companion/cc_theme.dart';
import 'package:care_companion/screens/auth/phone_screen.dart';

void main() {
  // Wrap PhoneScreen directly in a minimal app — no Firebase needed
  Widget buildTestApp() => const ElderScope(
    on: false,
    child: MaterialApp(
      home: PhoneScreen(),
    ),
  );

  testWidgets('Phone screen shows CareCompanion title', (tester) async {
    await tester.pumpWidget(buildTestApp());
    expect(find.text('CareCompanion'), findsOneWidget);
  });

  testWidgets('Phone screen shows Sign in tab by default', (tester) async {
    await tester.pumpWidget(buildTestApp());
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('Tapping Register shows name field', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('FULL NAME'), findsOneWidget);
  });

  testWidgets('Phone number hint is visible', (tester) async {
    await tester.pumpWidget(buildTestApp());
    expect(find.text('123456789'), findsOneWidget);
  });
}
// Basic smoke test: the app boots to the splash/login flow without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emtees_app/main.dart';

void main() {
  testWidgets('App boots and shows a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EmteesApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

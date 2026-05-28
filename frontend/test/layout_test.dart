import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test Column in Center with Expanded', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Text('Hello'),
                  Expanded(child: Container(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });
}

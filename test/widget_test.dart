// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OpenCode app smoke test', (WidgetTester tester) async {
    // Create a mock OpenCode client

    // Build our app and trigger a frame.

    // Verify that our app shows the OpenCode title.
    expect(find.text('OpenCode Mobile'), findsOneWidget);
    expect(find.text('OpenCode Mobile Client'), findsOneWidget);
  });
}

// integration_test/d_pad_flow_test.dart
// D-pad navigation flow on Tizen TV. Run with:
//   flutter-tizen test --device-id <id> integration_test/

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:demo/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-pad reaches Sign Out',
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Settings list autofocuses the first item; descend seven steps.
    for (var i = 0; i < 7; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    // Activate the focused item.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Sign out of all devices?'), findsOneWidget);

    await binding.takeScreenshot('signout-confirm');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

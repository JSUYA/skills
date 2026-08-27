// Example integration test for a Flutter-Tizen app.
//
// Run it on a connected target with:
//   flutter-tizen test integration_test/app_test.dart -d <device-id>
//
// Copy this file to `integration_test/app_test.dart` in the app and replace the
// `package:my_app/main.dart` import with the real entrypoint.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('home grid', () {
    testWidgets('D-pad moves focus and OK opens the details page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // The first tile takes focus when the grid mounts.
      expect(_focusedKey(), const ValueKey<String>('tile_0'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_focusedKey(), const ValueKey<String>('tile_1'));

      // OK arrives as `select` on some firmware and `enter` on others; a test
      // that only sends one of them passes on a single device and fails on the
      // next. Assert the app handles both.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('details_page')), findsOneWidget);

      // Back must pop the route; without an explicit handler Tizen exits the app.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_grid')), findsOneWidget);
    });

    testWidgets('a privilege-gated call fails loudly, not silently', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('refresh')));

      // A `<privilege>` missing from tizen/tizen-manifest.xml surfaces here as a
      // PlatformException. Asserting on it keeps the manifest honest.
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('error_banner')), findsNothing);
    });
  });
}

/// The key of the widget currently holding primary focus.
///
/// Read through the focus node rather than `Focus.of(context)`: that resolves
/// the nearest *ancestor* focus scope, so calling it on the keyed element's own
/// context reports the parent's state. This requires the `ValueKey` to sit on
/// the `Focus` / `FocusableActionDetector` widget itself, which is the element
/// the focus node attaches to.
Key? _focusedKey() => FocusManager.instance.primaryFocus?.context?.widget.key;

---
name: flutter-tizen-integration-test-device
description: Run Flutter `integration_test` packages on a real Tizen device or emulator using `flutter-tizen test --device-id=<id>` (alternatively `flutter-tizen drive`). Use when validating end-to-end flows on Tizen-specific hardware, when a feature only fails on TV/RPi, or when adding a CI lane that targets a connected emulator.
metadata:
  target: flutter-tizen
  category: testing
---
# Running Flutter integration tests on Tizen targets

## Contents
- [Why on-device tests matter for Tizen](#why-on-device-tests-matter-for-tizen)
- [Set up `integration_test`](#set-up-integration_test)
- [Authoring the test](#authoring-the-test)
- [Running on a Tizen target](#running-on-a-tizen-target)
- [Workflow: Add a Device-Backed Integration Test](#workflow-add-a-device-backed-integration-test)
- [Capturing artifacts](#capturing-artifacts)
- [CI lane sketch](#ci-lane-sketch)
- [Pitfalls](#pitfalls)

## Why on-device tests matter for Tizen

Most Tizen-specific failure modes only reproduce on a real Tizen runtime: privilege denials, app-control intents, message-port handshakes, focus traversal under the actual TV remote, fonts and DPI on real TV panels, GPU paths under the Tizen embedder. Pure widget tests miss these — they exercise Dart only and stub the platform.

`integration_test` keeps the same `flutter_test` APIs, but the harness runs inside the app on the device. Combined with `flutter-tizen -d <id>`, you get repeatable on-device runs locally and in CI.

## Set up `integration_test`

From the project root:

```sh
flutter-tizen pub add 'dev:integration_test:{"sdk":"flutter"}'
flutter-tizen pub add 'dev:flutter_test:{"sdk":"flutter"}'
```

Layout (matching upstream Flutter conventions):

```
my_app/
├── integration_test/
│   └── app_test.dart            # the test entry point
├── lib/main.dart
└── pubspec.yaml
```

Add stable `Key`s to widgets you intend to target — Tizen TV layouts often have several widgets with the same visible text.

## Authoring the test

```dart
// integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('home screen', () {
    testWidgets('opens settings via the focused button on the TV remote',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate with D-pad-equivalent keys
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_screen')), findsOneWidget);
    });
  });
}
```

Notes:

- Use `sendKeyEvent`, not `tap`, when validating focus-traversal — taps don't exercise the focus path that real TV users hit.
- `pumpAndSettle()` waits for animations to finish. Set a longer timeout on TV (`pumpAndSettle(const Duration(seconds: 10))`) — TV GPU paths are slower than emulator x86 paths.

## Running on a Tizen target

### Simple path: `flutter-tizen test integration_test`

```sh
# Single connected target
flutter-tizen test integration_test

# Pin a specific device
flutter-tizen -d emulator-26101 test integration_test/app_test.dart
```

This builds the app + tests, installs to the device, runs the test, and streams pass/fail to the host shell. It does not require a `test_driver/` host script.

### Driver path: `flutter-tizen drive`

Needed only if you must hold a long-running host harness (screenshot capture loops, perf timelines, host-side post-processing). Add `test_driver/integration_test.dart`:

```dart
// test_driver/integration_test.dart
import 'package:integration_test/integration_test_driver.dart';
Future<void> main() => integrationDriver();
```

Then:

```sh
flutter-tizen -d <id> drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/app_test.dart
```

### Choosing a build mode

- `--debug` (default) — required for the emulator; required for ad-hoc local runs.
- `--profile` — required to record perf timeline data via `IntegrationTestWidgetsFlutterBinding.reportData`.
- `--release` — supported only on real hardware; skips assertions, so widget tests that rely on `debug*` checks may behave differently.

### Targeting a specific build profile / arch

When the device or emulator's profile/arch differs from the project default, pass through to the build:

```sh
flutter-tizen -d emulator-26101 test integration_test/app_test.dart \
    --dart-define=FLAVOR=tv \
    --device-profile=tv --target-arch=x86
```

## Workflow: Add a Device-Backed Integration Test

### Task Progress
- [ ] **Step 1: Add deps** — `dev:integration_test`, `dev:flutter_test`.
- [ ] **Step 2: Create `integration_test/` with a `_test.dart` file** and `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`.
- [ ] **Step 3: Add `Key`s** to every widget the test touches.
- [ ] **Step 4: Author the scenario** in `flutter_test` style; use `sendKeyEvent` for D-pad flows.
- [ ] **Step 5: Confirm device** is up: `sdb devices` + `flutter-tizen devices` show the target as `device`.
- [ ] **Step 6: Run once locally** with `flutter-tizen -d <id> test integration_test/...`. Watch for `+1 -0 ~0` ("All tests passed").
- [ ] **Step 7: Capture artifacts** (see [Capturing artifacts](#capturing-artifacts)) if the test needs screenshots or perf timelines.
- [ ] **Step 8: Wire into CI** (see [CI lane sketch](#ci-lane-sketch)).

## Capturing artifacts

### Screenshots

```dart
final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

testWidgets('home looks right', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await binding.takeScreenshot('home_screen');
});
```

Screenshots land in the host filesystem when running via `flutter-tizen drive`. With `flutter-tizen test` you must pull them via `sdb` from the app's data directory.

### Perf timelines

```dart
testWidgets('home scroll perf', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await binding.traceAction(
    () async {
      await tester.fling(find.byType(ListView), const Offset(0, -500), 1000);
      await tester.pumpAndSettle();
    },
    reportKey: 'home_scroll',
  );
});
```

Pair with `--profile` mode. The trace JSON is delivered via `reportData` and written by `integrationDriver` if you use the driver path.

## CI lane sketch

```yaml
# pseudo CI config
steps:
  - name: launch tizen emulator
    run: |
      flutter-tizen emulators --launch <emulator-id> &
      timeout 90 bash -c 'until sdb devices | grep -q device$; do sleep 2; done'

  - name: integration test on emulator
    run: |
      flutter-tizen -d emulator-26101 test integration_test/ \
          --device-profile common --target-arch x86 --debug \
          --reporter expanded

  - name: dlog snapshot on failure
    if: failure()
    run: sdb -s emulator-26101 dlog -d > artifacts/dlog.txt
```

Tip: For TV runs, replace the emulator step with `sdb connect <tv-ip>` and pin the device-id; never let CI auto-pick when more than one Tizen device is reachable.

## Pitfalls

- **Forgetting `--debug` on the emulator.** Emulators reject AOT-compiled TPKs and the test launches, freezes, then times out. Build mode must be `--debug` for emulators.
- **Empty `Key`s and reliance on text.** TV apps frequently render the same text in multiple rails; `find.byKey` is the only reliable locator.
- **Driving by `tap` instead of key events.** The test passes against synthesized taps but the real D-pad path is never exercised — the bug ships. Use `sendKeyEvent`.
- **Timeouts too short.** `pumpAndSettle()` defaults to 10 minutes globally but per-frame waits can race on slow TV firmware; widen tolerances rather than chasing flakiness.
- **Stale installs.** A previous version of the app left on the device gets re-used if the package version didn't bump. `sdb -s <id> uninstall <appid>` between runs in CI.
- **Multi-device ambiguity.** With both an emulator and a TV reachable, omitting `-d` makes the test target whatever sdb listed first. Always pin `-d`.

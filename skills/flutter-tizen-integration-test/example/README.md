# Example: Integration test on a Tizen target

A device test that drives a TV remote flow, plus the bounded runner used to execute it unattended.

## Files

- `app_test.dart` — `integration_test/` entrypoint: initializes `IntegrationTestWidgetsFlutterBinding`, walks a grid with D-pad keys, and asserts focus and navigation. Shows the `ValueKey` + `sendKeyEvent` pattern rather than text matching or `sdb` key injection.
- `integration_test_runner.sh` — verifies the target with `sdb devices`, runs `flutter-tizen test` under `timeout`, captures the console (the only log channel that works on TV), and greps the captured log for the failure patterns that matter.

## Scenario

CI needs one command that either passes or fails with a readable reason on the TV 9.0 emulator. The runner never touches `sdb dlog` (locked down on TV, silently empty) and never leaves a `flutter-tizen run` session behind.

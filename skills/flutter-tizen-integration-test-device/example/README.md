# Example: D-pad-driven integration test on TV

Run an `integration_test` against a connected TV that drives focus traversal with `sendKeyEvent`.

## Files

- `integration_test/d_pad_flow_test.dart` — drive arrow + select keys through a settings flow, capture a screenshot at the destination.
- `test_driver/integration_test.dart` — `integrationDriver()` entry for `flutter-tizen drive`.
- `run_tests.sh` — emulator boot + `flutter-tizen test --device-id` + report collection.

## Scenario

User wants to verify on every CI run that the TV remote can land on the "Sign Out" item in Settings without keyboard fallback. The test simulates seven arrow presses, an OK, then asserts the resulting screen and screenshots the result.

# Example: Plugin Regression Test Runner

End-to-end regression testing for flutter-tizen plugins on TV emulator.

## Files

- `regression_test_runner.sh` — driver script: environment check, emulator launch, example app execution, log capture.
- `log_analysis.sh` — log analysis script: filter unhandled exceptions, Flutter framework errors, and native crashes from the captured run-console log.
- `self_check.sh` — verifies that clean logs pass and known failure patterns return non-zero.

## Scenario

User wants to validate that existing plugins continue to work after changes to the flutter-tizen toolchain, embedder, or engine. The scripts handle the full test cycle: verify environment → launch emulator → run example app → capture logs → analyze for issues.

## Usage

```bash
# Run regression test for a specific plugin
bash regression_test_runner.sh --plugin connectivity_plus

# Run regression test for all testable plugins
bash regression_test_runner.sh --all

# Name the emulator config to launch, or reuse a connected sdb device
bash regression_test_runner.sh --plugin connectivity_plus \
  --emulator-id T-samsung-9.0-x86
bash regression_test_runner.sh --plugin connectivity_plus \
  --device-id emulator-26101

# Analyze captured logs
bash log_analysis.sh example_run.log

# Check the analyzer itself
bash self_check.sh
```

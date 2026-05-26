#!/usr/bin/env bash
# CI-friendly emulator + integration-test driver.
# Companion to ../SKILL.md.

set -eu

VM_NAME="${VM_NAME:-T-samsung-9.0-x86}"
DEVICE_ID="${DEVICE_ID:-emulator-26101}"

# 1) Headless emulator
tizen emulator launch -n "$VM_NAME" --skin no-skin &
EMU_PID=$!
trap 'kill $EMU_PID 2>/dev/null' EXIT

# 2) Wait until sdb sees it
for _ in $(seq 1 60); do
    if sdb devices | grep -q "$DEVICE_ID"; then break; fi
    sleep 2
done

# 3) Run tests
flutter-tizen test \
    --device-id "$DEVICE_ID" \
    --reporter expanded \
    integration_test/

# 4) Optional: also via flutter-tizen drive for screenshot capture
# flutter-tizen drive \
#     --device-id "$DEVICE_ID" \
#     --driver test_driver/integration_test.dart \
#     --target integration_test/d_pad_flow_test.dart

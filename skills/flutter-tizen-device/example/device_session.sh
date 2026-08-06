#!/usr/bin/env bash
# Connect to a Tizen device, run the app, and print the VM Service URL.
# Companion to ../SKILL.md.

set -eu

DEVICE_IP="${DEVICE_IP:-192.168.0.101}"
DEVICE_PORT="${DEVICE_PORT:-26101}"
DEVICE_ID="${DEVICE_ID:-${DEVICE_IP}:${DEVICE_PORT}}"

# 1) Connect
sdb connect "${DEVICE_IP}:${DEVICE_PORT}"
sdb devices | grep -F "$DEVICE_ID" | grep -q $'\tdevice$' \
    || { echo "device not 'device' status — check developer mode + RSA prompt"; exit 1; }

# 2) flutter-tizen sees it
flutter-tizen devices | grep -F "$DEVICE_ID"

# 3) Run debug build with hot reload, capturing the VM Service URL
LOG=$(mktemp)
flutter-tizen -d "$DEVICE_ID" run --debug 2>&1 | tee "$LOG" &
FT_PID=$!

cleanup() {
    kill "$FT_PID" 2>/dev/null || true
    wait "$FT_PID" 2>/dev/null || true
    sdb disconnect "${DEVICE_IP}:${DEVICE_PORT}" >/dev/null 2>&1 || true
    rm -f "$LOG"
}
trap cleanup EXIT

# 4) Wait for the VM Service URL, then print it for DevTools/manual attach
VM_URL=""
for _ in {1..300}; do
    VM_URL=$(grep -m1 -oE 'http://127\.0\.0\.1:[0-9]+/[^ ]+' "$LOG" || true)
    [[ -n "$VM_URL" ]] && break
    kill -0 "$FT_PID" 2>/dev/null \
        || { echo "flutter-tizen exited before publishing a VM Service URL" >&2; exit 1; }
    sleep 1
done
[[ -n "$VM_URL" ]] \
    || { echo "timed out waiting for the VM Service URL" >&2; exit 1; }
echo "VM Service URL: $VM_URL"

# 5) Detach cleanly when done
wait "$FT_PID"

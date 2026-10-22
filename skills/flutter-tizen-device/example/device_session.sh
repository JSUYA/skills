#!/usr/bin/env bash
# Connect to a Tizen device and keep its Flutter run console in the foreground.
# Companion to ../SKILL.md.

set -eu

DEVICE_IP="${DEVICE_IP:-192.168.0.101}"
DEVICE_PORT="${DEVICE_PORT:-26101}"
DEVICE_ID="${DEVICE_ID:-${DEVICE_IP}:${DEVICE_PORT}}"

# 1) Connect
sdb connect "${DEVICE_IP}:${DEVICE_PORT}"
trap 'sdb disconnect "${DEVICE_IP}:${DEVICE_PORT}"' EXIT
devices=$(sdb devices)
awk -v id="$DEVICE_ID" '$1 == id && $2 == "device" {found = 1} END {exit !found}' <<< "$devices" \
    || { echo "device not 'device' status — check developer mode + RSA prompt"; exit 1; }

# 2) flutter-tizen sees it
flutter-tizen devices | grep -F "$DEVICE_ID"

# 3) Keep the session alive for logs, hot reload, and host port forwarding.
printf '%s\n' \
    'The "A Dart VM Service ..." URL below is the host HTTP URL for DevTools.' \
    'For Dart MCP, discover the app with the dtd tool first; the ws://.../ws form of this URL is the fallback.' \
    'CLI attach needs the device URI from verbose run output, not this host URL.'
flutter-tizen run -d "$DEVICE_ID" --debug

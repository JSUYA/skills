#!/usr/bin/env bash
# Filter dlog to Flutter-relevant tags only.
# Adjust DEVICE_ID and TAG to taste.
#
# USAGE: Run this script only on dlog-capable targets (common emulator, real devices).
#
# NOTE: dlog is blocked on the Samsung TV emulator. Before running, verify:
#   sdb -s <id> capability | grep -E 'intershell_support'
#
# If intershell_support:disabled, this script will return nothing.
# On the TV emulator, read the foreground `flutter-tizen run` console instead.

set -eu

DEVICE_ID="${DEVICE_ID:-192.168.0.101:26101}"

# Verify dlog is available on this target
if ! sdb -s "$DEVICE_ID" capability 2>/dev/null | grep -q 'intershell_support:enabled'; then
  echo "ERROR: sdb dlog is not available on this target (intershell_support:disabled)" >&2
  echo "On the TV emulator, use the foreground 'flutter-tizen run' console instead." >&2
  exit 1
fi

# Flutter console + engine + a custom plugin tag
sdb -s "$DEVICE_ID" dlog \
    'ConsoleMessage:I' \
    'FlutterEngine:I' \
    'FooTizen:V' \
    '*:S'

# Drop the final '*:S' to see everything else.

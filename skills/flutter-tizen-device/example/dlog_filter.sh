#!/usr/bin/env bash
# Filter dlog to Flutter-relevant tags only.
# Adjust DEVICE_ID and TAG to taste.
#
# NOTE: dlog is blocked on the Samsung TV emulator (capability shows
# secure_protocol:enabled — sdb dlog returns nothing there, with no error).
# Available only where capability shows intershell_support:enabled
# (verified on the common emulator).
# On the TV emulator, read the foreground `flutter-tizen run` console instead.

set -eu

DEVICE_ID="${DEVICE_ID:-192.168.0.101:26101}"

# Flutter console + engine + a custom plugin tag
sdb -s "$DEVICE_ID" dlog \
    'ConsoleMessage:I' \
    'FlutterEngine:I' \
    'FooTizen:V' \
    '*:S'

# Drop the final '*:S' to see everything else.

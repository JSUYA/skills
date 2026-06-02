#!/usr/bin/env bash
# Filter dlog to Flutter-relevant tags only.
# Adjust DEVICE_ID and TAG to taste.
#
# NOTE: dlog is blocked on the secured Samsung TV emulator (capability shows
# secure_protocol:enabled — sdb dlog returns nothing there, with no error).
# Works on real Samsung TVs in Developer Mode and on the common emulator.
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

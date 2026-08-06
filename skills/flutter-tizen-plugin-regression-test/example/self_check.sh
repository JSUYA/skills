#!/usr/bin/env bash

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: > "$WORK/clean.log"
printf 'Unhandled Exception: boom\n' > "$WORK/failing.log"

bash "$HERE/log_analysis.sh" "$WORK/clean.log" >/dev/null
if bash "$HERE/log_analysis.sh" "$WORK/failing.log" >/dev/null; then
    echo "log analyzer accepted a known failure" >&2
    exit 1
fi

echo "log analyzer self-check passed"

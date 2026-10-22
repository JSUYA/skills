#!/usr/bin/env bash
# Bootstrap a host for flutter-tizen development.
# Companion to ../SKILL.md.

set -euo pipefail

# Preserve the configured environment unless an explicit override was supplied.
if [[ -n "${FLUTTER_TIZEN_HOME:-}" ]]; then
    export PATH="$FLUTTER_TIZEN_HOME/bin:$PATH"
fi
if [[ -n "${TIZEN_SDK_TOOLS:-}" ]]; then
    export PATH="$TIZEN_SDK_TOOLS:$PATH"
fi

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

step "1. Tool access"
flutter-tizen --version || fail "flutter-tizen could not run — check its installation and PATH"
sdb version || fail "sdb could not run — check the configured SDK tools PATH"

step "2. Tizen toolchain"
doctor_output=$(flutter-tizen doctor -v) || { printf '%s\n' "$doctor_output"; fail "doctor command failed"; }
printf '%s\n' "$doctor_output"
# shortcut: match current English doctor output; update if its status format changes.
grep -Fq '[✓] Tizen toolchain' <<< "$doctor_output" \
    || fail "Tizen toolchain not verified — resolve its doctor findings"

step "3. Certificate profile"
profiles=$(tizen security-profiles list) || { printf '%s\n' "$profiles"; fail "certificate query failed — profile state is unverified"; }
printf '%s\n' "$profiles"
awk 'NF > 1 && $NF == "O" {active = 1} END {exit !active}' <<< "$profiles" \
    || fail "no active certificate profile — select one in Certificate Manager"

step "4. Smoke build (debug, common profile; build only)"
WORK="$(mktemp -d)"
pushd "$WORK" >/dev/null
flutter-tizen create demo || fail "smoke project creation failed"
cd demo
flutter-tizen build tpk --debug --device-profile common --target-arch x86 \
    || fail "smoke build failed — inspect the log above"
ls build/tizen/tpk/
popd >/dev/null

step "Setup complete."

# Example: First-time flutter-tizen setup

Verify an installed Flutter-Tizen toolchain on Ubuntu 24.04 through to a signed smoke build.

## Files

- `setup.sh` — driver script: tool access, Tizen doctor status, active certificate profile, smoke build.

The script uses the existing shell environment; it does not default to a legacy SDK path. Optional `FLUTTER_TIZEN_HOME` and `TIZEN_SDK_TOOLS` overrides prepend explicitly supplied directories to `PATH`. Configure the actual `tizen` launcher directory separately if it is not on `PATH` (it may be under the SDK's `tools/ide/bin`).

It runs `sdb version` directly and does not query executable locations or require the legacy CLI version. It requires a healthy **Tizen toolchain**, not a globally clean doctor result, and verifies an active certificate row instead of just the list header. Failed commands or missing required evidence stop the script. If an agent host denies a required check, follow the skill's supported alternative query and report the result; do not use this script to conceal a denied command.

## Scenario

Run `bash setup.sh` after installing the VS Code Extension for Tizen, flutter-tizen, and a certificate profile. It creates a temporary demo project and a signed common/x86/debug package; this is a build-only smoke check, not validation for a particular device ABI. It does not install packages on a device or change certificates.

---
name: flutter-tizen-setup
description: Install and verify the flutter-tizen toolchain (Tizen SDK, sdb, certificate profile, flutter-tizen CLI). Use when bootstrapping a new development host, when `flutter-tizen doctor` reports missing components, when `sdb` or `tizen` CLI is not found or a certificate profile is missing, or before a clean-room device build.
metadata:
  target: flutter-tizen
  category: environment
  last_modified: Mon, 19 Oct 2026 00:00:00 GMT
---
# Setting up flutter-tizen

## Prerequisites

Confirm the host environment before installing anything:

- 64-bit Linux (Ubuntu 22.04 / 24.04 verified), macOS x64, or Windows x64.
- `git`, `unzip`, `bash`, Python 3 available on `PATH`.
- For the Tizen emulator on Linux, HW virtualization (Intel VT-x / AMD-V) must be enabled in BIOS. On Ubuntu 24.04, install `libsdl1.2debian` if the emulator fails to launch.
- For TV / RPi targets, the host PC and the device must reach each other on the same L2 network.

## Reuse or install the Tizen SDK

Tizen Studio 6.1 was the last supported standalone release; the `VS Code Extension for Tizen` is now the recommended channel for the Tizen SDK.

If flutter-tizen is already installed, run `flutter-tizen doctor -v` first. Reuse the SDK it reports when the Tizen toolchain check passes; do not reinstall it or rewrite `PATH` just to discover executable locations.

1. If no usable SDK is installed, install the **VS Code Extension for Tizen**. An existing legacy Tizen Studio installation can be reused where the host policy permits it.
2. Open `Tizen: Package Manager` from the Command Palette and install:
   - `[Advanced] - [6.0 IOT-Headed + Mobile]` — required by flutter-tizen for the base build.
   - `[Advanced] - [9.0 Tizen or later]` — required only to use Tizen emulators.
   - The TV 9.0 emulator image — required only for TV emulator targets.
3. If shell tools are unavailable, use the installation location reported by the extension or SDK manager to configure their `PATH` entries. Use the actual executable directories: `sdb` is under `tools`, while the legacy `tizen` launcher may be under `tools/ide/bin`. Do not assume both live in the same directory or search the whole home directory for `sdb`.

   For a custom SDK location, Flutter-Tizen accepts `TIZEN_SDK` pointing to the SDK root. It also reads the extension's `.tizen.path.config`. The `tizen-sdk-skills` plugin uses a separate `.tizen.sdk.path.config`, configured through `tizen-sdk-init`; initializing that plugin does not configure Flutter-Tizen. Compare the SDK locations they report before using both. `TIZEN_SDK_PATH` is not a substitute for these settings.

   On Windows, configure the user `Path` as documented in the official [windows-install.md](https://github.com/flutter-tizen/flutter-tizen/blob/master/doc/windows-install.md).

   Verify shell access with `sdb version`. Check certificate access separately with `tizen security-profiles list`. Neither requires a preceding executable-location query or a CLI version query.

## Install flutter-tizen

`flutter-tizen` ships its own pinned Flutter SDK under `flutter-tizen/flutter` and always uses it, so an upstream `flutter` install can coexist. Call `flutter-tizen` by name for Tizen work; a `flutter` found first on `PATH` may be another version and has no Tizen device.

1. Clone the tool:
   ```sh
   git clone https://github.com/flutter-tizen/flutter-tizen.git
   ```
2. Add `flutter-tizen/bin` to `PATH`:
   ```sh
   export PATH="$PWD/flutter-tizen/bin:$PATH"
   ```
3. Trigger the first-run bootstrap (downloads the bundled Flutter SDK and engine artifacts):
   ```sh
   flutter-tizen --version
   ```

## Create a certificate profile

Tizen refuses to install unsigned packages — even on the emulator. Reuse a valid existing certificate profile; create one when missing:

1. Easiest: use **Certificate Manager** in the VS Code extension. Pick `Create Samsung Certificate` when unsure.
2. CLI alternative (after `tizen` is on `PATH`):
   ```sh
   tizen security-profiles add -n my-profile \
       -a /path/to/author.p12 -p author_password \
       -d /path/to/distributor.p12 -dp distributor_password
   tizen security-profiles list
   ```
3. When creating a distributor certificate, register the target device's `DUID`. For an emulator, run it first; the DUID then appears in Certificate Manager's device list automatically.
4. Pass the profile name at build time when the active profile is wrong: `flutter-tizen build tpk --security-profile my-profile`.

## Verify the toolchain

Run each check as a **separate tool invocation** so a rejected command cannot prevent unrelated checks from executing:

```sh
flutter-tizen doctor -v
sdb version
sdb devices
flutter-tizen devices
tizen security-profiles list
```

What the output must show:

- `flutter-tizen doctor` reports a green check for **Tizen toolchain**. Resolve Flutter/toolchain errors relevant to the Tizen task. The bundled Flutter's unknown-channel warning and missing Android/iOS/web tooling do not prevent a Tizen-only build.
- Before device execution, `sdb devices` lists the selected target as `device` (not `offline` or `unauthorized`), and `flutter-tizen devices` lists its matching ID. A build-only check does not require a connected device.
- The certificate list contains the intended profile. For the default build, require an active profile row (`O` in the `Active` column), not just the table header; otherwise select a valid profile explicitly at build time.

If `flutter-tizen doctor` says `To install missing package(s)`, install the listed package from Package Manager and re-run; the missing-package check is the most common false-`doctor` for new hosts.

### Working with SDK command guards

The installed `tizen-sdk-skills` hooks can reject executable-location searches, legacy SDK path commands, and `tizen version` even when the tools exist. These are not required preflight checks. Keep CLI version collection optional; the SDK version printed by `doctor` is not the CLI version.

Record each check as passed, failed, denied by policy, or not run. A denied version query means **version not collected**, not SDK missing. A denied required check remains unverified until an allowed equivalent succeeds. If a shell tool is unavailable, use the installed SDK skill's documented device/certificate query when available and initialized, or the extension UI; do not guess runner paths or make the SDK plugin a prerequisite. Report any unresolved check explicitly. Do not hide a denied command in a script or disable hooks to retry it.

## Workflow: First-Time Setup

Copy this checklist and tick items as completed:

### Task Progress
- [ ] **Step 1: Verify host prerequisites.** OS, `git`, `unzip`, Python 3 present; virtualization enabled if emulator targets are needed.
- [ ] **Step 2: Reuse or install Tizen SDK** with `6.0 IOT-Headed + Mobile` (and optionally `9.0` + TV 9.0 image).
- [ ] **Step 3: Verify shell access** with `sdb version`; configure actual tool directories only if needed. Query certificate profiles separately.
- [ ] **Step 4: Clone flutter-tizen** and put `bin/` on `PATH`; run `flutter-tizen --version` to bootstrap.
- [ ] **Step 5: Verify or create a certificate profile** via Certificate Manager (or `tizen security-profiles add`).
- [ ] **Step 6: If device execution is needed, connect the target**, then check `sdb devices` and `flutter-tizen devices` agree on its ID.
- [ ] **Step 7: Run `flutter-tizen doctor -v`** and resolve errors relevant to Tizen development. Report unrelated platform issues separately.
- [ ] **Step 8: Smoke build.** `flutter-tizen create demo && cd demo && flutter-tizen build tpk --debug --device-profile common` must succeed end-to-end.

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| `flutter-tizen doctor` says `Tizen toolchain ✗ To install missing package(s)` | Required SDK package not installed | Open Tizen Package Manager and install the package(s) listed by `doctor -v` |
| `sdb devices` shows `unauthorized` | Device hasn't accepted the host RSA key | Confirm the developer-mode prompt on the device |
| Certificate Manager refuses to create a distributor cert | Device DUID not registered | Connect the device first so its DUID is auto-populated |
| `flutter-tizen` invokes the wrong Flutter SDK | Upstream `flutter` is earlier on `PATH` | Put `flutter-tizen/bin` ahead of any other Flutter on `PATH`, or use absolute paths |
| Emulator fails to start on Ubuntu 24.04 | Missing legacy SDL runtime | `sudo apt install libsdl1.2debian` |
| `Currently on an unknown channel` warning from `doctor` | flutter-tizen's bundled Flutter uses a `user-branch` channel | Expected — this warning can be ignored for flutter-tizen |

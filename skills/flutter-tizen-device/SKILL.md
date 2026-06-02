---
name: flutter-tizen-device
description: Connect to and run Flutter apps on Tizen devices and emulators using `sdb`, `flutter-tizen run`, and `sdb dlog`. Use when bringing up a TV / RPi / emulator target, when `sdb devices` shows offline or unauthorized, when filtering noisy device logs, or when attaching a debugger to a running app.
metadata:
  target: flutter-tizen
  category: device
  last_modified: Wed, 27 May 2026 08:02:04 GMT
---
# Connecting, running, and logging Tizen targets

## Concepts

`sdb` (Samsung Debug Bridge) is Tizen's equivalent of `adb`. `flutter-tizen` talks to devices exclusively through `sdb`, so anything that breaks `sdb devices` breaks every flutter-tizen command. A few rules:

- A USB-connected device uses an `sdb` daemon over USB.
- A network-connected TV / RPi / emulator uses `sdb connect <ip>:<port>` (default port `26101`).
- Every flutter-tizen invocation that touches a device accepts `-d <device-id>`. If multiple devices are connected and `-d` is omitted, the command will error.

## Connecting a device

### Emulator

A running Tizen emulator is auto-registered as `emulator-26101` (or `26103`, `26105`, … for additional instances).

```sh
flutter-tizen emulators                          # list available emulator images
flutter-tizen emulators --launch <emulator-id>   # start one
sdb devices                                      # verify it shows up
```

### Real TV (Samsung)

1. Enable Developer Mode on the TV (Apps → App Settings → enter `12345`, enable Developer Mode, set the host PC IP).
2. From the host:
   ```sh
   sdb connect <tv-ip>          # uses port 26101 by default
   sdb devices                  # should list <tv-ip>:26101 as device
   ```
3. Power-cycling the TV usually drops the connection; reconnect with `sdb connect` each session.

### Raspberry Pi (Tizen)

After flashing Tizen to the SD card and booting, configure sdbd on the device, then `sdb connect <rpi-ip>` from the host.

## Selecting the active device

```sh
flutter-tizen devices                      # list all reachable Flutter devices
flutter-tizen -d emulator-26101 run        # explicit selection
flutter-tizen -d <substring> run           # prefix match also works
```

When scripting, prefer full device IDs over prefixes — prefix matching is ambiguous when two emulators are running.

## Running an app

```sh
# Default: debug mode, hot reload enabled, foreground attach
flutter-tizen -d <id> run

# Performance mode (AOT, instrumentation on)
flutter-tizen -d <id> run --profile

# Delay app execution until a debugger attaches
flutter-tizen -d <id> run --start-paused
```

While the app runs, keypresses in the terminal are forwarded:

- `r` — hot reload
- `R` — hot restart
- `p` — toggle `debugPaintSizeEnabled` overlay
- `o` — toggle platform (only useful for non-Tizen platforms)
- `q` — quit and detach

`flutter-tizen run` is the only flutter-tizen command that builds *and* installs *and* launches; for already-installed apps see [Attaching a debugger](#attaching-a-debugger).

## Reading device logs (dlog)

Tizen's logging system is `dlog`, surfaced via `sdb dlog`. By default it dumps every tag on every priority — useless. Always filter.

> **The Samsung TV emulator blocks `sdb dlog` and `sdb shell`.** Verified on `T-samsung-10.0-x86_64`: its `sdb capability` reports `secure_protocol:enabled` and `intershell_support:disabled`, so every `sdb dlog …` returns 0 lines and every `sdb shell …` (incl. `pgrep`) returns nothing — silently, with no error. On that target, read logs from the **foreground `flutter-tizen run` console** instead (it streams over the Dart VM service, not dlog). `sdb dlog`/`sdb shell` are available only where `sdb capability` shows `intershell_support:enabled` — verified on the **common** emulator. Check the target first:
>
> ```sh
> sdb -s <id> capability | grep -E 'intershell_support|secure_protocol'
> ```

### Filter by tag

```sh
# Console output from the Flutter app
sdb -s <id> dlog ConsoleMessage:D *:S

# Flutter engine internals
sdb -s <id> dlog FlutterEngine:V *:S

# Most-useful default for Flutter apps (console + engine + your own native tag)
sdb -s <id> dlog ConsoleMessage:V FlutterEngine:I MyPlugin:V *:S
```

The `<tag>:<priority>` syntax mirrors logcat: `V`erbose, `D`ebug, `I`nfo, `W`arn, `E`rror, `F`atal, `S`ilent. `*:S` silences every tag not explicitly listed.

### Filter by process / appid

```sh
# Print only lines from a specific PID
sdb -s <id> shell pgrep -af <your-app-binary>
sdb -s <id> dlog --pid <pid>

# Clear the ring buffer before reproducing a bug
sdb -s <id> dlog -c
```

### Saving logs

```sh
sdb -s <id> dlog ConsoleMessage:V *:S > app.log
sdb -s <id> dlog -d > snapshot.log    # dump and exit
```

## Attaching a debugger

Direct `flutter-tizen run` already attaches the Dart VM service — and is the **only** option on the secured TV emulator, where the dlog-grep step below returns nothing (see the dlog caveat above). For an app that is already running (e.g. launched by tapping its icon) on a dlog-capable target, attach manually:

1. Start the app on the device.
2. Tail dlog for the VM Service URL:
   ```sh
   sdb -s <id> dlog ConsoleMessage:V *:S | grep -i 'observatory\|vm service\|dart vm'
   ```
   Look for a line like `The Dart VM service is listening on http://127.0.0.1:<port>/...`.
3. Attach:
   ```sh
   flutter-tizen -d <id> attach --debug-url http://127.0.0.1:<port>/<token>=/
   ```
   The trailing `=/` is part of the URL — keep it.

For VS Code, the bundled `flutter-tizen: Attach (project)` configuration performs steps 2-3 automatically.

## Workflow: Bring Up a Target and Tail Logs

### Task Progress
- [ ] **Step 1: Confirm connectivity.** `sdb devices` shows the target as `device` (not `offline`).
- [ ] **Step 2: Select the device.** Capture the exact `device-id` and use it as `-d <id>` for every subsequent command.
- [ ] **Step 3: Build + run.** `flutter-tizen -d <id> run` (or `--profile` / `--release`).
- [ ] **Step 4: Clear and tail logs in a second shell.** (Skip on the secured TV emulator — dlog is blocked there; use the foreground `flutter-tizen run` console instead.)
   ```sh
   sdb -s <id> dlog -c && sdb -s <id> dlog ConsoleMessage:V FlutterEngine:I *:S
   ```
- [ ] **Step 5: Reproduce the issue / exercise the feature.** Use `r` for hot reload as needed.
- [ ] **Step 6: If debugging an externally-launched app**, grep dlog for the VM service URL and `flutter-tizen attach --debug-url=...`.
- [ ] **Step 7: Detach cleanly** with `q` or `Ctrl-C`. Re-running without `q` leaves zombie sdb shell pipes.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `sdb devices` shows `offline` | Device daemon dropped the host RSA fingerprint | `sdb kill-server && sdb start-server && sdb connect <ip>` |
| `No connected Tizen devices` from `flutter-tizen` | sdb sees the device but flutter-tizen does not | Check `sdb -s <id> capability` succeeds; if it hangs, restart the device |
| `flutter-tizen run` hangs at `Installing TPK` | Stale install of the same package conflicts | `sdb -s <id> uninstall <appid>` then retry |
| `dlog` output stops abruptly | TV firmware aggressively rotates the log buffer | Add `-b main -b system` flags, or save to file |
| `attach --debug-url` fails with `Connection refused` | The app crashed before printing the VM service URL, or printed an `http://...:0/` URL (port not yet allocated) | Restart the app with `--start-paused` and re-grep |
| Multiple emulators selected ambiguously | Prefix match collision | Pass the full ID (`emulator-26101`, not `emulator`) |

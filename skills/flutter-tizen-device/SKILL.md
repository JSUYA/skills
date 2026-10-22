---
name: flutter-tizen-device
description: Connect to and run Flutter apps on Tizen devices and emulators using `sdb` and `flutter-tizen run`. Use when bringing up a TV / RPi / emulator target, when `sdb devices` shows offline or unauthorized, when reading app logs, or when attaching a debugger to a running app.
metadata:
  target: flutter-tizen
  category: device
  last_modified: Mon, 19 Oct 2026 00:00:00 GMT
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
- `h` — list **all** interactive commands (the full set below is hidden until you press `h`)
- `d` — detach (leave the app running, stop `flutter-tizen run`)
- `c` — clear the screen
- `q` — quit and detach

The default key menu printed by `flutter-tizen run` is exactly `r R h d c q` (verified). Less-common keys such as `p` (toggle `debugPaintSizeEnabled`) and `o` (toggle platform) are only listed after pressing `h`.

`flutter-tizen run` is the only flutter-tizen command that builds *and* installs *and* launches; for already-installed apps see [Attaching a debugger](#attaching-a-debugger).

## Reading app logs

> **Tizen TV targets ship a locked-down `sdb`** — verified on `T-samsung-10.0-x86_64`: `sdb capability` shows `secure_protocol:enabled` + `intershell_support:disabled`, so log/shell access over `sdb` is unavailable (silently, with no error). Read app output from the **foreground `flutter-tizen run` session** instead.

`flutter-tizen run` streams Dart `print`/`debugPrint` and Flutter engine messages in the terminal it runs in:

```sh
flutter-tizen -d <id> run                    # logs stream live in this terminal
flutter-tizen -d <id> run 2>&1 | tee app.log # also capture to a file
```

The same session prints the Dart VM Service URL (for DevTools) and accepts the hot-reload keys below.

## Attaching a debugger

`flutter-tizen run` builds, installs, launches, **and** attaches the Dart VM service in one step — prefer it. It streams logs and prints the VM Service URL in the foreground.

For a separate CLI attach session, use the **device-side VM Service URL**. Start the app with `flutter-tizen -v -d <id> run` and capture the line labelled `VM Service URL on device:`. Keep the app alive (use `d` to detach the original terminal if needed), then pass that URI:

```sh
flutter-tizen -d <id> attach --debug-url http://127.0.0.1:<device-port>/<device-token>=/
```

Keep the scheme, port, token, and trailing slash from that device URI. The normal `A Dart VM Service ... is available at:` output is a **host-forwarded/DDS address**; passing it to CLI attach can forward the host port as a device port and repeatedly reset the connection. HTTP is valid for CLI attach. If the device URI is unavailable, use the existing `run` session rather than guessing the port.

For VS Code, the bundled `flutter-tizen: Attach (project)` configuration automates this.

## Driving the app from the Dart MCP server

The Dart MCP server (`dart mcp-server`) cannot launch a Tizen app: `launch_app` is off by default and drives upstream `flutter`, which has no Tizen device backend. It can attach to an app that `flutter-tizen run` started, through DTD first and by VM Service URI as the fallback:

1. `flutter-tizen -d <id> run` and keep that session alive. It starts a Dart Tooling Daemon for the project.
2. Run the MCP server from the project directory. `dtd` → `listDtdUris` lists that daemon; `dtd` → `connect` with its `ws://` URI registers the app (`listConnectedApps` shows it with its VM Service URI). The tools below then work without an `appUri`.
3. If DTD does not list the app, connect by **host WebSocket URI**: take `ws://127.0.0.1:<host-port>/<host-token>=/ws` from the DevTools line (`?uri=...`), or convert the `http://127.0.0.1:<host-port>/<host-token>=/` host URL from `A Dart VM Service ... is available at:` by changing the scheme and appending `ws` after the trailing `/`. Call `vm_service` with `command: connect` and that URI as `appUri`; passing HTTP directly fails with `Unsupported URL scheme 'http'` in Dart MCP 1.2.1.
4. Once connected, the app-level tools work as they do on any other platform:

| Tool | Use |
|---|---|
| `hot_reload` / `hot_restart` | Push an edit without leaving the terminal |
| `get_runtime_errors` | Last exceptions, including ones that scrolled past in the console |
| `widget_inspector` (`get_widget_tree`) | See what is actually mounted before guessing at finders |
| `flutter_driver_command` | Tap / scroll / enter text against real widgets |

Prefer the Dart SDK that ships with flutter-tizen (`flutter-tizen`'s bundled `flutter/bin/dart`) for the MCP server; a separate Dart install of the same version also works.

## Workflow: Bring Up a Target and Read Logs

### Task Progress
- [ ] **Step 1: Confirm connectivity.** `sdb devices` shows the target as `device` (not `offline`).
- [ ] **Step 2: Select the device.** Capture the exact `device-id` and use it as `-d <id>` for every subsequent command.
- [ ] **Step 3: Build + run.** `flutter-tizen -d <id> run` (or `--profile` / `--release`). Logs stream in this terminal.
- [ ] **Step 4: Reproduce the issue / exercise the feature.** Watch the `run` console; use `r` for hot reload as needed. To keep a copy, re-run with `2>&1 | tee app.log`.
- [ ] **Step 5: If a separate CLI attach is needed**, use `flutter-tizen -d <id> attach --debug-url <device-uri>` from the verbose `VM Service URL on device:` line. For Dart MCP, discover the app through `dtd` first, then fall back to the host WebSocket URI.
- [ ] **Step 6: Detach cleanly** with `q` or `Ctrl-C`.

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `sdb devices` shows `offline` | Device daemon dropped the host RSA fingerprint | `sdb kill-server && sdb start-server && sdb connect <ip>` |
| `No connected Tizen devices` from `flutter-tizen` | sdb sees the device but flutter-tizen does not | Check `sdb -s <id> capability` succeeds; if it hangs, restart the device |
| `flutter-tizen run` hangs at `Installing TPK` | Stale install of the same package conflicts | `sdb -s <id> uninstall <appid>` then retry |
| `flutter-tizen run` console shows no app output | App logged nothing yet, or crashed at startup | Trigger a `debugPrint`; for startup crashes re-run with `--start-paused` |
| CLI attach repeatedly resets the connection | A host-forwarded/DDS URI was used as a device URI | Use the verbose `VM Service URL on device:` value, keeping its HTTP scheme and device port |
| `attach --debug-url` fails with `Connection refused` | The app stopped or its device VM port is unavailable | Restart with `flutter-tizen -v -d <id> run --start-paused`, wait for a nonzero device VM port, and keep the app alive |
| Dart MCP connect reports `Unsupported URL scheme 'http'` | An HTTP URI was passed to the WebSocket client | Convert the host VM URI to `ws://.../ws`, preserving the token path |
| Multiple emulators selected ambiguously | Prefix match collision | Pass the full ID (`emulator-26101`, not `emulator`) |

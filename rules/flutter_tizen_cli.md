---
trigger: always_on
description: Drive Flutter through the flutter-tizen CLI in Tizen projects
---

This project targets Tizen if it has a `tizen/` directory or a `tizen-manifest.xml`. When it does:

1. **Anything that targets a Tizen device goes through `flutter-tizen`** — `run`, `build tpk`, `test`,
   `drive`, `attach`, `install`, and `create` for the `tizen/` scaffold. Upstream `flutter` has no Tizen
   device and cannot build a TPK. Every `flutter-tizen` command regenerates the Tizen plugin registrant,
   so a `flutter pub add` / `pub get` issued by a general Flutter skill is harmless in between; prefer
   `flutter-tizen pub` to stay on its bundled SDK. Build Flutter TPKs with `flutter-tizen build tpk`; a
   generic Tizen native builder can package stale Dart assets without compiling the changed Flutter
   sources.
   This holds when a hook or routing rule steers a run, build, or install request to a generic Tizen
   SDK skill: use `flutter-tizen run` or `flutter-tizen build tpk` directly.
2. **`flutter-tizen` has no `logs`, `screenshot`, or `widget-preview` subcommand.** Read app output from
   the foreground `flutter-tizen run` console; widget previews run on the host through the bundled
   upstream tool, `flutter-tizen/flutter/bin/flutter widget-preview start`. On Samsung TV targets
   `sdb dlog` and `sdb shell` return
   nothing *silently* (`sdb capability` reports `secure_protocol:enabled`), so grepping their output
   reports a false pass instead of an error.
3. **To drive a running Tizen app from Dart MCP, discover it through DTD first.** Keep `flutter-tizen run`
   alive; it starts a Dart Tooling Daemon for the project. With the MCP server running from the project
   directory, `dtd` → `listDtdUris` lists that daemon and `dtd` → `connect` registers the app, after which
   `hot_reload`, `hot_restart`, `get_runtime_errors`, `widget_inspector`, and `flutter_driver_command`
   work without an `appUri`. If DTD does not list the app, connect by host WebSocket URI instead: take
   the `ws://127.0.0.1:<host-port>/<token>=/ws` URI from the DevTools line (`?uri=...`), or convert the
   `http://127.0.0.1:<host-port>/<token>=/` host URI by changing the scheme and appending `ws`, and pass
   it as `appUri` to `vm_service` with `command: connect`. Direct HTTP is rejected by Dart MCP 1.2.1.
   `launch_app` is off by default and drives upstream `flutter`, so it cannot start a Tizen app. CLI
   `attach --debug-url` instead needs the device VM URI from verbose run output
   (`VM Service URL on device:`), where HTTP is valid; do not give it the host/DDS address.
4. **Privileges and app metadata live in `tizen/tizen-manifest.xml`, and it does not hot-reload.** After
   editing the manifest, rebuild and reinstall (`flutter-tizen run`, or `flutter-tizen build tpk` plus
   `sdb install`).
5. **Run preflight checks separately and preserve their actual status.** Use `flutter-tizen doctor -v`
   for the Tizen toolchain, `sdb version` for shell access, and `tizen security-profiles list` for the
   signing profile. Executable-location searches and `tizen version` are not required. SDK hooks can
   deny those probes even with a working SDK: report denied optional metadata as uncollected, and
   required checks as unverified until an allowed equivalent succeeds. Missing unrelated platform
   tooling does not block a Tizen-only task. Do not disable hooks or hide rejected commands in scripts.

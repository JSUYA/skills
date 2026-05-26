# Flutter-Tizen Agent Skills

Agent skills for [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) — Samsung's Flutter embedder for Tizen targets (TV, IoT-headed, RPi, wearable emulator profiles).

These skills complement the upstream [flutter/skills](https://github.com/flutter/skills) and [dart-lang/skills](https://github.com/dart-lang/skills) repositories: install those for generic Flutter / Dart workflows, and use this set for anything Tizen-specific (TPK packaging, `sdb`/`dlog`, certificate profiles, TV remote input, `tizen-manifest.xml` privileges, Tizen Native plugin scaffolding, on-device integration tests).

The repository mirrors the structure of upstream `flutter/skills` so the same generator and linter tooling work without modification.

## Installation

To install all skills into your project, run:

```bash
npx skills add flutter-tizen/skills --skill '*' --agent universal
```

The `--agent universal` flag drops the skills into `.agents/skills/`, the standard location most agents read from.

## Updating Skills

```bash
npx skills update
```

## Available Skills

| Skill | Description | Example prompt |
|---|---|---|
| [flutter-tizen-setup](skills/flutter-tizen-setup/SKILL.md) | Install and verify the flutter-tizen toolchain — Tizen SDK, `sdb`, `tizen`, certificate profile, `flutter-tizen doctor`. Use when bootstrapping a new development host or before a clean-room device build. | Set up flutter-tizen on a fresh Ubuntu 24.04 host and confirm `doctor` is green. |
| [flutter-tizen-build-tpk](skills/flutter-tizen-build-tpk/SKILL.md) | Build, sign, and inspect TPK packages per device profile (common / tv / mobile), ABI, and build mode. Use when producing a deployable artifact or troubleshooting signing failures. | Produce a signed release TPK for Samsung TV 2022. |
| [flutter-tizen-device](skills/flutter-tizen-device/SKILL.md) | Connect to Tizen devices and emulators with `sdb`, run apps with `flutter-tizen run`, filter `dlog`, attach the Dart VM debugger. Use when bringing up a TV / RPi / emulator target or filtering noisy logs. | Connect my TV at 192.168.0.101 and tail Flutter console + engine logs only. |
| [flutter-tizen-tv-remote-input](skills/flutter-tizen-tv-remote-input/SKILL.md) | Wire D-pad focus traversal and OK / Back / color / media key handling via `Focus`, `Shortcuts`, and `Actions`. Use when targeting Samsung TV 2021+ or when remote keys do nothing inside a Flutter view. | Make the home screen navigable with the TV remote, including OK to activate and Back to pop. |
| [flutter-tizen-tizen-tv-ui](skills/flutter-tizen-tizen-tv-ui/SKILL.md) | TV-friendly UI patterns — overscan / safe area, large default font scale, visible focus highlight, high-contrast accessibility, and screen-reader labelling. Use when a layout is cut off on TV, when text is unreadable at 3 m, or when an a11y audit is required. | TV-ize this app: safe area, larger fonts, focus ring, screen-reader labels. |
| [flutter-tizen-use-plugins](skills/flutter-tizen-use-plugins/SKILL.md) | Pick the right Tizen plugin (endorsed `*_tizen`, unendorsed, or Tizen-exclusive), declare privileges in `tizen-manifest.xml`, and request runtime permissions. Use when a cross-platform plugin lacks Tizen support. | Add location support to my app on Tizen, including the privilege declaration. |
| [flutter-tizen-create-plugin](skills/flutter-tizen-create-plugin/SKILL.md) | Scaffold a C++ Tizen plugin, wire a method channel, link Tizen Native libraries, declare privileges (public / partner / platform), wire runtime privacy-permission requests, validate via the example app. Use when no existing plugin wraps a needed Tizen Native API. | Wrap the Tizen `system_info` API as a new `system_info_tizen` plugin. |
| [flutter-tizen-app-lifecycle](skills/flutter-tizen-app-lifecycle/SKILL.md) | Map Tizen native lifecycle callbacks (`app_create`, `app_pause`, `app_resume`, `app_terminate`, low-memory, locale) onto Flutter `AppLifecycleState` and `WidgetsBindingObserver`. Use when state must be persisted across pause/resume. | Save the current scroll position when the user presses Home, restore it on resume. |
| [flutter-tizen-app-control](skills/flutter-tizen-app-control/SKILL.md) | Send and receive Tizen App Control intents — start another app by operation / URI / MIME, receive a launch request, return a reply, and implement deep linking. Use when integrating with the Tizen launcher / Settings / another app, or when wiring deep-link entry points. | Open the system Settings app from Flutter, then accept a launch back from it. |
| [flutter-tizen-background-service](skills/flutter-tizen-background-service/SKILL.md) | Build a Tizen service app alongside the UI app and wire two-way communication via `messageport_tizen`. Use when work must continue after the UI is paused (sync, telemetry, sensor polling) or when a long-running task must survive UI termination. | Add a service app that polls a sensor and forwards results to the UI. |
| [flutter-tizen-integration-test-device](skills/flutter-tizen-integration-test-device/SKILL.md) | Run `integration_test` against a Tizen device or emulator using `flutter-tizen test --device-id=<id>`; capture screenshots and perf timelines; wire a CI lane. Use when validating end-to-end flows on Tizen hardware. | Add an integration test that drives the D-pad through the settings flow on the TV emulator. |

## Repository Layout

```
flutter-tizen/skills
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── LICENSE
├── pubspec.yaml               # Dart workspace (matches upstream)
├── resources/
│   └── flutter_tizen_skills.yaml
├── skills/
│   ├── flutter-tizen-app-control/SKILL.md
│   ├── flutter-tizen-app-lifecycle/SKILL.md
│   ├── flutter-tizen-background-service/SKILL.md
│   ├── flutter-tizen-build-tpk/SKILL.md
│   ├── flutter-tizen-create-plugin/SKILL.md
│   ├── flutter-tizen-device/SKILL.md
│   ├── flutter-tizen-integration-test-device/SKILL.md
│   ├── flutter-tizen-setup/SKILL.md
│   ├── flutter-tizen-tizen-tv-ui/SKILL.md
│   ├── flutter-tizen-tv-remote-input/SKILL.md
│   └── flutter-tizen-use-plugins/SKILL.md
└── tool/
    ├── generator/             # vendored from flutter/skills
    ├── dart_skills_lint/      # vendored from flutter/skills
    └── dart_hooks/            # vendored from flutter/skills
```

Each `SKILL.md` follows the upstream `flutter/skills` shape: YAML frontmatter (`name`, `description`, `metadata`), a `Contents` table of contents, a numbered `Workflow:` checklist, and concrete examples / troubleshooting.

## Pipeline

Identical to upstream:

1. Edit `resources/flutter_tizen_skills.yaml` (the source of truth).
2. Generate or refresh `SKILL.md` files:
   ```bash
   cd tool
   dart run skills generate-skill --config ../resources/flutter_tizen_skills.yaml --output ../skills
   ```
   (Requires `GEMINI_API_KEY`.)
3. Validate:
   ```bash
   dart run dart_skills_lint
   ```
4. Refresh the table above:
   ```bash
   dart run skills update-readme
   ```

## Activation Hints

Agents activate a skill by matching the user's task against the `description` field. Trigger phrases for this set:

- "set up flutter-tizen", "doctor", "certificate profile" → `flutter-tizen-setup`
- "build TPK", "sign tpk", "device-profile tv" → `flutter-tizen-build-tpk`
- "sdb dlog", "tail logs from TV", "attach debugger" → `flutter-tizen-device`
- "D-pad", "TV remote", "focus traversal", "OK key" → `flutter-tizen-tv-remote-input`
- "TV safe area", "overscan", "font scale", "focus highlight", "TV accessibility" → `flutter-tizen-tizen-tv-ui`
- "privilege", "tizen-manifest" → `flutter-tizen-use-plugins`
- "new tizen plugin", "C++ Tizen plugin", "method channel", "ppm_request_permission" → `flutter-tizen-create-plugin`
- "AppLifecycleState", "pause/resume", "low-memory" → `flutter-tizen-app-lifecycle`
- "app control intent", "deep link", "launch another app" → `flutter-tizen-app-control`
- "service app", "messageport", "background worker" → `flutter-tizen-background-service`
- "integration test on TV", "flutter-tizen test", "device-id" → `flutter-tizen-integration-test-device`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Track feedback via GitHub issues against this repo.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

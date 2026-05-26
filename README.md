# Flutter-Tizen Agent Skills

Agent skills for [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) — Samsung's Flutter embedder for Tizen targets (TV, IoT-headed, RPi, wearable emulator profiles).

This set is intentionally narrow: six skills that cover the Tizen-only workflows where a generic Flutter/Dart agent would otherwise fail (toolchain, packaging, device wiring, remote input, plugin selection + privileges, plugin authoring). Install the upstream [flutter/skills](https://github.com/flutter/skills) and [dart-lang/skills](https://github.com/dart-lang/skills) repositories for everything else — generic Flutter, Dart language, layout, JSON, HTTP, routing, lifecycle, integration tests, accessibility.

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
| [flutter-tizen-build-tpk](skills/flutter-tizen-build-tpk/SKILL.md) | Build, sign, and inspect TPK packages per device profile (`common` or `tv`), ABI (`arm`/`arm64`/`x86`/`x64`), and build mode. Use when producing a deployable artifact or troubleshooting signing failures. | Produce a signed release TPK for Samsung TV 2022. |
| [flutter-tizen-device](skills/flutter-tizen-device/SKILL.md) | Connect to Tizen devices and emulators with `sdb`, run apps with `flutter-tizen run`, filter `dlog`, attach the Dart VM debugger. Use when bringing up a TV / RPi / emulator target or filtering noisy logs. | Connect my TV at 192.168.0.101 and tail Flutter console + engine logs only. |
| [flutter-tizen-tv-remote-input](skills/flutter-tizen-tv-remote-input/SKILL.md) | Wire D-pad focus traversal and OK / Back / color / media key handling via `Focus`, `Shortcuts`, and `Actions`. Use when targeting Samsung TV 2021+ or when remote keys do nothing inside a Flutter view. | Make the home screen navigable with the TV remote, including OK to activate and Back to pop. |
| [flutter-tizen-use-plugins](skills/flutter-tizen-use-plugins/SKILL.md) | Pick the right Tizen plugin (endorsed `*_tizen`, unendorsed, or Tizen-exclusive), declare privileges in `tizen-manifest.xml`, request runtime permissions. Use when a cross-platform plugin lacks Tizen support or when a `*_tizen` plugin throws `PRIVILEGE_DENIED`. | Add location support to my app on Tizen, including the privilege declaration. |
| [flutter-tizen-create-plugin](skills/flutter-tizen-create-plugin/SKILL.md) | Scaffold a C++ Tizen plugin, wire a method channel, link Tizen Native libraries via `USER_PKGS`, declare privileges (public / partner / platform), wire runtime privacy-permission requests, validate via the example app. Use when no existing plugin wraps a needed Tizen Native API. | Wrap the Tizen `system_info` API as a new `system_info_tizen` plugin. |

## What this set deliberately does NOT cover

- **Generic Flutter / Dart workflows** — JSON, HTTP, routing, layout, widget tests, integration tests, localization, responsive design, accessibility. Install upstream `flutter/skills` and `dart-lang/skills`.
- **`AppLifecycleState` / `WidgetsBindingObserver`** — already standard Flutter; upstream covers it.
- **App Control intents / deep linking** — see the [`tizen_app_control`](https://pub.dev/packages/tizen_app_control) plugin docs directly; routing logic is otherwise standard Flutter.
- **Tizen `<service-application>` (two-process)** — rare; covered ad-hoc via plugin docs + `flutter-tizen-use-plugins` for IPC privileges.
- **TV overscan / focus highlight styling** — folded into `flutter-tizen-tv-remote-input` (focus traversal). Generic 10-foot UI / a11y belongs to upstream a11y skills.

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
│   ├── flutter-tizen-build-tpk/SKILL.md
│   ├── flutter-tizen-create-plugin/SKILL.md
│   ├── flutter-tizen-device/SKILL.md
│   ├── flutter-tizen-setup/SKILL.md
│   ├── flutter-tizen-tv-remote-input/SKILL.md
│   └── flutter-tizen-use-plugins/SKILL.md
└── tool/
    ├── generator/             # vendored from flutter/skills
    ├── dart_skills_lint/      # vendored from flutter/skills
    └── dart_hooks/            # vendored from flutter/skills
```

Each `SKILL.md` follows the upstream `flutter/skills` shape: YAML frontmatter (`name`, `description`, `metadata`), a `Contents` table of contents, a numbered `Workflow:` checklist, an `example/` subdirectory with runnable snippets, and concrete pitfalls / troubleshooting.

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
- "build TPK", "sign tpk", "device-profile tv", "Tizen package is not authorized" → `flutter-tizen-build-tpk`
- "sdb dlog", "tail logs from TV", "attach debugger", "flutter-tizen run" → `flutter-tizen-device`
- "D-pad", "TV remote", "focus traversal", "OK key", "color key" → `flutter-tizen-tv-remote-input`
- "privilege", "tizen-manifest", "PRIVILEGE_DENIED", "messageport_tizen plugin" → `flutter-tizen-use-plugins`
- "new tizen plugin", "C++ Tizen plugin", "method channel", "wrap a Tizen Native API" → `flutter-tizen-create-plugin`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Track feedback via GitHub issues against this repo.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

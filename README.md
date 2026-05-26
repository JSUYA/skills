# Flutter-Tizen Agent Skills

Agent skills for [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) — Samsung's Flutter embedder for Tizen TV / IoT-Headed / RPi targets.

Six skills covering Tizen-only workflows where a generic Flutter agent fails: toolchain, packaging, device wiring, TV remote input, plugin selection + privileges, plugin authoring. Pair with upstream [flutter/skills](https://github.com/flutter/skills) and [dart-lang/skills](https://github.com/dart-lang/skills) for everything else.

## Skills

| Skill | Description | Example prompt |
|---|---|---|
| [flutter-tizen-setup](skills/flutter-tizen-setup/SKILL.md) | Install and verify the flutter-tizen toolchain — Tizen SDK, `sdb`, `tizen`, certificate profile, `flutter-tizen doctor`. | Set up flutter-tizen on a fresh Ubuntu 24.04 host and confirm `doctor` is green. |
| [flutter-tizen-build-tpk](skills/flutter-tizen-build-tpk/SKILL.md) | Build, sign, and inspect TPK packages per device profile (`common` / `tv`), ABI, and build mode. | Produce a signed release TPK for Samsung TV 2022. |
| [flutter-tizen-device](skills/flutter-tizen-device/SKILL.md) | Connect to Tizen devices/emulators via `sdb`, run apps with `flutter-tizen run`, filter `dlog`, attach the Dart VM. | Connect my TV at 192.168.0.101 and tail Flutter console + engine logs only. |
| [flutter-tizen-tv-remote-input](skills/flutter-tizen-tv-remote-input/SKILL.md) | Wire D-pad focus traversal and OK / Back / color / media key handling via `Focus`, `Shortcuts`, `Actions`. | Make the home screen navigable with the TV remote. |
| [flutter-tizen-use-plugins](skills/flutter-tizen-use-plugins/SKILL.md) | Pick the right `*_tizen` plugin, declare privileges in `tizen-manifest.xml`, request runtime permissions. | Add location support on Tizen, including the privilege declaration. |
| [flutter-tizen-create-plugin](skills/flutter-tizen-create-plugin/SKILL.md) | Scaffold a C++ Tizen plugin, wire a method channel, link Tizen Native libs via `USER_PKGS`, declare privileges. | Wrap the Tizen `system_info` API as a new `system_info_tizen` plugin. |

## Install

Drop the `skills/` subtree into the agent's skills directory. Most agents (Claude Code, Codex CLI, Gemini CLI, Cursor) read from one of:

- `<project>/.agents/skills/<skill-name>/SKILL.md`
- `~/.codex/skills/<skill-name>/SKILL.md` (Codex CLI)

Either copy or symlink each `skills/flutter-tizen-*` folder into the target directory.

## Layout

```
.
├── skills/<skill-name>/SKILL.md   # six SKILL.md files, each with example/
├── resources/flutter_tizen_skills.yaml  # generator source of truth
└── tool/                          # generator + dart_skills_lint (from flutter/skills)
```

`SKILL.md` follows the [Agent Skills spec](tool/dart_skills_lint/documentation/knowledge/SPECIFICATION.md): YAML frontmatter (`name`, `description`) plus Markdown body with a workflow checklist and runnable `example/` sources.

## Maintainers

Lint:

```bash
cd tool/dart_skills_lint
dart run bin/cli.dart -d ../../skills
```

Regenerate `SKILL.md` from the YAML manifest (requires `GEMINI_API_KEY`):

```bash
cd tool
dart run skills generate-skill --config ../resources/flutter_tizen_skills.yaml --output ../skills
```

## Contributing / License

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [LICENSE](LICENSE).

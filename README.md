# Flutter-Tizen Agent Skills

Agent skills for [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) — Samsung's Flutter embedder for Tizen TV / IoT-Headed / RPi targets.

Provides 6 Tizen-specific skills. Use with [flutter/skills](https://github.com/flutter/skills) for general Flutter development.

## Skills

| Skill                                                                          | Description                                       |
| ------------------------------------------------------------------------------ | ------------------------------------------------- |
| [flutter-tizen-setup](skills/flutter-tizen-setup/SKILL.md)                     | Install and verify Tizen SDK toolchain            |
| [flutter-tizen-build-tpk](skills/flutter-tizen-build-tpk/SKILL.md)             | Build, sign, and inspect TPK packages             |
| [flutter-tizen-device](skills/flutter-tizen-device/SKILL.md)                   | Connect devices via sdb, run apps, filter dlog    |
| [flutter-tizen-tv-remote-input](skills/flutter-tizen-tv-remote-input/SKILL.md) | Handle D-pad focus and remote key input           |
| [flutter-tizen-use-plugins](skills/flutter-tizen-use-plugins/SKILL.md)         | Use `*_tizen` plugins with privilege declarations |
| [flutter-tizen-create-plugin](skills/flutter-tizen-create-plugin/SKILL.md)     | Create C++ native plugins with method channels    |

## Install

```bash
# Install all skills
npx skills add JSUYA/flutter_tizen_skills --skill '*' --agent universal

# Install specific skills
npx skills add JSUYA/flutter_tizen_skills --skill flutter-tizen-setup,flutter-tizen-build-tpk

# Global install
npx skills add JSUYA/flutter_tizen_skills --skill '*' --global

# Update
npx skills update
```

For manual install, copy or symlink `skills/flutter-tizen-*/` folders to your target directory.

## Maintainers

```bash
# Lint
cd tool/dart_skills_lint
dart run bin/cli.dart -d ../../skills

# Regenerate SKILL.md (requires GEMINI_API_KEY)
cd tool
dart run skills generate-skill --config ../resources/flutter_tizen_skills.yaml --output ../skills
```

## License

[MIT License](LICENSE)

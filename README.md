# Flutter-Tizen Agent Plugins

Agent plugins for [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen), maintained by the Flutter-Tizen team.

This repository bundles Tizen-specific skills with the Dart MCP server for Claude Code, Codex, and Cursor. The existing skills-only install remains available for other agents. Use with [flutter/agent-plugins](https://github.com/flutter/agent-plugins) for general Flutter development.

## Skills

| Skill                                                                          | Description                                       |
| ------------------------------------------------------------------------------ | ------------------------------------------------- |
| [flutter-tizen-setup](skills/flutter-tizen-setup/SKILL.md)                     | Install and verify Tizen SDK toolchain            |
| [flutter-tizen-build-tpk](skills/flutter-tizen-build-tpk/SKILL.md)             | Build, sign, and inspect TPK packages             |
| [flutter-tizen-device](skills/flutter-tizen-device/SKILL.md)                   | Connect devices via sdb, run apps, filter dlog    |
| [flutter-tizen-tv-remote-input](skills/flutter-tizen-tv-remote-input/SKILL.md) | Handle D-pad focus and remote key input           |
| [flutter-tizen-use-plugins](skills/flutter-tizen-use-plugins/SKILL.md)         | Use `*_tizen` plugins with privilege declarations |
| [flutter-tizen-create-plugin](skills/flutter-tizen-create-plugin/SKILL.md)     | Create C++ native plugins with method channels    |


### For opensource dev
| Skill                                                                          | Description                                       |
| ------------------------------------------------------------------------------ | ------------------------------------------------- |
| [flutter-tizen-plugin-regression-test](skills/flutter-tizen-plugin-regression-test/SKILL.md) | Run regression tests for flutter-tizen plugins |

## Installation

Plugin installs require Dart 3.10.8 or newer on `PATH` for the bundled Dart MCP server.

### Skills only

The latest `skills` CLI requires Node.js 22.20.0 or newer.

```bash
# Install all skills
npx skills@1.5.21 add flutter-tizen/skills --skill '*' --agent universal --yes

# Install specific skills
npx skills@1.5.21 add flutter-tizen/skills --skill flutter-tizen-setup,flutter-tizen-build-tpk --agent universal --yes

# Global install
npx skills@1.5.21 add flutter-tizen/skills --skill '*' --global --yes

# Update
npx skills@1.5.21 update
```

For manual install, copy or symlink `skills/flutter-tizen-*/` folders to your target directory.

### Claude Code

```bash
claude plugin marketplace add flutter-tizen/skills
claude plugin install flutter-tizen@flutter-tizen
claude plugin marketplace list
```

### Codex

```bash
codex plugin marketplace add flutter-tizen/skills
codex plugin add flutter-tizen@flutter-tizen
codex plugin list --marketplace flutter-tizen
```

### Cursor

Copy this repository to `~/.cursor/plugins/local/flutter-tizen`, then restart Cursor. Cursor discovers the bundled skills and `.mcp.json` automatically.

## Maintainers

```bash
# Lint
cd tool/dart_skills_lint
dart run bin/cli.dart -d ../../skills

# Regenerate SKILL.md (requires GEMINI_API_KEY)
dart run tool/generator/bin/skills.dart generate-skill \
  resources/flutter_tizen_skills.yaml \
  --directory skills
```

> **Note:** The `tool/` directory (skill generator and linter) is sourced from [flutter/agent-plugins](https://github.com/flutter/agent-plugins) and kept in sync with its upstream updates.

## License

[BSD 3-Clause License](LICENSE)

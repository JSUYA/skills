# Contributing to Flutter-Tizen Skills

## Status

This repository is an MVP scaffolded as a companion to upstream [flutter/skills](https://github.com/flutter/skills). External contributions are not yet open while the initial skill set stabilises.

If you find a bug, want to request a new skill, or want a Tizen workflow added or refined, please [file an issue](https://github.com/flutter-tizen/skills/issues).

## Providing feedback on an existing skill

When filing an issue, include:

1. Which language model you used (Gemini 3.x, Claude Sonnet 4.6 / Opus 4.7, GPT-5, …).
2. Which agent harness you used (Claude Code, Gemini CLI, Antigravity, Cursor, Codex, …).
3. Logs that show the prompt used and the steps the agent took — which skill it picked, which MCP tools / shell commands it ran, and the final result.

## Requesting a new skill

Check the [next-skills issue](https://github.com/flutter-tizen/skills/issues?q=is%3Aissue+label%3Aenhancement) first. If your request is already listed, leave a comment so we can re-prioritise. Otherwise [file a new issue](https://github.com/flutter-tizen/skills/issues/new) describing:

- The Tizen-specific workflow the agent should automate.
- An example user prompt and the expected outcome.
- Doc URLs the generator should crawl (Tizen Native docs, flutter-tizen wiki, plugin READMEs).

## Editing a skill locally

Skills are generated from `resources/flutter_tizen_skills.yaml` plus the doc URLs declared per entry. The general flow is:

1. Edit the entry in `resources/flutter_tizen_skills.yaml`.
2. Regenerate the SKILL.md:
   ```bash
   dart run tool/generator/bin/skills.dart generate-skill \
     resources/flutter_tizen_skills.yaml \
     --directory skills
   ```
3. Hand-review the output — Tizen-specific CLI flags, plugin names, and privilege URLs are easy for the generator to hallucinate.
4. Lint:
   ```bash
   dart run tool/dart_skills_lint/bin/cli.dart -d skills
   ```
5. Update the README table:
   ```bash
   dart run tool/generator/bin/skills.dart update-readme \
     resources/flutter_tizen_skills.yaml \
     --directory skills \
     --readme README.md
   ```

## Issue triage

Maintainers triage incoming issues following the same conventions as upstream `flutter/skills`: untriaged issues get either closed with explanation or labelled `triaged` plus a priority (`P0`–`P3`). `P0` / `P1` issues are placed in a milestone.

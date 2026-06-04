# Skills CLI

The Skills CLI simplifies the process of creating "Agent Skills" from external documentation. It allows you to crawl documentation websites to discover relevant pages and then uses Generative AI (Gemini) to convert those pages into structured `SKILL.md` files that agents can use.

## Context

*   [Agent Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

## Prerequisite

Live generation, update, and validation require the `GEMINI_API_KEY` environment variable to be set. Dry runs fetch source content but do not call Gemini.

## Commands

> [!NOTE]
> Commands should be run from the repository root as: `dart run tool/generator/bin/skills.dart <command>`.
> The default configuration file path is `resources/flutter_tizen_skills.yaml`.

### `generate-skill`

Generates `SKILL.md` files from a YAML configuration file. Use the `--skill` option to generate a specific skill.

**Usage:**
```bash
dart run tool/generator/bin/skills.dart generate-skill [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_tizen_skills.yaml`.

**Options:**
*   `--skill`: Filter to generate only the specified skill by name.
*   `--directory` (`-d`): The directory to output the generated skill folder. Defaults to `skills/`.
*   `--dry-run`: Performs a dry run, showing what would be generated and token count without writing files.

**Example:**
Generate all skills defined in `resources/flutter_tizen_skills.yaml` to the `skills/` directory:

```bash
dart run tool/generator/bin/skills.dart generate-skill
```

Generate only the `flutter-tizen-setup` skill:

```bash
dart run tool/generator/bin/skills.dart generate-skill --skill flutter-tizen-setup
```

### `update-skill`

Updates an existing skill by combining its current content with fetched resources and new instructions.

**Usage:**
```bash
dart run tool/generator/bin/skills.dart update-skill [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_tizen_skills.yaml`.

**Options:**
*   `--skill`: Filter to update only the specified skill by name.
*   `--directory` (`-d`): The directory to search for skills. Defaults to `skills/`.
*   `--thinking-budget`: The token budget for the model to "think" before generating content. Defaults to 4096.

**Example:**
Update all skills defined in `resources/flutter_tizen_skills.yaml`:

```bash
dart run tool/generator/bin/skills.dart update-skill
```

Update only the `flutter-tizen-setup` skill:

```bash
dart run tool/generator/bin/skills.dart update-skill --skill flutter-tizen-setup
```

### `validate-skill`

Validates skills by re-generating and comparing with existing skills. This is useful for testing prompts or verifying consistency.

**Usage:**
```bash
dart run tool/generator/bin/skills.dart validate-skill [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_tizen_skills.yaml`.

**Options:**
*   `--skill`: Validate only the specified skill by name.
*   `--directory` (`-d`): The directory containing the generated skills to validate. Defaults to `skills/`.
*   `--thinking-budget`: The token budget for the model to "think" before generating content. Defaults to 4096.
*   `--dry-run`: Fetches source content and reports sizes without calling Gemini or writing validation output.

**Example:**
Validate skills in the default `skills/` directory:

```bash
dart run tool/generator/bin/skills.dart validate-skill
```

Dry-run validation for one skill:

```bash
dart run tool/generator/bin/skills.dart validate-skill --dry-run --skill flutter-tizen-setup
```

### `update-readme`

Updates the `README.md` file with a table of available skills.

**Usage:**
```bash
dart run tool/generator/bin/skills.dart update-readme [options] [config_file]
```

**Arguments:**
*   `[config_file]`: Path to the YAML configuration file. Defaults to `resources/flutter_tizen_skills.yaml`.

**Options:**
*   `--directory` (`-d`): The directory containing the generated skills. Defaults to `skills/`.
*   `--readme`: Path to the README.md file to update.

**Example:**
Update the root README.md:

```bash
dart run tool/generator/bin/skills.dart update-readme --directory skills --readme README.md
```

## Configuration

The default configuration file is located at `resources/flutter_tizen_skills.yaml`. It contains a list of skill definitions:

```yaml
- name: flutter-tizen-setup
  description: "..."
  resources:
    - https://github.com/flutter-tizen/flutter-tizen
```

## Development

To run analysis, formatting, and tests, navigate to this directory (`tool/generator`) and run:

```bash
dart analyze
dart format .
dart test
```

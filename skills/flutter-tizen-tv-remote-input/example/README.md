# Example: TV-remote-driven button + grid

Minimal screen that is fully operable from the D-pad, OK, Back, and color keys.

## Files

- `remote_button.dart` — single focusable button wired via `FocusableActionDetector`, `Shortcuts`, and `Actions`. Includes a focus highlight and color-key shortcut.
- `home_grid.dart` — 4×3 grid wrapped in `FocusTraversalGroup(OrderedTraversalPolicy)` with autofocus on the first tile.
- `raw_scan_code_fallback.dart` — workaround for the issue #319 case where a Tizen TV emits a raw `physicalKey` (F1–F12) instead of a `LogicalKeyboardKey` symbol.

## Scenario

User has a Tizen TV app where focus traversal "works" but OK does nothing, Back exits the app, and color keys are silent. The three files together fix focus + activation + system back + power-user shortcut + the known scan-code gap.

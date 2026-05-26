# Example: TV-ize an existing Flutter screen

Drop-in app shell that applies overscan inset, lifts the text scale, and exposes an unmistakable focus highlight.

## Files

- `tv_shell.dart` — `MaterialApp.builder` wrapper applying `SafeArea`, fixed 5% inset, and `MediaQuery(textScaler:)`.
- `focusable_tile.dart` — reusable TV tile with 4 px focus ring + 1.04× scale + `Semantics` label for the screen reader.
- `accessible_dialog.dart` — non-dismissing dialog pattern with extended timeout suitable for 3 m viewing.

## Scenario

User has a mobile-first Flutter app that "renders fine on TV" but is unreadable at 3 m and impossible to focus visually. Applying the three files top-down brings the app to a TV-friendly baseline.

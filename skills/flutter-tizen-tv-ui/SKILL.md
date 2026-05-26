---
name: flutter-tizen-tv-ui
description: Build a Tizen TV-friendly UI — overscan / safe area, large default font scale, visible focus highlight, high-contrast accessibility, and screen-reader (TalkBack-equivalent) labelling. Use when a layout is cut off on TV, when text is unreadable at 3 m, when focus is invisible, or when an a11y audit is required.
metadata:
  target: flutter-tizen
  category: tv-ui
---
# Building a Tizen TV UI

## Contents
- [Why TV UI is different](#why-tv-ui-is-different)
- [Safe area / overscan](#safe-area--overscan)
- [Font scale and readable typography](#font-scale-and-readable-typography)
- [Focus highlight](#focus-highlight)
- [Accessibility](#accessibility)
- [Workflow: TV-ize an Existing Screen](#workflow-tv-ize-an-existing-screen)
- [Pitfalls](#pitfalls)

## Why TV UI is different

A Samsung TV is consumed from ~3 m away with a remote, not a touch screen. Three constraints drive every TV layout decision:

- **Overscan**: legacy panels crop the edges. Even modern Tizen TVs reserve a margin for system UI.
- **Reading distance**: 14 sp on a phone is illegible on a 55" TV. Default body type lives around 24–32 sp.
- **No pointer**: every actionable element must be reachable by D-pad and have a high-contrast focused state.

## Safe area / overscan

Wrap the entire app shell — not individual screens — in a single `SafeArea` plus a fixed inset:

```dart
return MaterialApp(
  builder: (context, child) {
    return SafeArea(
      child: Padding(
        // 5% inset is the de-facto Tizen TV overscan margin.
        padding: const EdgeInsets.symmetric(
          horizontal: 48,
          vertical: 27,
        ),
        child: child!,
      ),
    );
  },
  home: const HomeScreen(),
);
```

Confirm on the real TV before shipping. `MediaQuery.of(context).viewPadding` is often `EdgeInsets.zero` on Tizen even on a TV that visibly overscans, so a fixed inset is more reliable than a viewPadding-driven one.

## Font scale and readable typography

Lift the global text scale instead of bumping individual `TextStyle`s:

```dart
return MaterialApp(
  builder: (context, child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      // 1.6x is a good starting point for 1080p TV; verify visually.
      data: media.copyWith(textScaler: const TextScaler.linear(1.6)),
      child: child!,
    );
  },
  theme: ThemeData(
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 18),
      titleLarge: TextStyle(fontSize: 28),
    ),
  ),
  home: const HomeScreen(),
);
```

Avoid `MediaQuery.textScalerOf(context)` user override on TV — Tizen does not expose a system font-scale slider; the value is always 1.0.

## Focus highlight

A focused widget must be unmistakable from across the room. Three layered defaults:

1. A 4 px outline ring, 2. a brightness lift on the foreground, 3. a subtle scale (1.04×) on motion-tolerant elements.

```dart
class TvFocusable extends StatefulWidget {
  const TvFocusable({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_focused ? 1.04 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused ? Colors.white : Colors.transparent,
            width: 4,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
```

Never rely on hover colour alone — TV remotes do not generate hover events.

## Accessibility

- **Semantics for every focusable**: wrap with `Semantics(label: ..., button: true)` so Tizen's screen reader announces the element. Implicit semantics from `Text`/`Icon` are not enough for custom focusables built on `GestureDetector`.
- **Contrast**: target WCAG AA on a 6500 K calibrated TV (`light-on-dark` is preferred; reserve `dark-on-light` for menus). Tools: `flutter analyze --suggestions` reports low-contrast hints when paired with a custom rule.
- **Keep tap targets ≥ 48 logical px** even on TV — the remote's focus dwell still needs a margin around each element.
- **Avoid time-out only dialogs** — TV users may need 10× longer than mobile to respond.
- **Captions and TTS**: third-party caption packages (`flutter_tts`) work on Tizen with the appropriate privileges (`http://tizen.org/privilege/tts`). Declare them via [flutter-tizen-use-plugins](../flutter-tizen-use-plugins/SKILL.md).

## Workflow: TV-ize an Existing Screen

Copy this checklist when adapting a screen from mobile to TV:

### Task Progress
- [ ] **Step 1: Wrap the app in safe-area + overscan inset** (5% horizontal, 5% vertical) at the `MaterialApp.builder` level.
- [ ] **Step 2: Lift the global text scale** with `MediaQuery(textScaler: TextScaler.linear(1.6))`.
- [ ] **Step 3: Convert every actionable widget** to `FocusableActionDetector` (or `Focus` + `Shortcuts` + `Actions`); see [flutter-tizen-tv-remote-input](../flutter-tizen-tv-remote-input/SKILL.md).
- [ ] **Step 4: Add a 4 px outline focus highlight** plus a 1.04× scale on focused state.
- [ ] **Step 5: Add `Semantics(label:, button:)`** to every custom focusable.
- [ ] **Step 6: Audit colour contrast** at WCAG AA on a 6500 K calibrated TV.
- [ ] **Step 7: Verify on a real TV**, not the desktop emulator — text rendering, overscan margins, and remote behavior all differ.
- [ ] **Step 8: Re-run [flutter-tizen-integration-test-device](../flutter-tizen-integration-test-device/SKILL.md)** with D-pad driven flows to catch regressions.

## Pitfalls

| Symptom | Likely cause | Action |
|---|---|---|
| Right edge of screen cut off | Overscan margin missing | Wrap app shell in `SafeArea` + 5% horizontal `Padding` |
| Text readable on desktop, illegible on TV | Default text scale 1.0 | Apply `TextScaler.linear(1.6)` at `MaterialApp.builder` |
| Focus state invisible from 3 m | Default Material focus colour | Replace with 4 px white outline + 1.04× scale |
| Screen reader silent on custom card | No explicit `Semantics` | Wrap with `Semantics(label:, button: true)` |
| Layout reflows when font scale changes | Fixed-height widgets | Use intrinsic sizes or `Flexible`; let TV scale grow vertically |
| Toast disappears before remote reaches it | Default snackbar duration | Bump to ≥ 6 s on TV; consider non-dismissing banner |

---
name: flutter-tizen-tv-remote-input
description: Make a Flutter-Tizen UI navigable with the Samsung TV remote — wire up D-pad focus traversal, OK/Back handling, color keys, and media keys using Flutter's `Focus`/`FocusNode`/`Shortcuts`/`Actions`. Use when targeting Samsung TV 2021+, when focus jumps incorrectly, or when remote keys do nothing in a Flutter view.
metadata:
  target: flutter-tizen
  category: tv-ui
---
# Wiring the Samsung TV remote into a Flutter-Tizen app

## Why this is different from mobile

A Tizen TV has no touch surface; every interaction is a key event. Flutter's gesture-based widgets (`InkWell`, `GestureDetector` with only `onTap`) do not react to the OK button unless you explicitly route key events into them via `Focus` and `Shortcuts`/`Actions`.

Three Flutter primitives carry the load:

- `Focus` / `FocusNode` — declare a widget as a focus stop and listen for key events.
- `FocusTraversalGroup` + `FocusTraversalPolicy` — control how D-pad arrows move focus.
- `Shortcuts` + `Actions` — map a `LogicalKeySet` (or platform key code) to a callable `Intent`.

Treat the OK button as `LogicalKeyboardKey.select` (alias for `enter`); treat Back as `LogicalKeyboardKey.goBack` (alias for `escape` on Tizen).

## Tizen TV remote key codes

Flutter receives Tizen remote keys as `LogicalKeyboardKey` values. Map of the keys you typically wire:

| Remote button | `LogicalKeyboardKey` | Notes |
|---|---|---|
| Up / Down / Left / Right | `arrowUp`, `arrowDown`, `arrowLeft`, `arrowRight` | Drives `FocusTraversalPolicy` automatically — usually no manual wiring needed |
| OK / Enter | `select` (or `enter`) | Use `ActivateIntent` to invoke the focused widget's primary action |
| Back / Return | `goBack` (or `escape`) | Pair with `Navigator.maybePop` |
| Channel Up / Down | `channelUp`, `channelDown` | Only on TV remotes with channel keys |
| Volume Up / Down / Mute | `audioVolumeUp`, `audioVolumeDown`, `audioVolumeMute` | The TV usually swallows these — do **not** override system volume |
| Media Play / Pause / Stop / FF / Rew | `mediaPlay`, `mediaPause`, `mediaStop`, `mediaTrackNext`, `mediaTrackPrevious`, `mediaFastForward`, `mediaRewind` | Wire only on media surfaces |
| Color keys (Red / Green / Yellow / Blue) | `colorF0Red`, `colorF1Green`, `colorF2Yellow`, `colorF3Blue` | Optional, used for power-user shortcuts |
| Number 0–9 | `digit0` … `digit9` | Useful for jump-to-row in long lists |

**Known mapping gap (flutter-tizen issue #319).** On several Samsung TV models the embedder forwards remote keys with arbitrary scan codes (F1–F12, Left Shift, even media keys reported as "Brightness Auto") instead of the matching `LogicalKeyboardKey`. If a key prints to `flutter logs` as `KeyEvent { logical: Key { keyId: 0x... } }` with no symbolic mapping:

1. Capture the `KeyEvent.physicalKey` value on a `KeyDownEvent` for that button and pin the dispatch to the physical key:
   ```dart
   if (event is KeyDownEvent &&
       event.physicalKey == PhysicalKeyboardKey.f1) {
     return KeyEventResult.handled;
   }
   ```
2. Centralise the raw-scan-code overrides in one `Shortcuts` widget high in the tree so per-screen code remains symbolic.
3. File a follow-up on the device model — flutter-tizen has been closing these one-by-one (see issue #319 history). Avoid hard-coding the override permanently if a fixed embedder version may ship.

Always verify the installed `flutter-tizen` Flutter version is current before working around a missing key — older builds were missing several TV codes that current main has.

## Architecture: Focus, Shortcuts, Actions

```
FocusScope (per screen)
 └── FocusTraversalGroup(policy: ReadingOrderTraversalPolicy())
      ├── Focus / FocusableActionDetector (each interactive widget)
      └── Shortcuts(...) → Actions(...) for global keys (Back, color keys, media)
```

Two important rules:

1. **One `FocusScope` per logical screen.** Pushing a route auto-creates one; modal dialogs need their own via `FocusScope.of(context).autofocus(...)`.
2. **Always autofocus on entry.** TV users have no way to "click into" a screen — if no widget has focus, the remote does nothing. Use `autofocus: true` on the most prominent interactive widget.

## Building a focusable widget

Prefer `FocusableActionDetector` over hand-wired `Focus + RawKeyboardListener`; it gives you focus, hover, mouse, and key handling in one widget and integrates with the `Actions` map.

```dart
class RemoteButton extends StatelessWidget {
  const RemoteButton({super.key, required this.label, required this.onPressed, this.autofocus = false});

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: autofocus,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed()),
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: focused ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(8),
              boxShadow: focused
                  ? [const BoxShadow(blurRadius: 12, color: Colors.white)]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: focused ? Colors.black : Colors.white,
                fontSize: 20,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

Notes:

- The focus halo is rendered by your widget, not by Flutter. TV designs need a much stronger highlight than mobile (large outline, glow, scale-up) so users can see it from across a room.
- Map both `LogicalKeyboardKey.select` and `enter` — some Tizen firmware versions ship `select`, others `enter`, depending on the model.

## Custom focus traversal

The default `ReadingOrderTraversalPolicy` ("left-to-right, top-to-bottom") covers most grids. For non-rectangular layouts (carousels, content rails, settings sidebars), use:

- `OrderedTraversalPolicy` with `FocusTraversalOrder(order: NumericFocusOrder(...))` for deterministic order.
- `DirectionalFocusTraversalPolicyMixin` if you need to override left/right/up/down individually.

Snap-back patterns (focus must stop at the last item in a row, not wrap) are implemented by overriding `inDirection` and returning `false` when the move would leave the rail.

## Workflow: Make a Screen Remote-Navigable

### Task Progress
- [ ] **Step 1: Identify interactive widgets.** List every place the user must "click" — buttons, list tiles, cards.
- [ ] **Step 2: Replace `InkWell`/`GestureDetector(onTap:)` with `FocusableActionDetector`** wired to `ActivateIntent`.
- [ ] **Step 3: Pick one widget to autofocus** on screen entry. Set `autofocus: true`.
- [ ] **Step 4: Add a `FocusTraversalGroup`** around the screen body; pick a policy that matches the visual layout.
- [ ] **Step 5: Wire Back.** Top-level `Shortcuts` mapping `LogicalKeyboardKey.goBack` (and `escape`) to a custom `BackIntent`; in `Actions`, call `Navigator.maybePop(context)`.
- [ ] **Step 6: Wire media keys**, but only on screens that own playback. Never swallow `audioVolume*`.
- [ ] **Step 7: Verify focus visibility.** The focused widget must be unambiguous from 3 m away.
- [ ] **Step 8: Drive the TV emulator** end-to-end with the remote panel: every reachable screen has a focused widget on entry; every reachable widget can be focused; OK invokes; Back pops.

## Verifying on a TV / emulator

The Tizen TV emulator has a virtual remote panel — open it via the emulator's `extended controls` icon. From the host shell, you can also synthesize keys with Tizen's `input_keyevent` tool (X11-style key names — *not* Android's `KEY_*` codes):

```sh
# Move focus right, then activate
sdb -s <emulator-id> shell input_keyevent Right
sdb -s <emulator-id> shell input_keyevent Return

# Back
sdb -s <emulator-id> shell input_keyevent XF86Back

# Other useful names
#   Left | Right | Up | Down | Return | XF86Back | XF86HomePage |
#   XF86Red | XF86Green | XF86Yellow | XF86Blue |
#   XF86AudioPlay | XF86AudioPause | XF86AudioStop
```

`input_keyevent <name>` synthesizes a down+up pair. Add `down` or `up` as a second arg to send only one half.

For sanity-checking from inside Flutter, drop a temporary listener:

```dart
Focus(
  onKey: (node, event) {
    debugPrint('key: ${event.logicalKey.debugName} (${event.runtimeType})');
    return KeyEventResult.ignored;
  },
  child: ...,
)
```

Watch for the matching `LogicalKeyboardKey.*` value in `flutter-tizen logs` / `sdb dlog ConsoleMessage:V *:S`. If you see `LogicalKeyboardKey#xxxxx(keyId: 0x...)` instead of a named key, the engine is missing a mapping for that physical key — file upstream and use `physicalKey` to bridge in the meantime.

## Pitfalls

- **Mouse-only widgets.** Material's `IconButton` is focusable; `InkResponse` with only `onTap` is not interactive via keyboard until wrapped in `FocusableActionDetector`. Audit by tabbing through with a USB keyboard before testing on the TV — keyboard `Tab` behaves like the D-pad for traversal.
- **`autofocus: true` on multiple widgets.** Only the first to mount actually wins; the rest silently no-op, which looks like a bug. Pick exactly one per screen.
- **Swallowing system keys.** Returning `KeyEventResult.handled` for `audioVolume*` or `power` keys prevents the TV from running its own handler and gets your app flagged in store review.
- **Focus lost on `setState`.** Recreating a `FocusableActionDetector` without a stable `Key` resets focus to nowhere. Use a `FocusNode` field or a `ValueKey` on rebuilds.
- **Dialogs steal focus oddly.** `showDialog` creates its own scope but does not autofocus inside it. Pass `useRootNavigator: false` and add `autofocus: true` to the first dialog button.


---
name: flutter-tizen-app-lifecycle
description: Map Tizen's native app lifecycle callbacks (`app_create`, `app_pause`, `app_resume`, `app_terminate`, low-memory, low-battery, language/locale changes) onto Flutter's `AppLifecycleState` and `WidgetsBindingObserver` hooks. Use when state needs to be persisted across pause/resume, when memory pressure must be released, or when behavior on launch differs from foreground-resume.
metadata:
  target: flutter-tizen
  category: lifecycle
---
# Handling app lifecycle on Tizen

## Contents
- [Lifecycle mapping](#lifecycle-mapping)
- [Listening from Dart](#listening-from-dart)
- [What to do in each state](#what-to-do-in-each-state)
- [System events: low-memory, low-battery, locale](#system-events-low-memory-low-battery-locale)
- [Workflow: Wire Lifecycle Handlers](#workflow-wire-lifecycle-handlers)
- [Verifying on emulator / device](#verifying-on-emulator--device)
- [Pitfalls](#pitfalls)

## Lifecycle mapping

The Tizen embedder converts each Tizen native callback into a `AppLifecycleState` change on the Dart side. The mapping is:

| Tizen Native callback | Flutter `AppLifecycleState` | When it fires |
|---|---|---|
| `app_create_cb` | _no event_ — `runApp` is the first Dart instruction | Process boot, before the first frame |
| `app_control_cb` | _no `AppLifecycleState`_, but `AppControl.onAppControl` fires | App started/resumed by an intent (use `tizen_app_control`) |
| `app_resume_cb` | `AppLifecycleState.resumed` | App returned to foreground / first foreground after launch |
| `app_pause_cb` | `AppLifecycleState.inactive` then `paused` | App went to background (Home key, app switcher, OS dialog) |
| `app_terminate_cb` | `AppLifecycleState.detached` | OS is about to kill the process |
| `app_low_memory_cb` | `WidgetsBindingObserver.didHaveMemoryPressure` | Low-memory warning |
| `app_low_battery_cb` | (no direct Flutter hook; surface via a platform channel) | Battery threshold crossed |
| `app_lang_changed_cb` | `WidgetsBindingObserver.didChangeLocales` | System language changed |
| `app_region_format_changed_cb` | `WidgetsBindingObserver.didChangeLocales` | Region / format changed |
| `app_orientation_changed_cb` | `WidgetsBindingObserver.didChangeMetrics` | Orientation flip (TV doesn't rotate; common/mobile only) |

Notes:

- `resumed` fires once on first foreground, so don't gate "first run" logic on it — that belongs in `main()`/`runApp`.
- Between `inactive` and `paused` no UI is visible, but Dart code keeps running for a brief grace window. Use this for save-state work, not user-visible work.

## Listening from Dart

Implement `WidgetsBindingObserver` at the level that owns app-wide state:

```dart
import 'package:flutter/widgets.dart';

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onResume();
        break;
      case AppLifecycleState.inactive:
        _onInactive();
        break;
      case AppLifecycleState.paused:
        _onPause();
        break;
      case AppLifecycleState.detached:
        _onTerminate();
        break;
      case AppLifecycleState.hidden:
        // Tizen does not fire `hidden` distinctly; treat like inactive.
        break;
    }
  }

  @override
  void didHaveMemoryPressure() {
    _releaseCaches();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    _reloadStrings(locales);
  }
  ...
}
```

For more than one observer (e.g. modules that each care about pause), register them independently — `addObserver` accepts many. Just remember to `removeObserver` in `dispose`.

## What to do in each state

| State | Do | Do NOT |
|---|---|---|
| `resumed` | Re-acquire camera/mic, restart polling, refresh tokens, reconnect sockets, replay any deferred App Control intent | Block the UI thread, run long migrations |
| `inactive` | Pause animations / video, stop high-frequency timers | Persist state — race risk vs. `paused` |
| `paused` | Persist user state (`SharedPreferences`, draft text, scroll positions); release big GPU resources | Open new files / DB transactions you can't finish quickly |
| `detached` | Best-effort flush; assume only a few hundred ms | Anything network-bound — process is about to die |

For TV: `paused` fires when the user pressed Home, the Smart Hub overlay is visible, or another app launched. Saving session state here is the norm.

## System events: low-memory, low-battery, locale

- **Low memory.** `didHaveMemoryPressure` is your one warning. Drop image caches (`imageCache.clear()`), unload off-screen videos, evict heavy controllers. Tizen will kill the app aggressively after sustained pressure.
- **Low battery.** No direct Flutter hook. Surface via a small platform channel that listens to `device_battery_set_warning_cb` in native code, and forward as a Dart event. On TV, irrelevant — TVs are always wall-powered.
- **Locale change.** `didChangeLocales` fires. `MaterialApp` with `localizationsDelegates` re-resolves automatically; manual code must reload strings.

## Workflow: Wire Lifecycle Handlers

### Task Progress
- [ ] **Step 1: Inventory side effects.** List every Stream subscription, Timer, camera handle, socket, audio session that the app owns.
- [ ] **Step 2: Decide owner.** Pick a single `State` (often the root `App`) to host `WidgetsBindingObserver`.
- [ ] **Step 3: Implement `didChangeAppLifecycleState`.** Cover `resumed`, `inactive`, `paused`, `detached`.
- [ ] **Step 4: Persist state in `paused`** using fast-path storage (SharedPreferences / a single SQLite txn). Avoid network writes.
- [ ] **Step 5: Add `didHaveMemoryPressure`** — at minimum, clear `imageCache`.
- [ ] **Step 6: Add `didChangeLocales`** if the app supports multiple languages, or skip otherwise.
- [ ] **Step 7: If using App Control intents**, subscribe to `AppControl.onAppControl` and re-apply intent on `resumed`.
- [ ] **Step 8: Validate by toggling foreground/background on the emulator** while watching `dlog` (see below).

## Verifying on emulator / device

Manually drive lifecycle transitions:

```sh
# Send the Home key (X11-style name; Tizen's tool is input_keyevent, not Android's `input keyevent`)
sdb -s <id> shell input_keyevent XF86HomePage

# Return to (or start) your app via the launcher
sdb -s <id> shell app_launcher -s <appid>

# Terminate the app to trigger detached (use -k to hard-kill)
sdb -s <id> shell app_launcher -t <appid>

# Inspect installed apps + their appids
sdb -s <id> shell app_launcher -l
```

Log your transitions:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  debugPrint('lifecycle => $state');
  super.didChangeAppLifecycleState(state);
}
```

Then:

```sh
sdb -s <id> dlog ConsoleMessage:V *:S | grep lifecycle
```

Expected sequence when pressing Home and returning:

```
lifecycle => AppLifecycleState.inactive
lifecycle => AppLifecycleState.paused
lifecycle => AppLifecycleState.resumed
```

If you only see `paused` and never `resumed`, the OS killed the process — re-launching counted as a *new* `main()`. Restore state via your `paused`-time save path on the next start.

## Pitfalls

- **Treating `inactive` as "user-visible".** It's the brief window between focus loss and full background; never paint UI changes that assume the user is still watching.
- **Heavy work in `paused`.** OS may finish you in 1–2 frames; long IO loses data.
- **Forgetting `removeObserver`.** Leaks observer references across hot restart and old observers re-fire after their state is gone. Always pair `add` with `remove`.
- **Listening multiple times.** Adding the same observer twice receives every callback twice. Use a single field, not a `List` of observers added per build.
- **Assuming `detached` is reliable.** It often runs, but never bet on it for critical persistence. Use `paused` as your durability boundary.
- **App Control on cold launch.** The intent that launched the app is delivered to `AppControl.onAppControl` *before* the first `resumed`. If you subscribe only after `resumed`, you miss it. Subscribe in `initState` and buffer.

## Example

Runnable companion sources live in [`example/README.md`](example/README.md) — open `example/README.md` for the scenario list.

# Example: Persist + restore on pause / resume

Mixin a `WidgetsBindingObserver` to save scroll position on `paused` and restore it on `resumed`, with a fallback for `didHaveMemoryPressure`.

## Files

- `lifecycle_observer.dart` — full `StatefulWidget` template covering pause / resume / memory-pressure / locale.
- `persisted_scroll_demo.dart` — concrete app using the observer to remember a `ListView` offset across pause/resume.

## Scenario

User leaves the app to answer a notification; on resume the list scrolls back to where they were. Same wiring releases image cache when the TV reports memory pressure.

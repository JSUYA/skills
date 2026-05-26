# Example: UI ↔ background service round-trip

Sensor-polling service app plus a UI app that asks for the latest reading on demand.

## Files

- `service/main.dart` — service-side Dart entry; opens a `LocalPort('worker_in')` and replies with sensor data when asked.
- `service/tizen-manifest.snippet.xml` — `<service-application>` block + `<privileges>` for `messageport` + `appmanager.launch`.
- `ui/start_stop.dart` — UI-side start (`sendLaunchRequest`) and stop (`sendTerminateRequest`) of the service.
- `ui/poll_sensor.dart` — UI sends `{cmd: 'poll'}` and listens for the reply via its own `LocalPort('ui_inbox')`.

## Scenario

User wants a sensor reading delivered even when the UI is backgrounded. The service stays alive across UI pause; the UI re-attaches on resume and pulls the most recent reading.

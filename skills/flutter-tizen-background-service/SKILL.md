---
name: flutter-tizen-background-service
description: Build a separate Tizen `<service-application>` TPK that runs alongside the Flutter UI app, keep its Dart entry alive after `main()` returns, and wire UI↔service IPC via `messageport_tizen`. Use when the work needs a second app process registered as a Tizen service (not just a plugin), when a service app exits immediately after `main()` returns, when work must continue after the UI is paused (sync, telemetry, sensor polling), or when a long-running task must survive UI process termination. For privileges around `messageport_tizen` inside a single UI process, use `flutter-tizen-use-plugins` instead.
metadata:
  target: flutter-tizen
  category: lifecycle
---
# Tizen Background Service + Messageport

## Contents
- [Two-process model](#two-process-model)
- [Scaffold the service app](#scaffold-the-service-app)
- [Start and stop the service from the UI](#start-and-stop-the-service-from-the-ui)
- [Communicate via messageport](#communicate-via-messageport)
- [Lifecycle and resource budget](#lifecycle-and-resource-budget)
- [Workflow: Add a Background Worker](#workflow-add-a-background-worker)
- [Pitfalls](#pitfalls)

## Two-process model

Tizen draws a hard line between a **UI app** and a **service app**:

- UI app: window, user interaction, foregrounded lifecycle. Process dies on `paused` if memory is tight.
- Service app: headless, registered separately in `tizen-manifest.xml`, owns its own privileges, survives UI pause / terminate.

Flutter is supported in both. The service-side runtime is the same Flutter engine without a visible window — `runApp(...)` is replaced by a long-lived Dart entry point that calls Tizen Native APIs directly.

Pick this skill instead of `flutter-tizen-app-lifecycle` when the work must outlive the UI process; the lifecycle skill only covers UI pause/resume, not "keep running after the user goes home".

## Scaffold the service app

Either embed a second app inside the existing project or create a sibling package:

```sh
# Sibling package approach
flutter-tizen create --template=app --tizen-language=cpp my_app_service
```

In `tizen-manifest.xml` of the service, declare it as a service:

```xml
<service-application appid="org.example.myapp.service"
                     exec="myapp_service"
                     type="capp"
                     multiple="false"
                     on-boot="false"
                     auto-restart="false">
  <label>MyApp Service</label>
</service-application>

<privileges>
  <privilege>http://tizen.org/privilege/appmanager.launch</privilege>
  <privilege>http://tizen.org/privilege/datasharing</privilege>
</privileges>
```

Key flags:

- `on-boot="true"` — start at device boot (TV only; phones and IoT may reject).
- `auto-restart="true"` — relaunch if the service crashes; use sparingly.
- `multiple="false"` — singleton; second start request is a no-op.

## Start and stop the service from the UI

```dart
import 'package:tizen_app_control/tizen_app_control.dart';

Future<void> startWorker() async {
  await AppControl(
    operation: 'http://tizen.org/appcontrol/operation/default',
    appId: 'org.example.myapp.service',
  ).sendLaunchRequest();
}

Future<void> stopWorker() async {
  await AppControl(
    appId: 'org.example.myapp.service',
  ).sendTerminateRequest();
}
```

Tizen treats service launches as App Control requests; pair this with [flutter-tizen-app-control](../flutter-tizen-app-control/SKILL.md). Pass startup parameters via `extraData`. The `sendTerminateRequest` path requires `http://tizen.org/privilege/appmanager.kill` (or `.kill.bgapp`) and assumes the caller owns the service or is signed under the same author.

## Communicate via messageport

`messageport_tizen` is the supported in-process-pair IPC. One side registers a port; the other side sends bytes (or a `Map`).

```dart
// In the service app
import 'package:messageport_tizen/messageport_tizen.dart';

LocalPort? _port;

Future<void> bootService() async {
  _port = await LocalPort.create('worker_in');
  _port!.register((dynamic message, [RemotePort? replyTo]) async {
    final cmd = (message as Map)['cmd'] as String?;
    if (cmd == 'poll' && replyTo != null) {
      final value = await readSensor();
      await replyTo.send({'value': value});
    }
  });
}
```

```dart
// In the UI app
final RemotePort remote = await RemotePort.connect(
  'org.example.myapp.service',
  'worker_in',
);
// Listen for service replies via our own LocalPort
final LocalPort inbox = await LocalPort.create('ui_inbox');
inbox.register((dynamic message, [RemotePort? sender]) {
  setState(() => latest = (message as Map)['value']);
});
await remote.sendWithLocalPort({'cmd': 'poll'}, inbox);
```

Local port name and remote app ID together form the addressing tuple — both sides must agree. Use distinct ports for distinct topics (one port per concern) instead of multiplexing.

`messageport_tizen` does not expose an `onMessage` stream; the registered callback is the only delivery channel. Pass a `LocalPort` via `sendWithLocalPort` when the sender wants replies back.

## Lifecycle and resource budget

Tizen's process scheduler is stricter than Android's:

- **Memory**: a service app holding > ~80 MB on TV is the first to be killed under pressure. Drop image caches and large buffers on `didHaveMemoryPressure`.
- **CPU**: long compute work blocks the Flutter engine isolate. Spawn a Dart `Isolate` or schedule the work via `compute(...)`.
- **Wake locks**: `tizen_power_options` exposes the power policy — request only when strictly needed (sensor polling, media playback). Holding a wake lock idle is a fast path to App Store rejection.
- **Restart loop guard**: if `auto-restart="true"`, the service can hot-loop on a startup crash and drain battery; gate with a backoff persisted to disk.

## Workflow: Add a Background Worker

Copy this checklist when introducing a service app to a project:

### Task Progress
- [ ] **Step 1: Decide whether a service app is required.** If the work fits within one UI pause/resume cycle, [flutter-tizen-app-lifecycle](../flutter-tizen-app-lifecycle/SKILL.md) is enough.
- [ ] **Step 2: Scaffold the service** via `flutter-tizen create --template=app --tizen-language=cpp <name>` (or a second `<service-application>` in the existing manifest).
- [ ] **Step 3: Declare `<service-application>` and privileges** in the service's `tizen-manifest.xml`.
- [ ] **Step 4: Wire start / stop** from the UI via `tizen_app_control` (see [flutter-tizen-app-control](../flutter-tizen-app-control/SKILL.md)).
- [ ] **Step 5: Open a `messageport_tizen` channel** with a clear port name per topic.
- [ ] **Step 6: Build and install both packages** — UI and service are separate TPKs.
- [ ] **Step 7: Verify the service survives UI pause** by sending the UI to the background (press Home on the physical device / remote) and confirming `sdb dlog` for the service keeps emitting.
- [ ] **Step 8: Audit resource budget** with `sdb shell top -p <pid>` while the service runs.
- [ ] **Step 9: Add an integration test** that drives the UI → service → UI round trip; see [flutter-tizen-integration-test-device](../flutter-tizen-integration-test-device/SKILL.md).

## Pitfalls

| Symptom | Likely cause | Action |
|---|---|---|
| Service exits immediately after launch | No long-lived Dart entry point (the `main()` returned) | Keep an open `Stream`/`Completer` or schedule a periodic `Timer` |
| `RemotePort.connect` throws `NOT_FOUND` | Service not running or wrong app ID / port name | Confirm `pkgcmd -l \| grep <appId>` and that `LocalPort.create` ran |
| Service is killed under load | Memory budget exceeded | Drop caches on memory pressure; cap in-memory buffers |
| Service does not start at boot | `on-boot="false"` or device profile forbids it | Set `on-boot="true"` on TV; on phones/IoT, prompt the user to start it |
| UI and service get out of sync after upgrade | Independent TPKs with mismatched protocol versions | Embed a version field in every message; reject mismatches at the receiver |
| `auto-restart="true"` drains the battery | Crash loop on startup | Persist crash count + backoff before restarting work |

## Example

Runnable companion sources live in [`example/README.md`](example/README.md) — open `example/README.md` for the scenario list.

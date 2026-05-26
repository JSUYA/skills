---
name: flutter-tizen-app-control
description: Send and receive Tizen App Control intents from a Flutter app — start another app by operation / URI / MIME, receive a launch request, return a reply, and implement deep linking. Use when integrating with the Tizen launcher, settings, or another Tizen app, or when wiring deep-link entry points. The `tizen_app_control` plugin is the API surface; this skill covers the workflow on top of it.
metadata:
  target: flutter-tizen
  category: lifecycle
---
# Using Tizen App Control

## Contents
- [App Control vs. plain plugin usage](#app-control-vs-plain-plugin-usage)
- [Send an App Control](#send-an-app-control)
- [Receive an App Control](#receive-an-app-control)
- [Reply to the caller](#reply-to-the-caller)
- [Deep linking entry points](#deep-linking-entry-points)
- [Workflow: Wire an App-Control Endpoint](#workflow-wire-an-app-control-endpoint)
- [Pitfalls](#pitfalls)

## App Control vs. plain plugin usage

`tizen_app_control` is one of many `*_tizen` plugins, but the workflow is different from generic [flutter-tizen-use-plugins](../flutter-tizen-use-plugins/SKILL.md):

- **App Control** is the cross-app contract — it spans a process boundary, requires privileges, and demands explicit manifest declarations for the receiving side.
- Generic Tizen plugins (`messageport_tizen`, `permission_handler_tizen`) operate inside one process and need no manifest registration.

Use this skill when the integration crosses an app boundary (launch another app, accept a launch from another app, implement a system deep link). Use `flutter-tizen-use-plugins` for everything else.

## Send an App Control

```dart
import 'package:tizen_app_control/tizen_app_control.dart';

Future<void> openSettingsScreen() async {
  await AppControl(
    operation: 'http://tizen.org/appcontrol/operation/setting',
    appId: 'org.tizen.setting',
  ).sendLaunchRequest();
}

Future<void> openUri(String uri) async {
  await AppControl(
    operation: 'http://tizen.org/appcontrol/operation/view',
    uri: uri,
  ).sendLaunchRequest();
}
```

Key flags:

- `operation` — required, in the `http://tizen.org/appcontrol/operation/*` namespace.
- `appId` — pin the target app (system Settings, Email, etc.).
- `uri` / `mime` — let the framework resolve a handler.
- `extraData` — `Map<String, dynamic>` of key/value pairs the receiver reads.

## Receive an App Control

A Flutter app declares the operations it handles in `tizen-manifest.xml`:

```xml
<app-control>
  <operation name="http://tizen.org/appcontrol/operation/view"/>
  <uri name="myapp"/>
  <mime name="application/json"/>
</app-control>
```

In Dart, subscribe before `runApp`:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppControl.onAppControl.listen((AppControl event) {
    final route = event.extraData['route'] as String?;
    if (route != null) {
      navigatorKey.currentState?.pushNamed(route);
    }
  });
  runApp(const MyApp());
}
```

Cold-start vs. warm receive:

- **Cold start (app was not running)**: the launch is delivered as the initial `AppControl` (`AppControl.fromInitialIntent()`). Read it once in `main` before `runApp`.
- **Warm receive (app was already running)**: comes through the `onAppControl` stream. Always subscribe; do not assume only one path.

## Reply to the caller

If the caller invoked the app via `sendLaunchRequestForResult`, the receiver must reply:

```dart
AppControl.onAppControl.listen((event) async {
  await event.reply(
    extraData: {'result': 'ok', 'payload': '...'},
    result: AppControlReplyResult.succeeded,
  );
});
```

`AppControlReplyResult.failed` and `cancelled` are also valid. Forgetting to reply leaves the caller hanging until its own timeout.

## Deep linking entry points

Two patterns coexist on Tizen:

- **Custom scheme** (`myapp://settings/profile`). Declare `<uri name="myapp"/>` in `<app-control>` and parse the `event.uri` in Dart.
- **Web URL** (`https://example.com/...`). Tizen TVs route HTTPS URLs through Smart Hub; require additional Samsung-side allowlisting. Custom schemes are simpler for in-product deep links.

Map the URI to the in-app router (`go_router`, custom `Navigator`) — keep the routing logic in one place so the deep-link handler shares it with regular navigation.

## Workflow: Wire an App-Control Endpoint

Copy this checklist when adding App Control to an app:

### Task Progress
- [ ] **Step 1: Add `tizen_app_control` to `pubspec.yaml`** and run `flutter-tizen pub get`.
- [ ] **Step 2: For the sending side**, identify the target `operation` and either pin the `appId` or rely on URI/MIME resolution.
- [ ] **Step 3: For the receiving side**, declare every supported `<operation>`, `<uri>`, and `<mime>` in `tizen-manifest.xml` under `<app-control>`.
- [ ] **Step 4: Read the cold-start intent** via `AppControl.fromInitialIntent()` in `main` before `runApp`.
- [ ] **Step 5: Subscribe to `AppControl.onAppControl`** for warm receives. Hold the subscription for the lifetime of the app.
- [ ] **Step 6: Reply when invoked-for-result** with `AppControl.reply(...)`; never drop the request silently.
- [ ] **Step 7: Wire the deep-link handler into the router** so the same code path serves user navigation and external launches.
- [ ] **Step 8: Test across cold-start and warm receive** on a real device — emulator launcher behavior differs from a real TV's Smart Hub.

## Pitfalls

| Symptom | Likely cause | Action |
|---|---|---|
| `App control request was not delivered` on send | Target app not installed / wrong `appId` | Verify with `sdb shell pkgcmd -l \| grep <appId>` |
| Cold-start intent missing | Reading `onAppControl` before subscribing | Read `AppControl.fromInitialIntent()` in `main` |
| Receiver never wakes | `<app-control>` missing from `tizen-manifest.xml` | Add the operation / uri / mime and rebuild — manifest is not hot-reloaded |
| Caller hangs forever | Receiver did not `reply()` | Add `event.reply(...)` to every handler |
| Deep link works in foreground only | Subscribing inside a screen widget | Subscribe in `main`, not in a widget's `initState` |
| `extraData` values lose type info | Tizen serialises everything to `String` | Encode complex values as JSON strings; decode on read |

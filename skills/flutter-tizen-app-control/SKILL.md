---
name: flutter-tizen-app-control
description: Send and receive Tizen App Control intents from a Flutter app via the `tizen_app_control` plugin — launch another app by `appId` or `operation` / `uri` / `mime`, accept incoming launch requests, return a reply, and implement deep linking. Use when integrating with the Tizen launcher / Settings / another Tizen app, or when wiring deep-link entry points.
metadata:
  target: flutter-tizen
  category: lifecycle
---
# Using Tizen App Control

## Contents
- [App Control vs. plain plugin usage](#app-control-vs-plain-plugin-usage)
- [Send a launch request](#send-a-launch-request)
- [Receive a launch request](#receive-a-launch-request)
- [Reply to the caller](#reply-to-the-caller)
- [Terminate another app](#terminate-another-app)
- [Deep linking entry points](#deep-linking-entry-points)
- [Workflow: Wire an App-Control Endpoint](#workflow-wire-an-app-control-endpoint)
- [Pitfalls](#pitfalls)

## App Control vs. plain plugin usage

`tizen_app_control` is one of many `*_tizen` plugins, but the workflow crosses a process boundary, requires privileges, and demands an explicit `<app-control>` block in `tizen-manifest.xml` for the receiving side. Generic Tizen plugins (`messageport_tizen`, `permission_handler_tizen`) operate inside one process and need no manifest registration.

Use this skill when the integration crosses an app boundary. Use [flutter-tizen-use-plugins](../flutter-tizen-use-plugins/SKILL.md) for everything else.

## Send a launch request

```dart
import 'package:tizen_app_control/tizen_app_control.dart';

Future<void> openSettingsScreen() async {
  final appControl = AppControl(
    appId: 'org.tizen.setting',
  );
  await appControl.sendLaunchRequest();
}

Future<void> openUri(String uri) async {
  final appControl = AppControl(
    operation: 'http://tizen.org/appcontrol/operation/view',
    uri: uri,
  );
  await appControl.sendLaunchRequest();
}
```

Constructor parameters (all optional):

- `appId` — pin the target app (e.g. `org.tizen.setting`).
- `operation` — in the `http://tizen.org/appcontrol/operation/*` namespace.
- `uri` / `mime` / `category` — let the framework resolve a handler.
- `launchMode` — defaults to `LaunchMode.single`; use `LaunchMode.group` for a new instance.
- `extraData` — `Map<String, dynamic>` of key/value pairs the receiver reads.

To launch-and-await-reply, pass a callback:

```dart
await appControl.sendLaunchRequest(
  replyCallback: (request, reply, result) {
    // result is AppControlReplyResult; reply is the AppControl carrying extraData
  },
);
```

`appControl.getMatchedAppIds()` returns the list of installed apps that can handle the request — useful when there is no explicit `appId`.

## Receive a launch request

A Flutter app declares the operations it handles in `tizen-manifest.xml`:

```xml
<app-control>
  <operation name="http://tizen.org/appcontrol/operation/view"/>
  <uri name="myapp"/>
  <mime name="application/json"/>
</app-control>
```

In Dart, subscribe before `runApp` — the stream yields `ReceivedAppControl` for both the cold-start launch and any subsequent in-process launches:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tizen_app_control/tizen_app_control.dart';

late final StreamSubscription<ReceivedAppControl> _appControlSub;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _appControlSub = AppControl.onAppControl.listen((ReceivedAppControl request) async {
    final route = request.extraData['route'] as String?;
    if (route != null) {
      navigatorKey.currentState?.pushNamed(route);
    }
  });
  runApp(const MyApp());
}
```

`AppControl.onAppControl` is a static `Stream<ReceivedAppControl>`. Subscribing in `main` before `runApp` is what guarantees the cold-start delivery — the plugin replays the initial request to the first subscriber. Subscribing later (e.g. inside a screen's `initState`) is the most common cause of "the deep link works only when the app is already running."

## Reply to the caller

`ReceivedAppControl.shouldReply` tells whether the caller expects a reply. If it is `true` and the receiver does not reply, the caller hangs until its own timeout fires.

```dart
AppControl.onAppControl.listen((ReceivedAppControl request) async {
  if (request.shouldReply) {
    final replyControl = AppControl(
      extraData: {'result': 'ok', 'payload': '...'},
    );
    await request.reply(replyControl, AppControlReplyResult.succeeded);
  }
});
```

`reply(AppControl reply, AppControlReplyResult result)` takes the reply payload (as another `AppControl` carrying `extraData`) plus the result enum (`succeeded`, `failed`, `cancelled`).

## Terminate another app

```dart
await AppControl(appId: 'org.tizen.setting').sendTerminateRequest();
```

`sendTerminateRequest` is the only termination path on the plugin — there is no `AppControl.terminate()` helper. Requires the `http://tizen.org/privilege/appmanager.kill` (or `.kill.bgapp`) privilege depending on the target.

## Deep linking entry points

Two patterns coexist on Tizen:

- **Custom scheme** (`myapp://settings/profile`). Declare `<uri name="myapp"/>` in `<app-control>` and parse `request.uri` in Dart.
- **Web URL** (`https://example.com/...`). Tizen TVs route HTTPS URLs through Smart Hub; require additional Samsung-side allowlisting. Custom schemes are simpler for in-product deep links.

Map the URI to the in-app router (`go_router`, custom `Navigator`) — keep routing logic in one place so the deep-link handler shares it with regular navigation.

## Workflow: Wire an App-Control Endpoint

Copy this checklist when adding App Control to an app:

### Task Progress
- [ ] **Step 1: Add `tizen_app_control`** to `pubspec.yaml` and run `flutter-tizen pub get`.
- [ ] **Step 2: For the sending side**, build an `AppControl(...)` and call `sendLaunchRequest()`. Pin `appId` for system targets; let URI/MIME resolution pick a handler otherwise.
- [ ] **Step 3: For the receiving side**, declare every supported `<operation>`, `<uri>`, and `<mime>` in `tizen-manifest.xml` under `<app-control>`.
- [ ] **Step 4: Subscribe to `AppControl.onAppControl`** in `main`, before `runApp`. Hold the subscription for the lifetime of the app.
- [ ] **Step 5: Reply when `request.shouldReply` is true** using `request.reply(AppControl(extraData: ...), AppControlReplyResult.succeeded)`.
- [ ] **Step 6: Wire the deep-link handler into the router** so the same code path serves user navigation and external launches.
- [ ] **Step 7: Test cold-start and warm receive separately** on a real device — emulator launcher behavior differs from a real TV's Smart Hub.

## Pitfalls

| Symptom | Likely cause | Action |
|---|---|---|
| `App control request was not delivered` on send | Target app not installed / wrong `appId` | Verify with `sdb shell pkgcmd -l \| grep <appId>` |
| Deep link works while app is open, not on cold start | Subscribing to `onAppControl` after `runApp` (e.g. in a screen's `initState`) | Subscribe in `main` before `runApp` |
| Receiver never wakes | `<app-control>` missing from `tizen-manifest.xml` | Add the operation / uri / mime and rebuild — manifest is not hot-reloaded |
| Caller hangs forever | Receiver did not reply when `shouldReply == true` | Call `request.reply(...)` in every handler that may be invoked-for-result |
| `extraData` values lose type info | The underlying Tizen API serialises everything to `String` | Encode complex values as JSON strings; decode on read |
| `sendTerminateRequest` throws permission denied | Missing kill privilege | Add `http://tizen.org/privilege/appmanager.kill` or `.kill.bgapp` |

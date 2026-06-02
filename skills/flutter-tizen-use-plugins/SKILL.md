---
name: flutter-tizen-use-plugins
description: Pick and wire up Tizen-side Flutter plugins (Samsung-maintained `*_tizen` packages and Tizen-exclusive plugins such as `tizen_app_control`, `messageport_tizen`, `permission_handler_tizen`). Use when a cross-platform plugin lacks Tizen support, when needing a Tizen-only feature (app-control, messageport, package manager), when a Tizen plugin throws `PRIVILEGE_DENIED` / crashes at runtime due to a missing privilege, or when declaring privileges in `tizen-manifest.xml`. Covers privilege declaration + runtime permission for *any* `*_tizen` plugin.
metadata:
  target: flutter-tizen
  category: plugins
  last_modified: Wed, 27 May 2026 08:02:04 GMT
---
# Selecting and integrating Tizen Flutter plugins

## How Tizen plugins are distributed

Three layouts you will encounter:

1. **Endorsed federated plugin.** The base plugin (e.g. `shared_preferences`) lists `shared_preferences_tizen` as an explicit dep. Adding only the base plugin pulls in Tizen support automatically.
2. **Unendorsed federated plugin.** The base plugin does not know about Tizen. You must list both `shared_preferences` *and* `shared_preferences_tizen` in `pubspec.yaml` for Tizen builds to use the Tizen implementation.
3. **Tizen-exclusive plugin.** Single package, no cross-platform parent (`tizen_app_control`, `messageport_tizen`, `tizen_package_manager`, `tizen_log`, `audio_session_tizen`, `app_settings_tizen`, …). Use directly.

Samsung publishes maintained packages under https://github.com/flutter-tizen/plugins. Treat this repo as the source of truth for whether a Tizen variant exists.

## Picking the right plugin

Decision flow:

1. Find the closest cross-platform plugin on pub.dev.
2. Search the [flutter-tizen/plugins repo](https://github.com/flutter-tizen/plugins) and pub.dev for `<plugin-name>_tizen`.
3. If found, check whether it's **endorsed** by the base plugin (open the base plugin's `pubspec.yaml` and look in `flutter.plugin.platforms.tizen`). Endorsed → add only the base. Unendorsed → add both.
4. If not found, evaluate Tizen-exclusive substitutes:
   - App-to-app intents / deep links → `tizen_app_control`.
   - In-process IPC between a UI app and a service app → `messageport_tizen`.
   - Privacy-privileged APIs (location, camera, mic, storage) → `permission_handler_tizen` plus the right `<privilege>` entry.
   - System info / device capabilities → `tizen_system_info` or a small native plugin.
5. If none of the above fits, escalate to [flutter-tizen-create-plugin](../flutter-tizen-create-plugin/SKILL.md).

Catalog of commonly-used Tizen plugins:

| Need | Plugin | Notes |
|---|---|---|
| Local key-value storage | `shared_preferences_tizen` | Endorsed |
| File system paths | `path_provider_tizen` | Dart-FFI based, no native code |
| HTTP fetch (no plugin needed) | `package:http` | Works out of the box on Tizen |
| WebView | `webview_flutter_tizen` | Backed by Tizen EWK |
| Connectivity status | `connectivity_plus_tizen` | Unendorsed; list both packages |
| Battery info | `battery_plus_tizen` | Unendorsed |
| Vibration | `vibration_tizen` | Requires `haptic` privilege |
| URL launcher | `url_launcher_tizen` | Endorsed |
| Send / receive Tizen app-control intent | `tizen_app_control` | Tizen-exclusive |
| Cross-app messaging (UI ↔ service) | `messageport_tizen` | Tizen-exclusive |
| Runtime permissions | `permission_handler` + `permission_handler_tizen` | Add both packages; import `permission_handler` |
| Foreground / background notifications | `flutter_local_notifications_tizen` | Requires `notification` privilege |

(Always verify the latest version on pub.dev — the catalog rotates.)

## Declaring privileges in tizen-manifest.xml

Tizen privileges live in `tizen/tizen-manifest.xml`. Three categories matter:

- **Normal privileges** — declared in the manifest and granted automatically (e.g. `internet`, `network.get`, `haptic`).
- **Privacy privileges** — declared in the manifest *and* must be requested at runtime via `permission_handler_tizen` before first use (e.g. `location`, `camera`, `microphone`, `mediastorage`, `externalstorage`, `account.read`).
- **Platform privileges** — restricted to platform-signed apps; ordinary store apps cannot use them.

Add privileges inside the `<privileges>` block:

```xml
<manifest package="com.example.demo" version="1.0.0" api-version="6.0"
          xmlns="http://tizen.org/ns/packages">
    <profile name="common"/>
    <ui-application appid="com.example.demo" exec="runner" type="capp"
                    multiple="false" nodisplay="false" taskmanage="true"
                    hw-acceleration="on">
        <label>demo</label>
        <icon>ic_launcher.png</icon>
    </ui-application>
    <privileges>
        <privilege>http://tizen.org/privilege/internet</privilege>
        <privilege>http://tizen.org/privilege/haptic</privilege>
        <!-- Privacy privilege: also requires runtime permission -->
        <privilege>http://tizen.org/privilege/location</privilege>
    </privileges>
    <feature name="http://tizen.org/feature/screen.size.all"/>
</manifest>
```

Most plugins list their required privileges in their README. If the plugin calls a Native API marked `privlevel="public"` in the Tizen docs, the corresponding `http://tizen.org/privilege/...` URL must appear in the manifest, or the call fails at runtime with `permission denied` even though Dart returned no error from `await Permission.x.request()`.

## Plugin patterns to know

### `tizen_app_control` — launch and receive app-control intents

```dart
import 'package:tizen_app_control/tizen_app_control.dart';

// Send: open a URL in the system browser
final control = AppControl(
  operation: 'http://tizen.org/appcontrol/operation/view',
  uri: 'https://flutter.dev',
);
await control.sendLaunchRequest();

// Receive: handle the launch that started or resumed this app
AppControl.onAppControl.listen((received) {
  debugPrint('extras: ${received.extraData}');
});
```

Wires straight into deep linking — no extra glue needed.

### `messageport_tizen` — talk to a Tizen service app

```dart
import 'package:messageport_tizen/messageport_tizen.dart';

final remote = await RemotePort.connect('com.example.service', 'channel');
remote.send({'cmd': 'ping'});

final local = await LocalPort.create('channel');
local.register((Map<String, dynamic> msg, _) => debugPrint('got $msg'));
```

Required when a foreground UI app must talk to a long-running Tizen service app (see the `service-app` template).

### `permission_handler_tizen` — runtime permission for privacy privileges

```dart
import 'package:permission_handler/permission_handler.dart';

if (!await Permission.location.isGranted) {
  final status = await Permission.location.request();
  if (status != PermissionStatus.granted) return;
}
```

This call **does not work** without the matching `<privilege>` line in `tizen-manifest.xml`; it returns `denied` instantly.

## Workflow: Add a Tizen Plugin

### Task Progress
- [ ] **Step 1: Decide.** Cross-platform with Tizen variant, or Tizen-exclusive? Endorsed or unendorsed?
- [ ] **Step 2: Add to `pubspec.yaml`** with `flutter-tizen pub add <plugin>` (and the Tizen sibling, if unendorsed).
- [ ] **Step 3: Sync.** `flutter-tizen pub get` and confirm `.dart_tool/package_config.json` lists the plugin.
- [ ] **Step 4: Read the plugin README** for required privileges and feature declarations.
- [ ] **Step 5: Update `tizen/tizen-manifest.xml`** — add `<privilege>` entries and any `<feature>` selectors.
- [ ] **Step 6: For privacy privileges**, add a runtime request flow via `permission_handler` (or the plugin's own permission API).
- [ ] **Step 7: Build + install** on the actual target profile. Privilege failures are profile-specific — e.g. some `tv` profiles silently drop privileges that work on `common`.
- [ ] **Step 8: Verify at runtime** by exercising the plugin code path and watching the foreground `flutter-tizen run` console for the call result or a `PlatformException` (e.g. `permission denied`).

## Verifying the plugin works

> `sdb dlog` / `sdb shell` do not work on Tizen TV targets (verified: `sdb capability` shows `secure_protocol:enabled`). Verify from the **foreground `flutter-tizen run` console** instead.

Plugin registration and Dart-side `print`/`debugPrint` appear directly in the `run` console. Surface native failures to the Dart side so they show there too:

```dart
try {
  final result = await MyPlugin.doThing();
  debugPrint('plugin ok: $result');
} on PlatformException catch (e) {
  debugPrint('plugin failed: ${e.code} ${e.message}'); // e.g. permission denied
}
```

(A plugin's native `ERR_*` macros log to dlog, which is unavailable on TV — catch the call on the Dart side as above to see the failure in the `run` console.)

A common false-positive: `flutter-tizen pub get` succeeds but the plugin's native code is missing from the TPK. Confirm with:

```sh
unzip -l build/tizen/tpk/*.tpk | grep -E 'lib/.*\.so'
```

For default `staticLib` plugins, `lib/libflutter_plugins.so` should appear under `lib/`; plugin-specific `.so` files appear only for `sharedLib` plugins. If the expected library is missing, run `flutter-tizen clean && flutter-tizen build tpk ...`.

## Pitfalls

- **Forgetting the Tizen sibling for unendorsed plugins.** `connectivity_plus` will compile without `connectivity_plus_tizen`, but its method channel is unimplemented and every call throws `MissingPluginException`.
- **Declaring a privilege the device profile doesn't allow.** Some TV firmware rejects packages that request platform privileges; installing prints `not authorized` at install time.
- **Trusting `permission_handler` alone.** Without a manifest privilege the runtime API instantly returns `denied`. Always check both layers.
- **API-version mismatch.** A plugin built against `api-version="6.0"` won't link on a 5.5 device. Bump the project's manifest `api-version` (and `device-profile`) to match what the plugin requires.
- **Stale build cache.** When swapping endorsed ↔ unendorsed, `flutter-tizen clean` is mandatory — pub cache and plugin registry are otherwise stale.

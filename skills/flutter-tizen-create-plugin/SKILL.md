---
name: flutter-tizen-create-plugin
description: Scaffold a new Tizen-side Flutter plugin (C++ or C#), wire it to Dart through a method channel, declare the right privileges in `tizen-manifest.xml`, and validate it against a device or emulator. Use when no existing Tizen plugin wraps a needed Tizen Native API, or when extending a cross-platform plugin with a `_tizen` implementation.
metadata:
  target: flutter-tizen
  category: plugins
---
# Creating a Tizen Flutter plugin

## Contents
- [Decide: C++, C#, or Dart FFI](#decide-c-c-or-dart-ffi)
- [Decide: standalone vs federated implementation](#decide-standalone-vs-federated-implementation)
- [Scaffold the plugin](#scaffold-the-plugin)
- [Implement the C++ side](#implement-the-c-side)
- [Implement the Dart side](#implement-the-dart-side)
- [Declare privileges and features](#declare-privileges-and-features)
- [Workflow: Bring up a New Plugin](#workflow-bring-up-a-new-plugin)
- [Testing the plugin](#testing-the-plugin)
- [Pitfalls](#pitfalls)

## Decide: C++, C#, or Dart FFI

| Language | When to pick it | When not to |
|---|---|---|
| **C++** | The Tizen Native API you need is a C header (`<system_info.h>`, `<app_control.h>`, `<bluetooth.h>`, …). Most TV-supported APIs are C. | TV does not support .NET runtime apps — avoid C# for TV plugins. |
| **C#** | Targeting Tizen .NET / common profile and the API is exposed via Tizen.* assemblies. | TV (no .NET runtime), or perf-sensitive native loops. |
| **Dart FFI** | The API is a stable C ABI exposed by a system shared library and there's no event-callback handshake needed. | Anything that needs Tizen lifecycle bindings, registrar messengers, or `Ecore_*` mainloop integration. |

This skill focuses on **C++ plugins**, which are the path you take for almost everything TV.

## Decide: standalone vs federated implementation

- **Adding Tizen support to an existing plugin** (e.g. you want `foobar_tizen` to back `foobar`):
  - Use the plugin name `<base>_tizen` (`foobar_tizen`).
  - Implement the platform interface from the base plugin.
  - Mark your package as the Tizen implementation in `pubspec.yaml`.
  - Consumers must list both `foobar` and `foobar_tizen` (unless the base plugin endorses you).
- **New, Tizen-only feature** (`tizen_app_control`, `tizen_messageport`, …):
  - Single package, no platform interface package.
  - Pick a `lowercase_with_underscores` name.

## Scaffold the plugin

```sh
# Tizen-only or unendorsed implementation
flutter-tizen create \
    --platforms tizen \
    --template plugin \
    --tizen-language cpp \
    --org com.example \
    foo_tizen

cd foo_tizen
```

This produces:

```
foo_tizen/
├── lib/
│   ├── foo_tizen.dart                       # Dart-facing API
│   └── foo_tizen_method_channel.dart        # MethodChannel wiring
├── tizen/
│   ├── inc/foo_tizen_plugin.h
│   ├── src/foo_tizen_plugin.cc              # C++ implementation
│   ├── src/log.h
│   ├── project_def.prop                     # Tizen native build settings
│   └── tizen-manifest.xml                   # privileges + appid metadata
├── example/                                 # runnable harness app
└── pubspec.yaml
```

When prompted, update `pubspec.yaml` to declare the Tizen plugin class:

```yaml
flutter:
  plugin:
    platforms:
      tizen:
        pluginClass: FooTizenPlugin
        fileName: foo_tizen_plugin.h
```

## Implement the C++ side

Two layers:

1. **Method channel handler** — wired in `RegisterWithRegistrar` (already templated).
2. **Tizen Native API call** — replace the template `getPlatformVersion` body.

Minimal pattern:

```cpp
#include "foo_tizen_plugin.h"

#include <app_common.h>            // example Tizen native header
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "log.h"

namespace {

class FooTizenPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrar *registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "foo_tizen",
            &flutter::StandardMethodCodec::GetInstance());
    auto plugin = std::make_unique<FooTizenPlugin>();
    channel->SetMethodCallHandler(
        [p = plugin.get()] (const auto &call, auto result) {
          p->HandleMethodCall(call, std::move(result));
        });
    registrar->AddPlugin(std::move(plugin));
  }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto &name = call.method_name();
    if (name == "getDataPath") {
      char *path = app_get_data_path();
      if (path == nullptr) {
        result->Error("APP_ERROR", "app_get_data_path returned null");
        return;
      }
      result->Success(flutter::EncodableValue(std::string(path)));
      free(path);
    } else {
      result->NotImplemented();
    }
  }
};

}  // namespace

void FooTizenPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  FooTizenPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrar>(registrar));
}
```

If the Tizen API needs link-time libraries, edit `tizen/project_def.prop`. There are two fields to keep straight:

```
# Source files (already present)
USER_SRCS += src/*.cc

# Tizen Native pkg-config module names — resolves both include dirs and
# link libraries via pkg-config. Use this for capi-* / dlog / vconf / ...
USER_PKGS = capi-appfw-app-common capi-system-info

# Plain link libraries (no -l prefix, no pkg-config). Use this for
# system libs like pthread or for sharedLib plugins that link the
# Flutter embedder directly.
USER_LIBS =

USER_INC_DIRS = inc src
```

Two pitfalls here:

- **`capi-*` belongs in `USER_PKGS`, not `USER_LIBS`.** They are pkg-config modules; resolving them with `USER_LIBS` silently misses the include paths and the build fails at link time with `undefined reference`.
- **Default plugin scaffold is `type = staticLib`.** The plugin is linked into the host TPK at app-build time, so most plugins do not need `USER_LIBS` at all — listing `USER_PKGS` is enough. `USER_LIBS` is mainly needed for `type = sharedLib` plugins (see flutter-tizen PR #407 for that path).

Event channels — replace `MethodChannel` with `EventChannel<flutter::EncodableValue>` and emit via the `StreamHandler` callback.

## Implement the Dart side

```dart
// lib/foo_tizen.dart
import 'foo_tizen_method_channel.dart';

class FooTizen {
  Future<String?> getDataPath() => FooTizenMethodChannel.instance.getDataPath();
}

// lib/foo_tizen_method_channel.dart
import 'package:flutter/services.dart';

class FooTizenMethodChannel {
  FooTizenMethodChannel._();
  static final instance = FooTizenMethodChannel._();
  static const _channel = MethodChannel('foo_tizen');

  Future<String?> getDataPath() => _channel.invokeMethod<String>('getDataPath');
}
```

When implementing a federated platform interface instead, override the base plugin's `XxxPlatform` class and call `XxxPlatform.instance = FooTizenPlatform()` in a `registerWith()` static method (see Flutter's federated-plugin docs for the exact pattern).

## Declare privileges and features

`tizen/tizen-manifest.xml` ships with **no privileges** by default. Native APIs typically refuse to run without the right `<privilege>` line, even if the binary linked successfully.

### Privilege categories

Tizen splits privileges into three tiers, each with a different signing cost:

| Category | Examples | Signing requirement |
|---|---|---|
| **Public** | `internet`, `network.get`, `mediastorage`, `notification` | Any author certificate — signs out of the box. |
| **Partner** | `appmanager.launch`, `usermanagement`, partner-only TV APIs | Samsung partner certificate; request access via the Samsung partner portal. |
| **Platform** | `bluetooth.admin`, `network.profile`, `permission`, low-level VPN | Platform signature — only Tizen vendor builds. Not usable by third parties. |

If a privilege the agent picks is Partner / Platform, surface the limitation explicitly — building will succeed locally but signing fails or the device rejects the TPK on install.

### Privacy (runtime) privileges

A privilege is **privacy-level** if Tizen surfaces a user consent popup at first use. Always assume privacy if the privilege touches identity, sensors, or media:

- `location`
- `camera`
- `recorder` (microphone)
- `mediastorage`
- `externalstorage`
- `contact`
- `account`
- `calendar`
- `messaging.read` / `messaging.write`
- `call`, `callhistory.read`
- `healthinfo`
- `sensor.*` (heart-rate, motion, …)

These require **both** the manifest declaration *and* a runtime request — the manifest alone is not enough; calling the Native API without runtime consent throws `PRIVILEGE_DENIED`.

### Lookup recipe

1. Open the Tizen Native API doc for the function being called (e.g. `app_get_data_path` → "Required privileges: none"; `location_manager_start` → `http://tizen.org/privilege/location`).
2. Add the URL under `<privileges>` in `tizen-manifest.xml`.
3. If it is a privacy privilege, also request it at runtime.
4. If the function needs a hardware feature (camera, bluetooth, NFC), add a matching `<feature>` selector so the package is filtered out on devices that lack the hardware. Without `<feature>`, the store install succeeds on incompatible hardware and the API throws at first call.

Example with both:

```xml
<privileges>
    <privilege>http://tizen.org/privilege/internet</privilege>
    <privilege>http://tizen.org/privilege/mediastorage</privilege>
    <privilege>http://tizen.org/privilege/location</privilege>
</privileges>
<feature name="http://tizen.org/feature/network.internet"/>
<feature name="http://tizen.org/feature/location"/>
```

### Runtime permission flow

Two supported paths:

**Easy path — `permission_handler_tizen`:**

```dart
import 'package:permission_handler_tizen/permission_handler_tizen.dart';

Future<bool> ensureLocation() async {
  var status = await Permission.location.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) {
    // User checked "don't ask again" — open settings.
    await openAppSettings();
    return false;
  }
  status = await Permission.location.request();
  return status.isGranted;
}
```

**Manual path — Tizen `ppm_request_permission` C API:**

```cpp
#include <privacy_privilege_manager.h>

void RequestLocation() {
  ppm_request_permission(
      "http://tizen.org/privilege/location",
      [](ppm_call_cause_e cause,
         ppm_request_result_e result,
         const char* privilege,
         void* user_data) {
        // dispatch back to Dart via MethodChannel reply
      },
      this);
}
```

Always handle three outcomes — granted, denied (re-ask later), denied-forever (open settings). Treating denied-forever as a re-prompt creates an infinite popup loop the user must force-quit.

### Declaring privileges on both sides

Plugin-side `tizen-manifest.xml` is *metadata only* — it describes what the plugin needs, but the host (example app, or consumer app) is what the OS actually evaluates at install / runtime. Two places must agree:

- The plugin's own `tizen-manifest.xml` — for documentation, generator tooling, and the example app fallback.
- Every consumer app's `tizen-manifest.xml` — the OS reads this one. Document the required privileges in the plugin README so consumers know what to copy.

## Workflow: Bring up a New Plugin

### Task Progress
- [ ] **Step 1: Confirm scope.** Standalone or federated? C++ vs C#? Pick once.
- [ ] **Step 2: Scaffold** with `flutter-tizen create --template plugin --tizen-language cpp`.
- [ ] **Step 3: Update `pubspec.yaml`** with the Tizen `pluginClass` and `fileName`.
- [ ] **Step 4: Replace `getPlatformVersion`** in the C++ source with the real Tizen Native API call.
- [ ] **Step 5: Add link libs** in `tizen/project_def.prop` (`USER_LIBS`, `USER_INC_DIRS`).
- [ ] **Step 6: Add `<privilege>` and `<feature>` entries** in both the plugin's own `tizen-manifest.xml` and the example app's `tizen-manifest.xml`.
- [ ] **Step 7: Define the Dart API** in `lib/<plugin>.dart` and the method-channel layer in `lib/<plugin>_method_channel.dart`.
- [ ] **Step 8: Build the example app** for the target profile, install, and exercise every Dart method while watching `sdb dlog`.
- [ ] **Step 9: Add `flutter_test` widget tests** at minimum; integration tests on a real device if the API depends on Tizen runtime state.

## Testing the plugin

```sh
# From the example/ directory of the plugin
cd example
flutter-tizen -d emulator-26101 run --debug

# Tail engine + your own log tag
sdb -s emulator-26101 dlog FooTizen:V ConsoleMessage:V FlutterEngine:I *:S
```

In `src/log.h`, the template defines `LOG_TAG` to your plugin name; emit native logs with `LOGI(...)` / `LOGE(...)` so they show up under that tag. Anchor the Dart layer with `debugPrint` calls so `ConsoleMessage` carries the matching Dart-side state.

For unit tests on the Dart layer, mock `MethodChannel` via `TestDefaultBinaryMessengerBinding`:

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('foo_tizen');
  channel.setMockMethodCallHandler((call) async {
    if (call.method == 'getDataPath') return '/opt/usr/apps/com.example.demo/data/';
    return null;
  });
  test('getDataPath returns', () async {
    expect(await FooTizen().getDataPath(), startsWith('/opt/usr/apps/'));
  });
}
```

## Pitfalls

- **Privilege missing from the *example app's* manifest.** Plugin manifest is metadata only; the host app's manifest decides runtime privileges. Both must declare the privilege.
- **Wrong `api-version`.** A plugin built for `6.0` won't load on a `5.5` device; bumping it past what the device firmware supports breaks `install`. Test on the lowest device version you ship for.
- **`USER_LIBS` syntax.** Library names are bare (`capi-appfw-app-common`), not `-lcapi-appfw-app-common`. The build accepts the wrong form silently and fails at link time with `undefined reference`.
- **Plugin not registered in TPK.** Confirm the plugin's `.so` is packed by `unzip -l build/tizen/tpk/*.tpk | grep <plugin>`. If missing, `flutter-tizen clean` and rebuild.
- **Hot reload skips native changes.** Editing `.cc` requires a full rebuild + reinstall. Only Dart-side changes hot-reload.
- **Memory leaks from Tizen `free`-required strings.** Any Tizen API that returns `char *` typically transfers ownership; always `free()` after copying into `std::string`, as in the template.

## Example

Runnable companion sources live in [`example/README.md`](example/README.md) — open `example/README.md` for the scenario list.

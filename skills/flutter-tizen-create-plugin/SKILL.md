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
        [p = plugin.get()](const auto &call, auto result) {
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

If the Tizen API needs link-time libraries, add them in `tizen/project_def.prop`:

```
USER_LIBS = capi-appfw-app-common
USER_INC_DIRS = inc src
```

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

Lookup recipe:

1. Open the Tizen Native API doc for the function you're calling (e.g. `app_get_data_path` → "Required privileges: none").
2. If a privilege URL is listed, add it under `<privileges>` in `tizen-manifest.xml`.
3. If the privilege is a privacy privilege (e.g. `location`, `mediastorage`, `camera`), also request it at runtime — the *easy* path is `permission_handler_tizen`; the *manual* path is the Tizen `ppm_request_permission` C API.
4. If the function needs a hardware feature (camera, bluetooth, NFC), add a matching `<feature>` selector so the package is filtered out on devices that lack the hardware.

Example with both:

```xml
<privileges>
    <privilege>http://tizen.org/privilege/internet</privilege>
    <privilege>http://tizen.org/privilege/mediastorage</privilege>
</privileges>
<feature name="http://tizen.org/feature/network.internet"/>
```

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

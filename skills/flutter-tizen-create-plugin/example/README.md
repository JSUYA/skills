# Example: Wrap a Tizen Native API as a Flutter plugin

`foo_tizen` plugin exposing `app_get_data_path()` (Tizen Native API) through a `MethodChannel`.

## Files

- `foo_tizen.dart` — Dart-facing API.
- `foo_tizen_plugin.cc` — C++ plugin, registrar + method-channel handler.
- `project_def.prop` — pkg-config wiring (`capi-appfw-app-common`).
- `tizen-manifest.snippet.xml` — privileges + feature declarations the consumer app must copy.

## Scenario

User has a generated `foo_tizen` plugin scaffold and needs to replace its platform-version example with `app_get_data_path()`. Copy these four snippets into the corresponding generated files; keep the generated header, `pubspec.yaml`, and remaining project structure.

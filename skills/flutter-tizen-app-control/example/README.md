# Example: Send + receive App Control

Open the Tizen system Settings app, then accept a launch back from another app and reply with extra data.

## Files

- `send_settings.dart` — `AppControl(appId: 'org.tizen.setting').sendLaunchRequest()`.
- `receive_main.dart` — subscribe to `AppControl.onAppControl` in `main` before `runApp`, handle a `view` operation with a custom URI scheme.
- `reply_for_result.dart` — `sendLaunchRequest(replyCallback: ...)` and the matching `ReceivedAppControl.reply()`.
- `tizen-manifest.snippet.xml` — `<app-control>` block declaring the supported operation, scheme, and MIME.

## Scenario

User wants their app to (1) launch the system Settings, (2) accept a launch from a partner app via `myapp://route/...`, and (3) be launched-for-result from another app and return a JSON payload.

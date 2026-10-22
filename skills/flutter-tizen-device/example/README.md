# Example: Connect to and run a Tizen device

End-to-end session against a real Samsung TV at `192.168.0.101` and a TV emulator.

## Files

- `device_session.sh` — `sdb connect`, verify, and foreground `flutter-tizen run`. The run console prints its host VM Service URL when ready and stays interactive for logs and hot reload; there is no fixed startup delay or background URL scraper.

## Scenario

User just got a fresh TV on the network and wants the project running with a hot-reload-capable VM attached. Set `DEVICE_IP` (and optionally `DEVICE_PORT` / `DEVICE_ID`) and run the script from the app project. It disconnects when the run session ends.

The `A Dart VM Service ... is available at:` URI is the **host HTTP URI** for DevTools. For Dart MCP, keep the session alive and discover the app through `dtd` (`listDtdUris` → `connect`); the fallback is the `ws://host:port/token=/ws` form of this URI, which the DevTools line also prints. CLI `attach --debug-url` needs a different endpoint: the device URI labelled `VM Service URL on device:` in a verbose run (`flutter-tizen -v -d <id> run`); HTTP remains valid there.

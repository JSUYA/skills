# Example: Connect, run, and tail a Tizen device

End-to-end session against a real Samsung TV at `192.168.0.101` and a TV emulator.

## Files

- `device_session.sh` — `sdb connect`, verify, `flutter-tizen run`, and print the VM Service URL.
- `dlog_filter.sh` — recommended log filters for narrowing TV/RPi output to Flutter-relevant tags.

## Scenario

User just got a fresh TV on the network and wants the project running with a hot-reload-capable VM attached. The script handles the connect → verify → run loop and prints the VM Service URL for DevTools or manual attach.

// service/main.dart
// Service-side Dart entry. Keeps a LocalPort registered and replies
// to UI requests.

import 'dart:async';

import 'package:messageport_tizen/messageport_tizen.dart';

LocalPort? _port;

Future<void> main() async {
  _port = await LocalPort.create('worker_in');
  _port!.register((dynamic message, [RemotePort? sender]) async {
    if (message is! Map) return;
    final cmd = message['cmd'] as String?;
    if (cmd == 'poll' && sender != null) {
      final value = await _readSensor();
      await sender.send({'value': value});
    }
  });

  // Keep the isolate alive — without this, the Dart VM exits and
  // Tizen shuts the process down.
  final keepAlive = Completer<void>();
  await keepAlive.future;
}

Future<double> _readSensor() async {
  // Stub for the example. Real code would call the Tizen sensor API
  // via a plugin (e.g. `sensors_plus_tizen`).
  return DateTime.now().millisecondsSinceEpoch / 1000.0;
}

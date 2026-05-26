// ui/poll_sensor.dart
// UI sends one `poll` request; the service replies back to the UI's
// LocalPort. messageport_tizen has no `onMessage` stream — the
// registered callback is the only delivery channel.

import 'package:messageport_tizen/messageport_tizen.dart';

const _kServiceAppId = 'org.example.myapp.service';

class SensorClient {
  LocalPort? _inbox;
  RemotePort? _remote;
  void Function(double)? _onValue;

  Future<void> connect({required void Function(double) onValue}) async {
    _onValue = onValue;
    _inbox = await LocalPort.create('ui_inbox');
    _inbox!.register((dynamic message, [RemotePort? sender]) {
      if (message is Map && message['value'] is num) {
        _onValue?.call((message['value'] as num).toDouble());
      }
    });
    _remote = await RemotePort.connect(_kServiceAppId, 'worker_in');
  }

  Future<void> poll() async {
    if (_remote == null || _inbox == null) {
      throw StateError('connect() before poll()');
    }
    await _remote!.sendWithLocalPort({'cmd': 'poll'}, _inbox!);
  }

  Future<void> dispose() async {
    await _inbox?.unregister();
    _inbox = null;
    _remote = null;
  }
}

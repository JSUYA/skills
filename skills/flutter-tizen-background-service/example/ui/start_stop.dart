// ui/start_stop.dart
// UI-side control of the service lifecycle. Pair with poll_sensor.dart.

import 'package:tizen_app_control/tizen_app_control.dart';

const _kServiceAppId = 'org.example.myapp.service';

Future<void> startService() async {
  await AppControl(appId: _kServiceAppId).sendLaunchRequest();
}

Future<void> stopService() async {
  await AppControl(appId: _kServiceAppId).sendTerminateRequest();
}

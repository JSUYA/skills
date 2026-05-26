// send_settings.dart
// Pin a system app by appId and launch it.

import 'package:tizen_app_control/tizen_app_control.dart';

Future<void> openSettings() async {
  final control = AppControl(appId: 'org.tizen.setting');
  await control.sendLaunchRequest();
}

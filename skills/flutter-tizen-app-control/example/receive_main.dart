// receive_main.dart
// Subscribe BEFORE runApp so the cold-start launch is delivered.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tizen_app_control/tizen_app_control.dart';

final navigatorKey = GlobalKey<NavigatorState>();
late StreamSubscription<ReceivedAppControl> _appControlSub;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _appControlSub = AppControl.onAppControl.listen(_handle);
  runApp(MaterialApp(navigatorKey: navigatorKey, home: const _Home()));
}

Future<void> _handle(ReceivedAppControl request) async {
  // Custom-scheme deep link: myapp://route/<name>
  final uri = request.uri;
  if (uri != null && uri.startsWith('myapp://route/')) {
    navigatorKey.currentState?.pushNamed('/${uri.substring('myapp://route/'.length)}');
  }
}

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Home')));
}

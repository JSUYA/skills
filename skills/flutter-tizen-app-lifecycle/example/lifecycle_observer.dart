// lifecycle_observer.dart
// Reusable WidgetsBindingObserver covering the lifecycle events that
// actually occur on Tizen: paused / resumed / detached / memory pressure
// / locale change.

import 'dart:ui';

import 'package:flutter/material.dart';

mixin TizenLifecycleObserver<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        onPause();
      case AppLifecycleState.resumed:
        onResume();
      case AppLifecycleState.detached:
        onDetached();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient; do not persist here — Tizen fires `inactive` on
        // notification overlays and system dialogs.
        break;
    }
  }

  @override
  void didHaveMemoryPressure() {
    onMemoryPressure();
  }

  // Subclass hooks — override in the using widget.
  void onPause() {}
  void onResume() {}
  void onDetached() {}
  void onMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
  }

  // Stubs to satisfy WidgetsBindingObserver — override if needed.
  @override
  void didChangeAccessibilityFeatures() {}
  @override
  void didChangeLocales(List<Locale>? locales) {}
  @override
  void didChangeMetrics() {}
  @override
  void didChangePlatformBrightness() {}
  @override
  void didChangeTextScaleFactor() {}
  @override
  void didChangeViewFocus(ViewFocusEvent event) {}
  @override
  Future<bool> didPopRoute() async => false;
  @override
  Future<bool> didPushRoute(String route) async => false;
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async => false;
  @override
  Future<AppExitResponse> didRequestAppExit() async => AppExitResponse.exit;
  @override
  void handleCancelBackGesture() {}
  @override
  void handleCommitBackGesture() {}
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => false;
  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {}
}

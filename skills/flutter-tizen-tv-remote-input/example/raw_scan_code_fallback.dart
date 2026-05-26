// raw_scan_code_fallback.dart
// Workaround for flutter-tizen issue #319 — some TV models send remote
// keys as raw scan codes (F1–F12, Left Shift) with no matching
// LogicalKeyboardKey. Place this above MaterialApp so the override
// is reachable from every screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RawScanCodeOverride extends StatelessWidget {
  const RawScanCodeOverride({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // Map physical keys observed on the affected device models.
        switch (event.physicalKey) {
          case PhysicalKeyboardKey.f1:
            // The TV's Red color key arrives as F1 on this model.
            _dispatchRed(context);
            return KeyEventResult.handled;
          case PhysicalKeyboardKey.f5:
            // Media Play/Pause arrives as F5.
            _dispatchPlayPause(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: child,
    );
  }

  void _dispatchRed(BuildContext context) {
    Actions.maybeInvoke<DismissIntent>(context, const DismissIntent());
  }

  void _dispatchPlayPause(BuildContext context) {
    Actions.maybeInvoke<ActivateIntent>(context, const ActivateIntent());
  }
}

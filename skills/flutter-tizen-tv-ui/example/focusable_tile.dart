// focusable_tile.dart
// Tile with 4 px focus outline + 1.04x scale + Semantics for screen reader.

import 'package:flutter/material.dart';

class FocusableTile extends StatefulWidget {
  const FocusableTile({
    super.key,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<FocusableTile> createState() => _FocusableTileState();
}

class _FocusableTileState extends State<FocusableTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(24),
          transform: Matrix4.identity()..scale(_focused ? 1.04 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1A1A1A),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 4,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

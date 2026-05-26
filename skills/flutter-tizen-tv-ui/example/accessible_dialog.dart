// accessible_dialog.dart
// Persistent banner pattern that does not auto-dismiss — replace the
// default SnackBar (3 s) on TV where users may need 10x longer to react.

import 'package:flutter/material.dart';

Future<bool?> showTvConfirmation(
  BuildContext context, {
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // require an explicit choice
    builder: (context) => AlertDialog(
      title: const Text('Please confirm'),
      content: Text(message),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

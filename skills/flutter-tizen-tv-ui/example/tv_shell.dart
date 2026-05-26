// tv_shell.dart
// MaterialApp shell with overscan inset + lifted text scale.

import 'package:flutter/material.dart';

class TvShell extends StatelessWidget {
  const TvShell({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.copyWith(
              bodyMedium: const TextStyle(fontSize: 18),
              titleLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          // 1.6x is a good baseline for 1080p TV at 3 m viewing distance.
          data: media.copyWith(textScaler: const TextScaler.linear(1.6)),
          child: SafeArea(
            child: Padding(
              // ~5% inset on each axis — Tizen TV de-facto overscan margin.
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 27),
              child: child!,
            ),
          ),
        );
      },
      home: home,
    );
  }
}

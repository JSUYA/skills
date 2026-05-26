// persisted_scroll_demo.dart
// Uses the mixin from lifecycle_observer.dart to persist a scroll
// position across pause/resume.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lifecycle_observer.dart';

class PersistedList extends StatefulWidget {
  const PersistedList({super.key});

  @override
  State<PersistedList> createState() => _PersistedListState();
}

class _PersistedListState extends State<PersistedList>
    with TizenLifecycleObserver {
  static const _kKey = 'list_offset';
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getDouble(_kKey) ?? 0;
      if (saved > 0 && _controller.hasClients) {
        _controller.jumpTo(saved);
      }
    });
  }

  @override
  void onPause() async {
    if (!_controller.hasClients) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kKey, _controller.offset);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      itemCount: 500,
      itemBuilder: (_, i) => ListTile(title: Text('Row $i')),
    );
  }
}

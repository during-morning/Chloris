import 'dart:async';

class AudioFocusCoordinator {
  static final instance = AudioFocusCoordinator();
  final _owners = <String, Future<void> Function()>{};
  String? current;
  int _generation = 0;
  void register(String owner, Future<void> Function() pause) =>
      _owners[owner] = pause;
  void unregister(String owner) {
    _owners.remove(owner);
    if (current == owner) current = null;
  }

  Future<bool> acquire(String owner) async {
    final g = ++_generation;
    final previous = current;
    current = owner;
    if (previous != null && previous != owner) await _owners[previous]?.call();
    return g == _generation;
  }
}

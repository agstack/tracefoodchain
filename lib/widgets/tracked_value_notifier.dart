import 'package:flutter/foundation.dart';

/// Wrapper für ValueNotifier der alle Listener trackt
class TrackedValueNotifier<T> extends ValueNotifier<T> {
  final String name;
  final Set<VoidCallback> _trackedListeners = {};

  TrackedValueNotifier(super.value, this.name);

  @override
  void addListener(VoidCallback listener) {
    
    _trackedListeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    
    _trackedListeners.remove(listener);
    super.removeListener(listener);
  }

  @override
  void notifyListeners() {
    
    try {
      super.notifyListeners();
    } catch (e, stackTrace) {

);
      rethrow;
    }
  }

  @override
  set value(T newValue) {
    
    super.value = newValue;
  }

  @override
  void dispose() {
    
    _trackedListeners.clear();
    super.dispose();
  }
}

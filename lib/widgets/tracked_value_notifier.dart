import 'package:flutter/foundation.dart';
import 'package:trace_foodchain_app/helpers/frame_safe_value_notifier.dart';

/// Wrapper für ValueNotifier der alle Listener trackt
///
/// Erbt von [FrameSafeValueNotifier], damit eine Wertänderung mitten im
/// Frame-Aufbau keine Listener innerhalb desselben Frames neu bauen lässt -
/// das erzeugt bei verschachtelten LayoutBuildern den Fehler
/// "_RenderLayoutBuilder was mutated in performLayout".
class TrackedValueNotifier<T> extends FrameSafeValueNotifier<T> {
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

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A [ValueNotifier] that never notifies while a frame is being built.
///
/// Notifying listeners during the build/layout phase makes them rebuild inside
/// that same frame. Where the app nests LayoutBuilders - the container list has
/// two of them - this surfaces as:
///
///   A _RenderLayoutBuilder was mutated in _RenderLayoutBuilder.performLayout
///
/// The value is still stored IMMEDIATELY, so reading `.value` right after
/// writing it returns the new value as usual; only the notification is deferred
/// to the end of the current frame. Repeated writes within one frame collapse
/// into a single notification.
class FrameSafeValueNotifier<T> extends ValueNotifier<T> {
  FrameSafeValueNotifier(super.value);

  bool _notificationScheduled = false;

  @override
  void notifyListeners() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final insideFrame = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!insideFrame) {
      super.notifyListeners();
      return;
    }

    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!hasListeners) return;
      super.notifyListeners();
    });
  }
}

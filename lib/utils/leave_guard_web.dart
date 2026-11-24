// Web: der Browser fragt vor dem Neuladen/Schließen nach, solange der Schutz
// aktiv ist. Den Text der Rückfrage bestimmt der Browser selbst.
import 'dart:async';
import 'dart:html' as html;

StreamSubscription<html.Event>? _subscription;
int _depth = 0;

void enableLeaveGuard() {
  if (_depth++ > 0) return;
  _subscription = html.window.onBeforeUnload.listen((event) {
    if (event is html.BeforeUnloadEvent) {
      event.preventDefault();
      // Ältere Browser zeigen die Rückfrage nur mit gesetztem returnValue.
      event.returnValue = '';
    }
  });
}

void disableLeaveGuard() {
  if (_depth == 0) return;
  if (--_depth > 0) return;
  _subscription?.cancel();
  _subscription = null;
}

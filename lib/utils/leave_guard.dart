/// Warnt im Browser vor dem Neuladen oder Schließen der Seite, solange etwas
/// läuft, das dabei verloren ginge - etwa eine QC-Entscheidung, die noch nicht
/// gespeichert und hochgeladen ist. Auf Mobilgeräten ohne Wirkung.
///
/// Aufrufe dürfen verschachtelt sein: die Warnung bleibt aktiv, bis jedem
/// [enableLeaveGuard] ein [disableLeaveGuard] gefolgt ist.
library;

export 'leave_guard_io.dart' if (dart.library.html) 'leave_guard_web.dart';

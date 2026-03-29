const String APP_VERSION = 'version 1.6.0+26 (2026-03-18)';

// DEBUG ONLY: Überschreibt die Rollen-basierte Navigation für UI-Tests.
// Gültige Werte: '' (deaktiviert), 'registrar', 'Farmer', 'Trader', 'Processor', 'Importer'
// Nur bei kDebugMode aktiv — im Release-Build KEIN Effekt.
const String kDebugViewRole =
    'registrar'; // z.B. 'registrar' zum Testen des Registrar-UIs

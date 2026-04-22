const String APP_VERSION = 'version 1.6.1+27 (2026-04-22)';

// DEBUG ONLY: Überschreibt die Rollen-basierte Navigation für UI-Tests.
// Gültige Werte: '' (deaktiviert), 'registrar', 'Farmer', 'Trader', 'Processor', 'Importer'
// Nur bei kDebugMode aktiv — im Release-Build KEIN Effekt.
const String kDebugViewRole =
'Trader';
    // 'registrar'; // z.B. 'registrar' zum Testen des Registrar-UIs

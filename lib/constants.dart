const String APP_VERSION = 'version 2.0.1+39 (2026-11-03)';

// DEBUG ONLY: Überschreibt die Rollen-basierte Navigation für UI-Tests.
// Gültige Werte: '' (deaktiviert), 'registrar', 'Farmer', 'Trader', 'Processor', 'Importer'
// Nur bei kDebugMode aktiv — im Release-Build KEIN Effekt.
const String kDebugViewRole = 'Trader';
// const String kDebugViewRole = 'registrar';
// 'registrar'; // z.B. 'registrar' zum Testen des Registrar-UIs

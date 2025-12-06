# Registrar Workflow - Änderungen Dokumentation

## Problem
Der ursprüngliche 3-Schritt-Workflow (Farmer → Farm → Felder) im Registrierungs-Stepper war problematisch:
- Gekoppelte Farm- und Feldregistrierung
- Nicht flexibel genug für getrennte Arbeitsabläufe
- Registrar konnte nicht erst mehrere Farmen registrieren und später alle Felder aufzeichnen

## Lösung
**Workflow-Trennung in 2 unabhängige Prozesse:**

### 1. Farm/Farmer Registrierung (2 Schritte)
**Widget:** `lib/widgets/stepper_registrar_registration.dart`
- **Schritt 1:** Farmer-Daten (Vorname, Nachname, National-ID, Telefon)
- **Schritt 2:** Farm-Daten (Farm-Name, Stadt, Region)
- Erstellt Farmer (human) und Farm (farm) mit `objectState: "qcPending"`
- Verknüpft Farm mit Farmer via `linkedObjectRef`
- Speichert in Hive, signiert mit Ed25519, sync-fähig

### 2. Feldgrenzen-Aufzeichnung (separate Funktion)
**Widget:** `lib/widgets/field_boundary_recorder.dart`

#### PFLICHT-Features:
✅ **Farm-Auswahl aus Liste** (Dropdown mit allen Farmen aus localStorage)
✅ **"Farm erstellen" Button** (öffnet StepperRegistrarRegistration in Dialog-Modus)
✅ **GPS-Polygon-Aufzeichnung** (via PolygonRecorderWidget)
✅ **Feld-Name Eingabe** (TextField mit validation)
✅ **PFLICHT-Verknüpfung** Farm↔Field:
   - `field.currentGeolocation.container.UID = farmUID`
   - `field.linkedObjectRef` enthält Farm-Referenz
   - `farm.linkedObjectRef` wird mit Field-Referenz aktualisiert
   - `farm.totalAreaHa` wird mit neuer Feldfläche addiert

#### Workflow:
1. Registrar wählt Farm aus Dropdown (PFLICHT - kann nicht übersprungen werden)
2. Optional: Neue Farm über Button erstellen (öffnet 2-Schritt-Stepper)
3. Feld-Name eingeben
4. GPS-Polygon aufzeichnen (Start → Punkte → Stop)
5. Speichern erstellt:
   - Field-Objekt mit `qcPending` Status
   - Verknüpfung zur ausgewählten Farm
   - `generateDigitalSibling` Methode mit Farm als Input, Field als Output
   - Farm-Update mit neuer totalAreaHa

## Dateien geändert

### NEU erstellt:
- `lib/widgets/field_boundary_recorder.dart` (~380 Zeilen)
  - Farm-Dropdown mit Reload nach Erstellung
  - PolygonRecorderWidget-Integration
  - Pflicht-Validierung (Farm + Feld-Name)
  - openRAL-konforme Field-Erstellung mit Verknüpfungen

### Geändert:
- `lib/widgets/stepper_registrar_registration.dart`
  - Von 3 auf 2 Schritte reduziert (Feld-Aufzeichnung entfernt)
  - ~200 Zeilen Code entfernt (_buildFieldsForm, FieldData class, field creation logic)
  - Fokus nur auf Farmer + Farm Registrierung

- `lib/screens/registrar_screen.dart`
  - Neuer Quick Action Button: "Record Field Boundary" (grün, Icon: terrain)
  - Methode `_openFieldBoundaryRecorder()` mit GPS-Check
  - Import von `field_boundary_recorder.dart`

## Technische Details

### Farm-Field Verknüpfung (3-fach redundant für Datenintegrität):
```dart
// 1. Container-Relationship
field['currentGeolocation']['container']['UID'] = farmUID;

// 2. Field → Farm LinkedObject
field['linkedObjectRef'].add({
  'UID': farmUID,
  'RALType': 'farm',
  'role': 'location',
});

// 3. Farm → Field LinkedObject (in updatedFarm)
farm['linkedObjectRef'].add({
  'UID': fieldUID,
  'RALType': 'field',
  'role': 'parcel',
});
```

### Farm-Flächen-Tracking:
```dart
final currentArea = getSpecificPropertyfromJSON(updatedFarm, 'totalAreaHa') ?? 0.0;
updatedFarm = setSpecificPropertyJSON(
  updatedFarm, 
  'totalAreaHa', 
  currentArea + area,  // area = Shoelace-Formel aus Polygon
  'double'
);
```

## Vorteile der neuen Struktur

✅ **Flexibilität:** Registrar kann mehrere Farmen schnell registrieren, später alle Felder aufzeichnen
✅ **Datenintegrität:** Farm-Field-Verknüpfung KANN NICHT übersprungen werden (UI erzwingt Auswahl)
✅ **Offline-First:** Beide Workflows funktionieren ohne Internet, sync bei Verbindung
✅ **QC-Workflow:** Alle Objekte mit `qcPending` Status für spätere Validierung in `registrar_qc_screen.dart`
✅ **GPS-Sicherheit:** Beide Workflows prüfen GPS-Verfügbarkeit vor Start

## Nächste Schritte (zukünftige Erweiterungen)

- [ ] Asset Registry Integration für GeoID-Zuweisung zu Feldern
- [ ] WHISP API Integration für Deforestation Risk Scoring nach Field-Erstellung
- [ ] Batch-Import von Farmen via CSV/Excel
- [ ] Offline-Maps für Registrar-Arbeit in abgelegenen Gebieten
- [ ] Field-Edit-Funktion für Korrektur von Polygon-Grenzen
- [ ] Statistiken-Dashboard (heute registrierte Farmen/Felder)

## Testing Checklist

- [x] Compile-Fehler geprüft (keine Fehler)
- [x] Localization-Keys validiert (alle existieren)
- [x] Farm-Dropdown lädt Farmen aus localStorage
- [x] GPS-Check funktioniert vor Field-Recording
- [x] Farm-Field-Verknüpfung wird korrekt gespeichert
- [ ] Integration-Test: Farm registrieren → Field aufzeichnen → QC approven
- [ ] Test: Neue Farm während Field-Recording erstellen
- [ ] Test: Mehrere Felder für dieselbe Farm aufzeichnen (totalAreaHa addiert sich)
- [ ] Test: Offline-Sync nach Internet-Verbindung

## User Journey

### Registrar im Feld (Honduras Hochland):
1. Öffnet App, Login als Registrar
2. Quick Action: "Register Farm/Farmer" → 2-Schritt-Formular ausfüllen → Speichern
3. Wiederholt Schritt 2 für mehrere Farmen (schneller Durchlauf)
4. Quick Action: "Record Field Boundary" → Farm aus Liste wählen
5. Feld-Name eingeben → GPS-Aufzeichnung starten
6. Um Feld herumlaufen (Auto-Punkte alle 5m + manuell bei Ecken)
7. Zurück zum Startpunkt → Polygon schließt automatisch → Fläche anzeigen → Speichern
8. Nächstes Feld für dieselbe oder andere Farm aufzeichnen
9. Bei Internet-Verbindung: Automatischer Sync zu Firebase/Cloud

### QC-Reviewer im Büro:
1. Login als Registrar (oder dedizierte QC-Rolle)
2. Quick Action: "Review Pending Registrations"
3. Filter: "Fields only" oder "All"
4. Aufklappbare Karten mit Details (Name, Farm, Fläche, Recorder, Timestamp)
5. Approve: Notizen eingeben → Status → qcApproved
6. Reject: Ablehnungsgrund → Status → qcRejected
7. Alle Änderungen digitally signed, synced to cloud


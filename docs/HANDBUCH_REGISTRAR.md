# Handbuch: Registrar-App

> **Sprachen:** **Deutsch** · [English](HANDBOOK_REGISTRAR.md) · [Español](MANUAL_REGISTRAR.md)
>
> **Zielgruppe:** Registrare im Außendienst (Erfassung von Landwirten, Farmen und Feldgrenzen)
> **Stand:** August 2026 · Trace Foodchain App
> **Sprache der App:** über das Sprachsymbol oben rechts umstellbar (DE / EN / ES / FR). Die in diesem Handbuch genannten Beschriftungen entsprechen der deutschen Oberfläche.

---

## Inhalt

1. [Was macht der Registrar?](#1-was-macht-der-registrar)
2. [Voraussetzungen](#2-voraussetzungen)
3. [Das Dashboard im Überblick](#3-das-dashboard-im-überblick)
4. [Workflow A: Farm/Landwirt registrieren](#4-workflow-a-farmlandwirt-registrieren)
5. [Workflow B: Feldgrenzen aufzeichnen](#5-workflow-b-feldgrenzen-aufzeichnen)
6. [Verlauf: erfasste Daten prüfen und nachbearbeiten](#6-verlauf-erfasste-daten-prüfen-und-nachbearbeiten)
7. [Offline arbeiten und Daten hochladen](#7-offline-arbeiten-und-daten-hochladen)
8. [Werkzeuge & Einstellungen](#8-werkzeuge--einstellungen)
9. [Was nach dem Upload passiert (Qualitätskontrolle)](#9-was-nach-dem-upload-passiert-qualitätskontrolle)
10. [Meldungen und häufige Fragen](#10-meldungen-und-häufige-fragen)
11. [Übersicht der Screenshots](#11-übersicht-der-screenshots)

---

## 1. Was macht der Registrar?

Der Registrar erfasst im Feld die Stammdaten der Lieferkette:

- **Landwirte** (Person, Ausweis, Kontaktdaten, Einverständniserklärung)
- **Farmen** (Name, Lage, geschätzte Kaffeeanbaufläche)
- **Felder / Parzellen** (per GPS abgelaufene Feldgrenze als Polygon, mit Feldfoto)

Alle Daten werden **zuerst auf dem Gerät gespeichert** und später – sobald Internet verfügbar ist – in die Cloud übertragen. Die App ist damit vollständig offline benutzbar.

Jede Registrierung geht anschließend in die **Qualitätskontrolle (QC)** beim Registrar Coordinator (siehe [Kapitel 9](#9-was-nach-dem-upload-passiert-qualitätskontrolle)).

---

## 2. Voraussetzungen

| Voraussetzung | Warum |
|---|---|
| Anmeldung mit dem Registrar-Konto | Ohne Anmeldung ist der lokale Datenspeicher nicht geöffnet, es kann nichts gespeichert werden. |
| **GPS aktiviert** und Standortfreigabe erteilt | Ohne GPS lassen sich weder Registrierung noch Feldaufzeichnung starten. |
| Kamerafreigabe | Ausweisfoto, Einverständniserklärung und Feldfoto sind Pflichtaufnahmen. |
| Geladener Akku / Speicherplatz | Fotos werden bis zum Upload lokal auf dem Gerät gehalten. |

> Internet ist **nicht** Voraussetzung für die Erfassung – nur für den späteren Upload.

---

## 3. Das Dashboard im Überblick

Nach der Anmeldung als Registrar öffnet sich das **Registrar Dashboard**. Es ist von oben nach unten nach Arbeitsablauf sortiert: *Wer bin ich → Kann ich jetzt arbeiten → Was tue ich → Was habe ich geschafft → Selten Gebrauchtes*.

> 📷 **Screenshot 01** – Gesamtes Dashboard direkt nach dem Login (ganzer Bildschirm, Werkzeuge-Bereich eingeklappt).
>
> ![Registrar Dashboard](screenshots/registrar-01-dashboard.png)

### 3.1 Kopfzeile

| Symbol | Funktion |
|---|---|
| 🌐 Sprache | Sprache der App umschalten (DE / EN / ES / FR) |
| 👤 Profil | **Profil anzeigen und bearbeiten**: Profilfoto, Vorname, Nachname, Telefonnummer |
| ⏻ Logout | Abmelden (mit Sicherheitsabfrage) |

> 📷 **Screenshot 02** – Dialog „Profil bearbeiten" mit Profilfoto und Eingabefeldern.
>
> ![Profil bearbeiten](screenshots/registrar-02-profil.png)

### 3.2 Begrüßung

Zeigt den eigenen Namen und die Rollen-Kennzeichnung **REGISTRAR**. Steht statt des Namens die E-Mail-Adresse, sind im Profil noch kein Vor-/Nachname hinterlegt.

### 3.3 Statusstreifen – „Kann ich jetzt arbeiten?"

Drei Anzeigen nebeneinander:

**① GPS**

| Anzeige | Bedeutung |
|---|---|
| „Suche…" | Position wird noch ermittelt |
| ± 3 m (grün) | Ausgezeichnet – unter 5 m Abweichung |
| ± 8 m (hellgrün) | Gut – unter 10 m |
| ± 15 m (orange) | Ausreichend – unter 20 m |
| ± 30 m (rot) | Schlecht – Feldgrenzen sollten so nicht aufgezeichnet werden |
| GPS aus / kein Fix | Antippen öffnet die Hinweise zum Aktivieren |

**② Verbindung** – „Online" (grün) oder „Offline" (grau). Offline ist kein Fehler: es wird normal weitergearbeitet.

**③ Upload-Status**

| Anzeige | Bedeutung |
|---|---|
| ☁️ „Synchron" (grün) | Alles ist in der Cloud angekommen |
| ☁️ „*N* offen" (orange) | *N* Datensätze warten noch auf den Upload |
| ☁️ „Pausiert" (orange, mit Zahl-Badge) | Upload ist bewusst pausiert; die Zahl zeigt die wartenden Datensätze |

**Antippen öffnet das Sync-Panel** mit Details (siehe [Kapitel 7](#7-offline-arbeiten-und-daten-hochladen)).

> 📷 **Screenshot 03** – Statusstreifen in der Nahaufnahme, idealerweise mit offenen Uploads (orange).
>
> ![Statusstreifen](screenshots/registrar-03-statusstreifen.png)

### 3.4 Die beiden Hauptaufgaben

| Schaltfläche | Aufgabe |
|---|---|
| 🌱 **Farm/Landwirt registrieren** (grün) | Neuen Landwirt samt Farm anlegen → [Kapitel 4](#4-workflow-a-farmlandwirt-registrieren) |
| 🗺️ **Feldgrenzen aufzeichnen** (blau) | Feldgrenze einer bestehenden Farm ablaufen → [Kapitel 5](#5-workflow-b-feldgrenzen-aufzeichnen) |

Beide prüfen zuerst das GPS. Ist es aus, erscheint **„GPS muss für Registrierung aktiviert sein"** – erst GPS einschalten, dann erneut tippen.

> 📷 **Screenshot 04** – Hinweisdialog „GPS muss für Registrierung aktiviert sein".
>
> ![GPS-Hinweis](screenshots/registrar-04-gps-hinweis.png)

### 3.5 Tagesleistung und Verlauf

Die Karte zeigt links groß **„Heute registriert"**, rechts daneben **„Verifiziert"** (grün) und **„Ausstehend"** (orange).

So werden die Zahlen gebildet – alle drei beziehen sich auf **dieselbe Menge** (Landwirte, Farmen, Felder/Parzellen) **auf diesem Gerät**:

| Zahl | Bedeutung |
|---|---|
| Heute registriert | Datensätze, die **heute** angelegt wurden |
| Verifiziert | Datensätze, welche die Qualitätskontrolle **bestanden** haben |
| Ausstehend | Datensätze, die noch **auf die QC warten** |

> Das eigene Benutzerprofil wird nicht mitgezählt. Die Zahlen entsprechen genau dem, was der **Verlauf** auflistet.

Am unteren Rand der Karte führt **„Verlauf anzeigen"** zur vollständigen Liste → [Kapitel 6](#6-verlauf-erfasste-daten-prüfen-und-nachbearbeiten).

> 📷 **Screenshot 05** – Tageskarte mit Zahlen > 0 und der Zeile „Verlauf anzeigen".
>
> ![Tagesleistung](screenshots/registrar-05-tagesleistung.png)

### 3.6 Werkzeuge & Einstellungen

Eingeklappter Bereich am Seitenende → [Kapitel 8](#8-werkzeuge--einstellungen).

---

## 4. Workflow A: Farm/Landwirt registrieren

Die Registrierung führt in **drei Schritten** durch das Formular. Jeder Schritt wird beim Weitertippen geprüft; fehlt eine Pflichtangabe, erscheint unten eine Meldung und es geht nicht weiter.

> 📷 **Screenshot 06** – Stepper-Übersicht mit den drei Schritten (Schritt 1 geöffnet).
>
> ![Registrierung Schritt 1](screenshots/registrar-06-stepper-uebersicht.png)

### Schritt 1 – Landwirt-Informationen

| Feld | Pflicht | Hinweis |
|---|---|---|
| Vorname | ✔ | |
| Nachname | ✔ | |
| Personalausweis (Nummer) | – | wird als zusätzliche Kennung gespeichert |
| **Ausweis-Foto** | ✔ | Foto des Ausweisdokuments; ohne Foto kein Weiterkommen |
| Telefonnummer | – | Format z. B. `+504-9999-8888` |
| E-Mail | – | |

Der Rahmen um den Foto-Bereich zeigt den Zustand: **rot** = Foto fehlt, **grün** = Foto vorhanden (mit Vorschaubild). Über **„Ausweis-Foto erneut aufnehmen"** lässt sich die Aufnahme wiederholen.

> 📷 **Screenshot 07** – Schritt 1 mit ausgefüllten Feldern und aufgenommenem Ausweis-Foto (grüner Rahmen).
>
> ![Landwirt-Informationen](screenshots/registrar-07-landwirt.png)

### Schritt 2 – Datennutzungseinwilligung

Der Landwirt unterschreibt die Einverständniserklärung auf Papier; **das unterschriebene Formular wird abfotografiert**. Auch dieses Foto ist Pflicht.

> 📷 **Screenshot 08** – Schritt 2 mit fotografierter Einverständniserklärung.
>
> ![Einverständniserklärung](screenshots/registrar-08-einverstaendnis.png)

### Schritt 3 – Farm-Informationen

| Feld | Pflicht | Hinweis |
|---|---|---|
| Farm-Name | ✔ | |
| Farm-ID | – | betriebsinterne Kennung, falls vorhanden |
| Gemeinde | – | |
| Dorf/Gemeinschaft | – | |
| Bundesland/Departamento | – | |
| E-Mail | – | Kontakt der Farm |
| Geschätzte Kaffeeanbaufläche | – | Zahl **plus Einheit** aus der Auswahlliste rechts daneben |

Mit **„Registrierung abschließen"** werden Landwirt und Farm angelegt.

> 📷 **Screenshot 09** – Schritt 3 mit Flächenangabe und Einheiten-Auswahl.
>
> ![Farm-Informationen](screenshots/registrar-09-farm.png)

### Nach dem Abschluss

- Landwirt und Farm werden **lokal gespeichert** und erhalten den Status **Ausstehend** (wartet auf QC).
- Die Fotos bleiben zunächst auf dem Gerät und gehen mit dem nächsten Upload mit.
- Es erscheint eine Erfolgsmeldung; danach steht die Tageszahl auf dem Dashboard um die neuen Einträge höher.
- Während des Speicherns zeigt ein Overlay den Fortschritt (bei aktivem Upload auch den Foto-Upload in Prozent).

> ⚠️ **Abbrechen:** Wird das Formular mit bereits eingegebenen Daten verlassen, fragt die App nach, ob die Daten **verworfen** werden sollen. Verworfene Eingaben lassen sich nicht wiederherstellen.

> 📷 **Screenshot 10** – Fortschritts-Overlay bzw. Erfolgsmeldung nach Abschluss.
>
> ![Registrierung abgeschlossen](screenshots/registrar-10-abschluss.png)

---

## 5. Workflow B: Feldgrenzen aufzeichnen

### 5.1 Farm auswählen (Pflicht)

Ein Feld gehört **immer zu einer Farm**. Zuerst wird deshalb die Farm gewählt.

- Ist noch keine Farm erfasst, erscheint der Hinweis **„Noch keine Farmen registriert"** mit der Schaltfläche **„Farm registrieren"** – diese führt direkt in [Workflow A](#4-workflow-a-farmlandwirt-registrieren).
- Die gewählte Farm steht danach oben in der Kopfzeile; über das ✏️-Symbol lässt sie sich wechseln (**„Farm ändern"**).

> 📷 **Screenshot 11** – Farm-Auswahl vor Beginn der Aufzeichnung.
>
> ![Farm-Auswahl](screenshots/registrar-11-farmauswahl.png)

### 5.2 Angefangene Aufzeichnungen

Gibt es **unfertige Feldaufzeichnungen**, fragt die App beim Start: **„Fortsetzen oder neu starten?"** – entweder die begonnene Fläche weiter ablaufen oder **„Neues Feld beginnen"**.

### 5.3 Grenze ablaufen

Die Feldgrenze wird Punkt für Punkt abgegangen:

| Bedienelement | Funktion |
|---|---|
| **Punkt hinzufügen** | Aktuelle GPS-Position als Eckpunkt übernehmen |
| Punktliste / Karte | Zeigt die gesetzten Punkte und die aufgespannte Fläche |
| Punkt antippen → **Punkt löschen** | Einzelnen Fehlpunkt entfernen (mit Rückfrage) |
| **Polygon löschen** | Aufzeichnung komplett zurücksetzen |
| Genauigkeitsanzeige | Aktuelle GPS-Genauigkeit in Metern |

Regeln beim Setzen der Punkte:

- **Mindestens 3 Punkte** sind erforderlich – sonst „Mindestens 3 Punkte erforderlich".
- Zwei Punkte müssen **mindestens 5 m** auseinanderliegen – sonst „Punkt zu nahe am vorherigen Punkt".
- Vor dem Speichern fragt die App, ob das Polygon **automatisch geschlossen** werden soll (letzter Punkt zurück zum ersten). Die berechnete Fläche wird angezeigt.
- Bei schlechter GPS-Genauigkeit (rote Anzeige) besser einen Moment warten, bis das Signal stabiler ist.

> 📷 **Screenshot 12** – Aufzeichnung läuft: Karte mit gesetzten Punkten, Punktzähler und Genauigkeitsanzeige.
>
> ![Feldgrenze aufzeichnen](screenshots/registrar-12-polygon.png)

### 5.4 Feld-Foto (Pflicht)

Über das Kamera-Symbol in der Kopfzeile wird das **Feld-Foto** aufgenommen. Das Symbol trägt eine farbige Markierung:

| Markierung | Bedeutung |
|---|---|
| 🟠 Warnzeichen | Foto fehlt noch |
| 🟢 Haken | Foto vorhanden und gültig |
| 🔴 Kreuz | Foto ungültig – es wurde **außerhalb des Polygons** aufgenommen |

Das Foto muss **innerhalb der aufgezeichneten Fläche** entstehen (Toleranz 50 m); es dient als Nachweis, dass der Registrar tatsächlich vor Ort war.

> 📷 **Screenshot 13** – Feld-Foto-Dialog mit gültigem (grünem) Status.
>
> ![Feld-Foto](screenshots/registrar-13-feldfoto.png)

### 5.5 Speichern

**„Feld registrieren"** legt das Feld an und verknüpft es mit der gewählten Farm. Auch dieses Feld startet im Status **Ausstehend**. Alternativ kann die Aufzeichnung mit **„Verlassen und speichern"** unterbrochen und später fortgesetzt werden.

---

## 6. Verlauf: erfasste Daten prüfen und nachbearbeiten

**Dashboard → „Verlauf anzeigen"** öffnet die vollständige Registrierungshistorie dieses Geräts.

Möglichkeiten:

- **Filtern** nach *Alle / Landwirte / Farmen / Felder* und **Suchen** nach Namen
- **Status** jedes Eintrags einsehen (verifiziert / ausstehend / abgelehnt) samt Registrierungsdatum
- **Eintrag bearbeiten**: Stammdaten korrigieren, Ausweis- bzw. Einverständnis-Foto neu aufnehmen
- **Farm zu einem Landwirt hinzufügen** (ein Landwirt kann mehrere Farmen haben)
- **Feld zu einer Farm hinzufügen** (eine Farm kann mehrere Felder haben)
- Fläche und Kartenausschnitt eines Feldes ansehen

> 📷 **Screenshot 14** – Verlauf mit Filterleiste und mehreren Einträgen unterschiedlichen Status.
>
> ![Verlauf](screenshots/registrar-14-verlauf.png)

> 📷 **Screenshot 15** – Detail-/Bearbeitungsansicht eines Eintrags.
>
> ![Eintrag bearbeiten](screenshots/registrar-15-eintrag-bearbeiten.png)

---

## 7. Offline arbeiten und Daten hochladen

### 7.1 Grundprinzip

Die Erfassung funktioniert **vollständig ohne Internet**. Jeder Datensatz wird sofort lokal gespeichert und in eine Warteschlange für den Upload gestellt. Sobald das Gerät online ist, wird die Warteschlange abgearbeitet:

- automatisch etwa **alle 10 Minuten**, solange das Dashboard geöffnet und der Upload nicht pausiert ist,
- oder sofort über **„Jetzt synchronisieren"** im Sync-Panel.

### 7.2 Das Sync-Panel

Erreichbar über den **Upload-Chip im Statusstreifen** oder über *Werkzeuge & Einstellungen*.

| Element | Bedeutung |
|---|---|
| **Upload pausieren** (Schalter) | Aus = „Upload aktiv". Ein = „Upload pausiert – Daten werden nur lokal gespeichert" |
| Liste der offenen Objekte | Was genau noch wartet, mit Typ und Grund |
| Letzte erfolgreiche Synchronisierung | Uhrzeit bzw. Datum |
| Nächster Wiederholungsversuch / Letzter Fehler | Erscheint nur, wenn ein Upload hängt |
| **Jetzt synchronisieren** | Startet den Upload sofort |

> 📷 **Screenshot 16** – Sync-Panel mit Pausieren-Schalter und Liste der offenen Uploads.
>
> ![Sync-Panel](screenshots/registrar-16-sync-panel.png)

### 7.3 Wann sollte man den Upload pausieren?

In abgelegenen Gebieten mit **sehr schwacher Mobilfunkverbindung** blockieren große Fotos den Upload und bremsen die Arbeit aus. In diesem Fall:

1. **Upload pausieren** einschalten,
2. den Tag über normal weiter erfassen (alles wird lokal gesichert),
3. abends bei guter Verbindung (z. B. WLAN im Büro) den Schalter wieder ausschalten und **„Jetzt synchronisieren"** antippen.

> ⚠️ Solange pausiert ist, liegen die Daten **nur auf dem Gerät**. Erst nach erfolgreichem Upload sind sie gesichert – Gerät nicht zurücksetzen und App nicht deinstallieren, solange offene Uploads angezeigt werden.

---

## 8. Werkzeuge & Einstellungen

Der eingeklappte Bereich am Ende des Dashboards enthält:

| Einstellung | Bedeutung |
|---|---|
| **Flächeneinheit** | Einheit für die Anzeige der Feldgröße. Die Schaltfläche rechts schaltet zwischen den für das Land gültigen Einheiten um. |
| **Sync-Bereich** | Dasselbe Panel wie in [Kapitel 7](#72-das-sync-panel): Upload pausieren, offene Objekte, letzter Sync, jetzt synchronisieren. |

> 📷 **Screenshot 17** – Ausgeklappter Bereich „Werkzeuge & Einstellungen".
>
> ![Werkzeuge und Einstellungen](screenshots/registrar-17-werkzeuge.png)

> ℹ️ **Hinweis zum IHCafé-Produzentenverzeichnis:** Das Verzeichnis wird bewusst **nicht** auf die Registrar-Geräte geladen – der vollständige Datensatz ist mehrere Megabyte groß. Es steht ausschließlich dem **Registrar Coordinator in der QC-Ansicht (Webapp)** zur Verfügung; die Zuordnung eines Datensatzes zu einem IHCafé-Produzenten erfolgt dort.

---

## 9. Was nach dem Upload passiert (Qualitätskontrolle)

1. Der Registrar erfasst die Daten → Status **Ausstehend**.
2. Die Daten werden in die Cloud übertragen.
3. Der **Registrar Coordinator** prüft sie in der QC-Ansicht: Fotos, Lage, Plausibilität der Angaben, ggf. Abgleich mit dem IHCafé-Produzentenverzeichnis.
4. Ergebnis:
   - **Verifiziert** – der Datensatz ist freigegeben und zählt auf dem Dashboard unter „Verifiziert".
   - **Abgelehnt** – der Datensatz erscheint im Verlauf als abgelehnt und muss nachgebessert werden.

Deshalb gilt: **Fotos scharf und vollständig aufnehmen** und Namen sorgfältig schreiben – jede Nachbesserung bedeutet einen zweiten Besuch beim Landwirt.

---

## 10. Meldungen und häufige Fragen

| Meldung / Situation | Ursache | Lösung |
|---|---|---|
| „GPS muss für Registrierung aktiviert sein" | Standortdienst aus oder keine Freigabe | GPS im Gerät aktivieren, Standortfreigabe für die App erteilen, dann erneut starten |
| Ausweis-Foto / Einverständnis-Foto verlangt | Pflichtfoto fehlt | Foto aufnehmen; erst danach lässt sich weiterblättern |
| „Mindestens 3 Punkte erforderlich" | Polygon hat zu wenige Eckpunkte | Weitere Punkte entlang der Feldgrenze setzen |
| „Punkt zu nahe am vorherigen Punkt (mind. 5 m)" | Zwei Punkte liegen zu dicht beieinander | Ein Stück weitergehen und erst dann den nächsten Punkt setzen |
| Feld-Foto rot markiert | Foto wurde außerhalb des Polygons aufgenommen | Innerhalb der aufgezeichneten Fläche stehen und Foto neu aufnehmen (Toleranz 50 m) |
| „Feld muss mit einer Farm verknüpft sein" | Keine Farm ausgewählt | Farm auswählen bzw. zuerst eine Farm registrieren |
| „Noch keine Farmen registriert" | Zu dieser Farm existiert noch kein Datensatz | Über **„Farm registrieren"** zunächst Landwirt und Farm anlegen |
| Chip zeigt dauerhaft „*N* offen" | Keine Verbindung, Upload pausiert oder Upload-Fehler | Sync-Panel öffnen: Pausieren ausschalten, Verbindung prüfen, Fehlermeldung lesen, **„Jetzt synchronisieren"** |
| Zahlen auf dem Dashboard wirken zu niedrig | Die Zahlen zeigen nur die Datensätze **dieses Geräts** | Ist normal; die Gesamtübersicht hat der Registrar Coordinator |
| Statt des Namens erscheint die E-Mail-Adresse | Im Profil fehlen Vor-/Nachname | Über das Profil-Symbol Name ergänzen und speichern |

---

## 11. Übersicht der Screenshots

Alle Bilder unter `docs/screenshots/` ablegen. Empfohlen: Hochformat, Gerätebreite ≥ 1080 px, PNG. Die deutsche, englische und spanische Fassung verweisen auf **dieselben** Dateinamen – ein Screenshot-Satz genügt für alle drei; alternativ je Sprache ein eigener Satz in Unterordnern samt angepasster Pfade.

| Nr. | Dateiname | Motiv |
|---|---|---|
| 01 | `registrar-01-dashboard.png` | Gesamtes Dashboard nach dem Login |
| 02 | `registrar-02-profil.png` | Dialog „Profil bearbeiten" |
| 03 | `registrar-03-statusstreifen.png` | Statusstreifen (GPS / Online / Uploads), möglichst mit offenen Uploads |
| 04 | `registrar-04-gps-hinweis.png` | Dialog „GPS muss für Registrierung aktiviert sein" |
| 05 | `registrar-05-tagesleistung.png` | Tageskarte mit Zahlen und „Verlauf anzeigen" |
| 06 | `registrar-06-stepper-uebersicht.png` | Registrierungs-Stepper, drei Schritte sichtbar |
| 07 | `registrar-07-landwirt.png` | Schritt 1 mit Ausweis-Foto (grüner Rahmen) |
| 08 | `registrar-08-einverstaendnis.png` | Schritt 2 mit fotografierter Einverständniserklärung |
| 09 | `registrar-09-farm.png` | Schritt 3 mit Fläche und Einheiten-Auswahl |
| 10 | `registrar-10-abschluss.png` | Fortschritts-Overlay bzw. Erfolgsmeldung |
| 11 | `registrar-11-farmauswahl.png` | Farm-Auswahl im Feldgrenzen-Recorder |
| 12 | `registrar-12-polygon.png` | Laufende Polygon-Aufzeichnung mit Punkten |
| 13 | `registrar-13-feldfoto.png` | Feld-Foto-Dialog, Status gültig |
| 14 | `registrar-14-verlauf.png` | Verlauf mit Filtern und Einträgen |
| 15 | `registrar-15-eintrag-bearbeiten.png` | Detail-/Bearbeitungsansicht eines Eintrags |
| 16 | `registrar-16-sync-panel.png` | Sync-Panel mit Pausieren-Schalter |
| 17 | `registrar-17-werkzeuge.png` | Ausgeklappter Bereich „Werkzeuge & Einstellungen" |

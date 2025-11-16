// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Lebensmittelketten verfolgen';

  @override
  String get traceTheFoodchain => 'Verfolge die Lebensmittelkette';

  @override
  String get selectRole => 'Bitte wähle deine Rolle!';

  @override
  String welcomeMessage(String role) {
    return 'Willkommen, $role!';
  }

  @override
  String get actions => 'Aktionen';

  @override
  String get storage => 'Lager';

  @override
  String get settings => 'Einstellungen';

  @override
  String get farmerActions => 'Landwirt-Aktionen';

  @override
  String get farmManagerActions => 'Hofmanager-Aktionen';

  @override
  String get traderActions => 'Händler-Aktionen';

  @override
  String get transporterActions => 'Transporteur-Aktionen';

  @override
  String get sellerActions => 'Verkäufer-Aktionen';

  @override
  String get buyerActions => 'Käufer-Aktionen';

  @override
  String get identifyYourselfOnline => 'Identifiziere dich';

  @override
  String get startHarvestOffline => 'Ernte starten';

  @override
  String get waitingForData => 'Warte auf Daten...';

  @override
  String get handOverHarvestToTrader => 'Übergebe Ernte an Händler';

  @override
  String get scanQrCodeOrNfcTag => 'QR-Code oder NFC-Tag scannen';

  @override
  String get startNewHarvest => 'Neue Ernte';

  @override
  String get scanTraderTag => 'Händler-Tag scannen!';

  @override
  String get scanFarmerTag => 'Landwirt-Tag scannen!';

  @override
  String get unit => 'Einheit';

  @override
  String get changeRole => 'Rolle ändern';

  @override
  String get inTransit => 'in Transit';

  @override
  String get delivered => 'geliefert';

  @override
  String get completed => 'abgeschlossen';

  @override
  String get statusUpdatedSuccessfully => 'erfolgreich aktualisiert';

  @override
  String get noRole => 'Keine Rolle';

  @override
  String get roleFarmer => 'Landwirt';

  @override
  String get roleFarmManager => 'Hofmanager';

  @override
  String get roleTrader => 'Händler';

  @override
  String get roleTransporter => 'Transporteur';

  @override
  String get roleProcessor => 'Verarbeiter';

  @override
  String get roleImporter => 'EU-Importeur';

  @override
  String get activeImports => 'Aktuelle Importe';

  @override
  String get noActiveImports => 'Keine aktuellen Importe';

  @override
  String get noActiveItems => 'Keine Lagerbestände gefunden';

  @override
  String get noImportHistory => 'Keine Importe im Verlauf';

  @override
  String get importHistory => 'Import Verlauf';

  @override
  String get roleSeller => 'Verkäufer';

  @override
  String get roleBuyer => 'Käufer';

  @override
  String get roleSystemAdministrator => 'System Administrator';

  @override
  String get roleDiascaAdmin => 'Diasca-Administrator';

  @override
  String get roleSuperAdmin => 'Super Administrator';

  @override
  String get roleTfcAdmin => 'TFC Administrator';

  @override
  String get roleRegistrarCoordinator => 'Registrar Koordinator';

  @override
  String get roleVerificationAuthority => 'Verifizierungsbehörde';

  @override
  String get roleAssignedSuccessfully => 'Rolle erfolgreich zugewiesen';

  @override
  String get errorAssigningRole => 'Fehler beim Zuweisen der Rolle';

  @override
  String get userManagement => 'Benutzerverwaltung';

  @override
  String get userManagementSubtitle => 'Benutzerrollen verwalten und zuweisen';

  @override
  String get noPermissionForUserManagement =>
      'Keine Berechtigung für Benutzerverwaltung';

  @override
  String get userManagementOnlineOnly =>
      'Benutzerverwaltung ist nur online verfügbar';

  @override
  String get noUsersFound => 'Keine Benutzer gefunden';

  @override
  String get assignRole => 'Rolle zuweisen';

  @override
  String get currentRole => 'Aktuelle Rolle';

  @override
  String get newRole => 'Neue Rolle';

  @override
  String get reason => 'Grund';

  @override
  String get enterReasonForRoleChange => 'Grund für Rollenänderung eingeben';

  @override
  String get enterReason => 'Grund für Rollenänderung eingeben';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get assign => 'Zuweisen';

  @override
  String get userDetails => 'Benutzerdetails';

  @override
  String get name => 'Name';

  @override
  String get email => 'E-Mail';

  @override
  String get userID => 'Benutzer-ID';

  @override
  String get manageable => 'Verwaltbar';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get close => 'Schließen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get roleManagementDebugInfo => 'Rollenverwaltung Debug Info';

  @override
  String get firestoreError => 'Firestore Fehler';

  @override
  String get appUserDocRepairedSuccessfully =>
      'appUserDoc erfolgreich repariert';

  @override
  String get repairFailed => 'Reparatur fehlgeschlagen';

  @override
  String get repairAppUserDoc => 'appUserDoc reparieren';

  @override
  String get notManageable => 'Nicht verwaltbar';

  @override
  String get possibleReasons =>
      'Mögliche Gründe:\n• Keine verwaltbaren Benutzer gefunden\n• Filter zu restriktiv\n• Fehlende Berechtigungen';

  @override
  String get noAvailableRolesForPermission =>
      'Keine verfügbaren Rollen für Ihre Berechtigung';

  @override
  String usersCount(int filtered, int total) {
    return '$filtered von $total Benutzern';
  }

  @override
  String get showUserDetails => 'User-Details anzeigen';

  @override
  String get editRole => 'Rolle bearbeiten';

  @override
  String get superadminSecurityError =>
      'SICHERHEITSFEHLER: SUPERADMIN-Rollen können nicht geändert werden';

  @override
  String get superadminSecurityInfo =>
      'SUPERADMIN-Benutzer sind durch Sicherheitsrichtlinien geschützt';

  @override
  String get superadminCannotBeAssigned =>
      'SUPERADMIN-Rolle kann nicht zugewiesen werden';

  @override
  String get superadminCannotBeChanged =>
      'SUPERADMIN-Rolle kann nicht geändert werden';

  @override
  String get searchUsers => 'Benutzer suchen';

  @override
  String get filterByRole => 'Nach Rolle filtern';

  @override
  String get allRoles => 'Alle Rollen';

  @override
  String get roleSuccessfullyAssigned => 'Rolle erfolgreich zugewiesen';

  @override
  String get errorWhileAssigningRole => 'Fehler beim Zuweisen der Rolle';

  @override
  String get reasonForRoleChange => 'Grund für Rollenänderung';

  @override
  String get enterNewFarmerID => 'Geben Sie Ihre Landwirt-ID ein';

  @override
  String get enterNewFarmID => 'Geben Sie eine neue Betriebs-ID ein';

  @override
  String scannedCode(String code) {
    return 'Gescannter Code: $code';
  }

  @override
  String get confirm => 'Bestätigen';

  @override
  String get errorIncorrectData =>
      'FEHLER: Die empfangenen Daten sind ungültig!';

  @override
  String get provideValidSellerTag =>
      'Bitte geben Sie ein gültiges Verkäufer-Tag an.';

  @override
  String get confirmTransfer =>
      'Hat der Käufer die Informationen korrekt erhalten?';

  @override
  String get peerTransfer => 'Peer-Übertragung';

  @override
  String get generateTransferData => 'Übertragungsdaten generieren';

  @override
  String get startScanning => 'Scannen starten';

  @override
  String get stopScanning => 'Scannen stoppen';

  @override
  String get startPresenting => 'Präsentieren starten';

  @override
  String get stopPresenting => 'Präsentieren stoppen';

  @override
  String get transferDataGenerated => 'Übertragungsdaten generiert';

  @override
  String get dataReceived => 'Daten empfangen';

  @override
  String get ok => 'OK';

  @override
  String get feedbackEmailSubject => 'Feedback für die TraceFoodchain App';

  @override
  String get feedbackEmailBody => 'Bitte gib hier dein Feedback ein:';

  @override
  String get unableToLaunchEmail =>
      'E-Mail-Client konnte nicht geöffnet werden';

  @override
  String get activeItems => 'Aktive Artikel';

  @override
  String get pastItems => 'Vergangene Artikel';

  @override
  String get changeFarmerId => 'Landwirt-ID ändern';

  @override
  String get associateWithDifferentFarm => 'Mit anderem Hof verknüpfen';

  @override
  String get manageFarmEmployees => 'Hofmitarbeiter verwalten';

  @override
  String get manageHarvests => 'Ernten verwalten';

  @override
  String get manageContainers => 'Container verwalten';

  @override
  String get buyHarvest => 'Ernte kaufen';

  @override
  String get sellHarvest => 'Ernte verkaufen';

  @override
  String get manageInventory => 'Inventar verwalten';

  @override
  String get addEmployee => 'Mitarbeiter hinzufügen';

  @override
  String get editEmployee => 'Mitarbeiter bearbeiten';

  @override
  String get addHarvest => 'Ernte hinzufügen';

  @override
  String get harvestDetails => 'Erntedetails';

  @override
  String get addContainer => 'Container hinzufügen';

  @override
  String get containerQRCode => 'Container QR-Code';

  @override
  String get notImplementedYet => 'Diese Funktion ist noch nicht implementiert';

  @override
  String get add => 'Hinzufügen';

  @override
  String get save => 'Speichern';

  @override
  String get buy => 'Kaufen';

  @override
  String get sell => 'Verkaufen';

  @override
  String get invalidInput => 'Ungültige Eingabe. Bitte gib gültige Zahlen ein.';

  @override
  String get editInventoryItem => 'Inventarartikel bearbeiten';

  @override
  String get filterByCropType => 'Nach Erntetyp filtern';

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get cropType => 'Erntetyp';

  @override
  String get quantity => 'Menge';

  @override
  String get transactionHistory => 'Transaktionsverlauf';

  @override
  String get price => 'Preis';

  @override
  String get activeDeliveries => 'Aktive Lieferungen';

  @override
  String get deliveryHistory => 'Lieferverlauf';

  @override
  String get updateStatus => 'Status aktualisieren';

  @override
  String get updateDeliveryStatus => 'Lieferstatus aktualisieren';

  @override
  String get noDeliveryHistory => 'Kein Lieferverlauf';

  @override
  String get noActiveDeliveries => 'Keine aktiven Lieferungen';

  @override
  String get listProducts => 'Produkte auflisten';

  @override
  String get manageOrders => 'Bestellungen verwalten';

  @override
  String get salesHistory => 'Verkaufsverlauf';

  @override
  String get goToActions => 'Zu Aktionen gehen';

  @override
  String get setPrice => 'Preis festlegen';

  @override
  String get browseProducts => 'Produkte durchsuchen';

  @override
  String get orderHistory => 'Bestellverlauf';

  @override
  String get addToCart => 'Zum Warenkorb hinzufügen';

  @override
  String get noDataAvailable => 'Keine Daten verfügbar';

  @override
  String get total => 'Gesamt';

  @override
  String get syncData => 'Daten synchronisieren';

  @override
  String get startSync => 'Synchronisation starten';

  @override
  String get syncSuccess => 'Daten erfolgreich synchronisiert';

  @override
  String get syncError => 'Fehler bei der Datensynchronisation';

  @override
  String get nfcNotAvailable => 'NFC nicht verfügbar';

  @override
  String get scanningForNfcTags => 'Suche nach NFC Tags';

  @override
  String get nfcScanStopped => 'NFC Scan unterbrochen';

  @override
  String get qrCode => 'QR-Code';

  @override
  String get nfcTag => 'NFC-Tag';

  @override
  String get nfcScanError => 'Fehler beim NFC-Scan';

  @override
  String get multiTagFoundIOS => 'Mehrere Tags gefunden!';

  @override
  String get scanInfoMessageIOS => 'Scanne dein Tag';

  @override
  String get addEmptyItem => 'Leeren Gegenstand hinzufügen';

  @override
  String get maxCapacity => 'Maximale Kapazität';

  @override
  String get uid => 'UID';

  @override
  String get bag => 'Sack';

  @override
  String get container => 'Container';

  @override
  String get building => 'Gebäude';

  @override
  String get transportVehicle => 'Transportfahrzeug';

  @override
  String get pleaseCompleteAllFields => 'Bitte füllen Sie alle Felder aus';

  @override
  String get fieldRequired => 'Dieses Feld ist erforderlich';

  @override
  String get invalidNumber => 'Bitte geben Sie eine gültige Zahl ein';

  @override
  String get geolocation => 'Geolokalisierung';

  @override
  String get latitude => 'Breitengrad';

  @override
  String get longitude => 'Längengrad';

  @override
  String get useCurrentLocation => 'Aktuellen Standort verwenden';

  @override
  String get locationError => 'Fehler beim Abrufen des Standorts';

  @override
  String get invalidLatitude => 'Ungültiger Breitengrad';

  @override
  String get invalidLongitude => 'Ungültiger Längengrad';

  @override
  String get sellOnline => 'Online verkaufen';

  @override
  String get recipientEmail => 'E-Mail des Empfängers';

  @override
  String get invalidEmail => 'Ungültige E-Mail-Adresse';

  @override
  String get userNotFound => 'Benutzer nicht gefunden';

  @override
  String get saleCompleted => 'Verkauf erfolgreich abgeschlossen';

  @override
  String get saleError => 'Während des Verkaufs ist ein Fehler aufgetreten';

  @override
  String get newTransferNotificationTitle => 'Neue Übertragung';

  @override
  String get newTransferNotificationBody =>
      'Sie haben eine neue Artikelübertragung erhalten';

  @override
  String get coffee => 'Kaffee';

  @override
  String get amount2 => 'Menge';

  @override
  String speciesLabel(String species) {
    return 'Art: $species';
  }

  @override
  String amount(String value, String unit) {
    return '$value $unit';
  }

  @override
  String processingStep(String step) {
    return '$step';
  }

  @override
  String boughtOn(String date) {
    return 'Gekauft am: $date';
  }

  @override
  String fromPlot(String plotId) {
    return 'Von Parzelle: $plotId';
  }

  @override
  String get noPlotFound => 'Keine Parzelle gefunden';

  @override
  String errorWithParam(String error) {
    return 'Fehler: $error';
  }

  @override
  String get loadingData => 'Lade Daten...';

  @override
  String get pdfGenerationError => 'Fehler bei der PDF-Generierung';

  @override
  String containerIsEmpty(String containerType, String id) {
    return '$containerType $id ist leer';
  }

  @override
  String idWithBrackets(String id) {
    return '(ID: $id)';
  }

  @override
  String get buyCoffee => 'Kaffee kaufen';

  @override
  String get sellOffline => 'Offline verkaufen';

  @override
  String get changeProcessingState => 'Verarbeitungs-/Qualitätszustand ändern';

  @override
  String get changeLocation => 'Standort ändern';

  @override
  String get selectQualityCriteria => 'Qualitätskriterien auswählen';

  @override
  String get selectProcessingState => 'Verarbeitungszustand auswählen';

  @override
  String pdfError(String error) {
    return 'PDF-Fehler: $error';
  }

  @override
  String get errorSendingEmailWithError => 'Fehler beim E-Mail-Versand';

  @override
  String get signOut => 'Abmelden';

  @override
  String get resendEmail => 'E-Mail erneut senden!';

  @override
  String get waitingForEmailVerification =>
      'Warte auf E-Mail-Bestätigung. Bitte prüfen Sie Ihren Posteingang und bestätigen Sie Ihre E-Mail.';

  @override
  String get emailVerification => 'E-Mail-Bestätigung';

  @override
  String get securityError => 'Sicherheitsfehler';

  @override
  String get securityErrorMessage =>
      'Die Sicherheitseinstellungen für Digitale Unterschriften konnten nicht generiert werden. Bitte versuchen Sie es später erneut und stellen Sie sicher, dass Sie eine Internetverbindung haben.';

  @override
  String get closeApp => 'App schließen';

  @override
  String get uidAlreadyExists =>
      'Diese ID existiert bereits, bitte wählen Sie eine andere!';

  @override
  String get selectItemToSell =>
      'Bitte wählen Sie einen Artikel zum Verkaufen aus';

  @override
  String get debugDeleteContainer => 'Container löschen (Debug)';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get languageFrench => 'Französisch';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get generateDDS => 'DDS generieren';

  @override
  String get ddsGenerationDemo =>
      'DDS-Generierung ist nur im Demo-Modus verfügbar';

  @override
  String get sampleOperator => 'Beispiel-Betreiber';

  @override
  String get sampleAddress => 'Beispiel-Adresse';

  @override
  String get sampleEori => 'Beispiel-EORI';

  @override
  String get sampleHsCode => 'Beispiel-HS-Code';

  @override
  String get sampleDescription => 'Beispiel-Beschreibung';

  @override
  String get sampleTradeName => 'Beispiel-Handelsname';

  @override
  String get sampleScientificName => 'Beispiel-Wissenschaftlicher Name';

  @override
  String get sampleQuantity => 'Beispiel-Menge';

  @override
  String get sampleCountry => 'Beispiel-Land';

  @override
  String get sampleName => 'Beispiel-Name';

  @override
  String get sampleFunction => 'Beispiel-Funktion';

  @override
  String get scanQRCode => 'QR-Code scannen';

  @override
  String get errorLabel => 'Fehler';

  @override
  String get welcomeToApp => 'Willkommen bei TraceFoodChain';

  @override
  String get signInMessage =>
      'Bitte melden Sie sich an oder registrieren Sie sich, um die Sicherheit und Integrität unseres Lebensmittelketten-Tracking-Systems zu gewährleisten.';

  @override
  String get password => 'Passwort';

  @override
  String get pleaseEnterEmail => 'Bitte geben Sie Ihre E-Mail-Adresse ein';

  @override
  String get pleaseEnterPassword => 'Bitte geben Sie Ihr Passwort ein';

  @override
  String get signInSignUp => 'Anmelden / Registrieren';

  @override
  String get helpButtonTooltip => 'Hilfe öffnen';

  @override
  String get errorOpeningUrl => 'Hilfeseite konnte nicht geöffnet werden';

  @override
  String get weakPasswordError => 'Das eingegebene Passwort ist zu schwach.';

  @override
  String get emailAlreadyInUseError =>
      'Ein Konto mit dieser E-Mail existiert bereits.';

  @override
  String get invalidEmailError => 'Die E-Mail-Adresse ist ungültig.';

  @override
  String get userDisabledError => 'Dieser Benutzer wurde deaktiviert.';

  @override
  String get wrongPasswordError => 'Falsches Passwort für diesen Benutzer.';

  @override
  String get undefinedError => 'Ein unbekannter Fehler ist aufgetreten.';

  @override
  String get error => 'Fehler';

  @override
  String get aggregateItems => 'Artikel zusammenfassen';

  @override
  String get addNewEmptyItem => 'Neuen leeren Artikel hinzufügen';

  @override
  String get selectBuyCoffeeOption => 'Kaffee-Kaufoption wählen';

  @override
  String get selectSellCoffeeOption => 'Kaffee-Verkaufsoption wählen';

  @override
  String get deviceToCloud => 'Gerät-zu-Cloud';

  @override
  String get deviceToDevice => 'Gerät-zu-Gerät';

  @override
  String get ciatFirstSale => 'CIAT Erstverkauf';

  @override
  String get buyCoffeeDeviceToDevice => 'Kaffee kaufen (Gerät-zu-Gerät)';

  @override
  String get scanSelectFutureContainer => 'Zielbehälter scannen/auswählen';

  @override
  String get scanContainerInstructions =>
      'Verwenden Sie QR-Code/NFC oder wählen Sie manuell aus, wo der Kaffee gelagert werden soll.';

  @override
  String get presentInfoToSeller => 'Informationen dem Verkäufer präsentieren';

  @override
  String get presentInfoToSellerInstructions =>
      'Zeigen Sie dem Verkäufer den QR-Code oder NFC-Tag, um die Transaktion zu starten.';

  @override
  String get receiveDataFromSeller => 'Daten vom Verkäufer empfangen';

  @override
  String get receiveDataFromSellerInstructions =>
      'Scannen Sie den QR-Code oder NFC-Tag vom Gerät des Verkäufers, um die Transaktion abzuschließen.';

  @override
  String get present => 'PRÄSENTIEREN';

  @override
  String get receive => 'EMPFANGEN';

  @override
  String get back => 'ZURÜCK';

  @override
  String get next => 'WEITER';

  @override
  String get buyCoffeeCiatFirstSale => 'Kaffee kaufen (CIAT Erstverkauf)';

  @override
  String get scanSellerTag => 'Verkäufer-Tag scannen';

  @override
  String get scanSellerTagInstructions =>
      'Verwenden Sie QR-Code oder NFC vom Verkäufer, um den zu kaufenden Kaffee zu spezifizieren.';

  @override
  String get enterCoffeeInfo => 'Kaffee-Informationen eingeben';

  @override
  String get enterCoffeeInfoInstructions =>
      'Geben Sie Details zum gekauften Kaffee an.';

  @override
  String get scanReceivingContainer =>
      'Tag des Empfangsbehälters scannen (Sack, Lager, Gebäude, LKW...)';

  @override
  String get scanReceivingContainerInstructions =>
      'Geben Sie an, wohin der Kaffee transferiert wird.';

  @override
  String get coffeeInformation => 'Kaffee-Informationen';

  @override
  String get countryOfOrigin => 'Herkunftsland';

  @override
  String get selectCountry => 'Land auswählen';

  @override
  String get selectSpecies => 'Art auswählen';

  @override
  String get enterQuantity => 'Menge eingeben';

  @override
  String get start => 'START!';

  @override
  String get scan => 'SCANNEN!';

  @override
  String get species => 'Art';

  @override
  String get processingState => 'Verarbeitungsstatus';

  @override
  String get qualityReductionCriteria => 'Qualitätsminderungskriterien';

  @override
  String get sellCoffeeDeviceToDevice => 'Kaffee verkaufen (Gerät-zu-Gerät)';

  @override
  String get scanBuyerInfo =>
      'Vom Käufer bereitgestellte Informationen scannen';

  @override
  String get scanBuyerInfoInstructions =>
      'Verwenden Sie Ihre Smartphone-Kamera oder NFC, um die Ausgangsinformationen vom Käufer zu lesen';

  @override
  String get presentInfoToBuyer =>
      'Informationen dem Käufer präsentieren, um den Verkauf abzuschließen';

  @override
  String get presentInfoToBuyerInstructions =>
      'Geben Sie an, wohin der Kaffee transferiert wird.';

  @override
  String get selectFromDatabase => 'Aus Datenbank auswählen';

  @override
  String get notSynced => 'Nicht mit Cloud synchronisiert';

  @override
  String get synced => 'Mit Cloud synchronisiert';

  @override
  String get inbox => 'Posteingang';

  @override
  String get sendFeedback => 'Feedback senden';

  @override
  String get fillInReminder => 'Bitte füllen Sie alle Felder korrekt aus';

  @override
  String get manual => 'Manuelle Eingabe';

  @override
  String get selectCountryFirst => 'Bitte wählen Sie zuerst ein Land aus!';

  @override
  String get inputOfAdditionalInformation =>
      'Zusätzliche Informationen sind erforderlich!';

  @override
  String get provideValidContainer =>
      'Bitte geben Sie einen gültigen Tag für den Empfangsbehälter an.';

  @override
  String get buttonNext => 'WEITER';

  @override
  String get buttonScan => 'SCAN!';

  @override
  String get buttonStart => 'START!';

  @override
  String get buttonBack => 'ZURÜCK';

  @override
  String get locationPermissionsDenied =>
      'Standortberechtigungen sind verweigert';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'Standortberechtigungen sind dauerhaft verweigert';

  @override
  String get errorSyncToCloud =>
      'Fehler beim Synchronisieren der Daten mit der Cloud';

  @override
  String get errorBadRequest => 'Serverfehler: Ungültige Anfrage';

  @override
  String get errorMergeConflict =>
      'Serverfehler: Merge-Konflikt - Daten existieren in unterschiedlichen Versionen';

  @override
  String get errorServiceUnavailable => 'Serverfehler: Dienst nicht verfügbar';

  @override
  String get errorUnauthorized => 'Serverfehler: Nicht autorisiert';

  @override
  String get errorForbidden => 'Serverfehler: Verboten';

  @override
  String get errorNotFound => 'Serverfehler: Nicht gefunden';

  @override
  String get errorInternalServerError => 'Serverfehler: Interner Serverfehler';

  @override
  String get errorGatewayTimeout => 'Serverfehler: Gateway-Timeout';

  @override
  String get errorUnknown => 'Unbekannter Fehler';

  @override
  String get errorNoCloudConnectionProperties =>
      'Keine Cloud-Verbindungsdaten gefunden';

  @override
  String get syncToCloudSuccessful =>
      'Synchronisierung mit der Cloud erfolgreich';

  @override
  String get testModeActive => 'Testmodus aktiv';

  @override
  String get dataMode => 'Datenmodus';

  @override
  String get testMode => 'Testmodus';

  @override
  String get realMode => 'Produktionsmodus';

  @override
  String get nologoutpossible =>
      'Abmelden ist nur möglich, wenn eine Internetverbindung besteht';

  @override
  String get manuallySyncingWith => 'Synchronisiere manuell mit';

  @override
  String get syncingWith => 'Synchronisiere mit';

  @override
  String get newKeypairNeeded =>
      'Kein privater Schlüssel gefunden - Erzeuge neues Schlüsselpaar...';

  @override
  String get failedToInitializeKeyManagement =>
      'WARNUNG: Fehler bei der Initialisierung der Schlüsselverwaltung!';

  @override
  String get newUserProfileNeeded =>
      'Kein Benutzerprofil in der lokalen Datenbank gefunden - erstelle ein neues Profil...';

  @override
  String get coffeeIsBought => 'Kaffee wird gekauft';

  @override
  String get coffeeIsSold => 'Kaffee wird verkauft';

  @override
  String get generatingItem => 'Artikel wird generiert...';

  @override
  String get processing => 'Daten werden verarbeitet...';

  @override
  String get setItemName => 'Namen festlegen';

  @override
  String get unnamedObject => 'Unbenanntes Objekt';

  @override
  String get capacity => 'Kapazität';

  @override
  String get freeCapacity => 'Freie Kapazität';

  @override
  String get selectContainerForItems =>
      'Bitte wählen Sie Behälter\nfür die Artikel aus';

  @override
  String get selectContainer => 'Behälter auswählen';

  @override
  String get enterUIDhere => 'UID hier eingeben';

  @override
  String get excelFileDownloaded => 'Excel-Datei heruntergeladen';

  @override
  String get excelFileSavedAt => 'Excel-Datei gespeichert unter';

  @override
  String get failedToGenerateExcelFile =>
      'Fehler beim Generieren der Excel-Datei';

  @override
  String get exportToExcel => 'Exportieren nach Excel';

  @override
  String get resetPasswordEmailSent => 'Passwort zurücksetzen E-Mail gesendet';

  @override
  String get forgotPasswordQuestion => 'Passwort vergessen?';

  @override
  String get weightEquivalentGreenBeanKg => 'Äquivalent in grünen Bohnen (kg)';

  @override
  String get login => 'Anmelden';

  @override
  String get pleaseEnterEmailAndPassword =>
      'Bitte E-Mail und Passwort eingeben';

  @override
  String get loggingIn => 'Anmeldung läuft...';

  @override
  String get loginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get gettingAuthorityToken => 'Authority Token wird abgerufen...';

  @override
  String get fieldRegistry => 'Feld-Registry';

  @override
  String get fieldRegistryTitle => 'Registrierte Felder';

  @override
  String get fieldName => 'Feldname';

  @override
  String get geoId => 'Geo-ID';

  @override
  String get area => 'Fläche';

  @override
  String get registerNewFields => 'Neue Felder registrieren';

  @override
  String get uploadCsv => 'CSV hochladen';

  @override
  String get selectCsvFile => 'CSV-Datei auswählen';

  @override
  String get csvUploadSuccess => 'CSV erfolgreich hochgeladen';

  @override
  String get csvUploadError => 'Fehler beim CSV-Upload';

  @override
  String get registering => 'Registriere...';

  @override
  String get registrationComplete => 'Registrierung abgeschlossen';

  @override
  String get registrationError => 'Fehler bei der Registrierung';

  @override
  String get fieldAlreadyExists => 'Feld bereits vorhanden';

  @override
  String get noFieldsRegistered => 'Keine Felder registriert';

  @override
  String get csvFormatInfo => 'CSV-Format: Name, Beschreibung, Koordinaten';

  @override
  String get invalidCsvFormat => 'Ungültiges CSV-Format';

  @override
  String get fieldRegisteredSuccessfully => 'Feld erfolgreich registriert';

  @override
  String get progressStep1InitializingServices =>
      'Schritt 1: Initialisiere Services...';

  @override
  String get progressStep1UserRegistryLogin =>
      'Schritt 1: Anmeldung bei User Registry...';

  @override
  String get progressStep2RegisteringField =>
      'Schritt 2: Registriere Feld bei Asset Registry...';

  @override
  String get progressStep2FieldRegisteredSuccessfully =>
      'Schritt 2: Feld erfolgreich registriert, extrahiere GeoID...';

  @override
  String get progressStep2FieldAlreadyExists =>
      'Schritt 2: Feld existiert bereits, extrahiere GeoID...';

  @override
  String progressStep3CheckingCentralDatabase(String geoId) {
    return 'Schritt 3: Prüfe zentrale Datenbank (GeoID: $geoId)...';
  }

  @override
  String get progressStep3FieldNotFoundInCentralDb =>
      'Schritt 3: Feld nicht in zentraler Datenbank gefunden - lokale Registrierung...';

  @override
  String get processingCsvFile => 'CSV-Datei wird verarbeitet...';

  @override
  String get fieldRegistrationInProgress => 'Feldregistrierung läuft...';

  @override
  String fieldXOfTotal(String current, String total) {
    return 'Feld $current von $total';
  }

  @override
  String currentField(String fieldName) {
    return 'Aktuelles Feld: $fieldName';
  }

  @override
  String fieldRegistrationSuccessMessage(String fieldName) {
    return '✅ Feld \"$fieldName\" erfolgreich registriert!';
  }

  @override
  String fieldRegistrationErrorMessage(String fieldName, String error) {
    return '❌ Fehler bei \"$fieldName\": $error';
  }

  @override
  String fieldAlreadyExistsGeoIdExtracted(String geoId) {
    return '✅ Feld existiert bereits - GeoID erfolgreich extrahiert: $geoId';
  }

  @override
  String fieldAlreadyExistsGeoIdFailed(String error) {
    return '⚠️ Feld existiert bereits - Fehler beim Extrahieren der GeoID: $error';
  }

  @override
  String fieldRegistrationNewGeoIdExtracted(String geoId) {
    return '✅ Neues Feld registriert - GeoID erfolgreich extrahiert: $geoId';
  }

  @override
  String fieldRegistrationNewGeoIdFailed(String error) {
    return '⚠️ Neues Feld registriert - Fehler beim Extrahieren der GeoID: $error';
  }

  @override
  String get csvProcessingComplete => 'CSV-Verarbeitung abgeschlossen';

  @override
  String get fieldsSuccessfullyRegistered => 'Felder erfolgreich registriert';

  @override
  String get fieldsAlreadyExisted => 'Felder existierten bereits';

  @override
  String get fieldsWithErrors => 'Felder mit Fehlern';

  @override
  String get unnamedField => 'Unbenanntes Feld';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get today => 'Heute';

  @override
  String get yesterday => 'Gestern';

  @override
  String daysAgo(String days) {
    return 'vor $days Tagen';
  }

  @override
  String weeksAgo(String weeks, String plural) {
    return 'vor $weeks Woche$plural';
  }

  @override
  String monthsAgo(String months, String plural) {
    return 'vor $months Monat$plural';
  }

  @override
  String yearsAgo(String years, String plural) {
    return 'vor $years Jahr$plural';
  }

  @override
  String get allFields => 'Alle Felder';

  @override
  String get registeredToday => 'Heute registriert';

  @override
  String get lastWeek => 'Letzte Woche';

  @override
  String get lastMonth => 'Letzter Monat';

  @override
  String get lastYear => 'Letztes Jahr';

  @override
  String get filterByRegistrationDate => 'Nach Registrierungsdatum filtern';

  @override
  String get registrationErrors => 'Registrierungsfehler';

  @override
  String get noFieldsForSelectedTimeframe =>
      'Keine Felder für den gewählten Zeitraum';

  @override
  String registeredOn(String date) {
    return 'Registriert: $date';
  }

  @override
  String fieldsCountSorted(String count, String total, String totalSingular) {
    String _temp0 = intl.Intl.selectLogic(
      totalSingular,
      {
        '1': 'Feld',
        'other': 'Felder',
      },
    );
    return '$count von $total $_temp0 (nach Datum sortiert)';
  }

  @override
  String csvLineError(String line, String error) {
    return 'Zeile $line: $error';
  }

  @override
  String csvLineNameCoordinatesRequired(String line) {
    return 'Zeile $line: Name und Koordinaten sind erforderlich';
  }

  @override
  String csvLineRegistrationError(String line, String error) {
    return 'Zeile $line: Registrierungsfehler - $error';
  }

  @override
  String get registeredOnLabel => 'Registriert am';

  @override
  String get specificDateLabel => 'Spezifisches Datum';

  @override
  String get archiveContainer => 'Container archivieren';

  @override
  String get containerSuccessfullyArchived =>
      'Container wurde erfolgreich archiviert.';

  @override
  String get showArchivedContainers => 'Zeige auch archivierte Container';

  @override
  String get archivedContainersVisible =>
      'Archivierte Container werden angezeigt';

  @override
  String get archivedContainersHidden =>
      'Archivierte Container sind ausgeblendet';

  @override
  String get searchContainers => 'Container suchen...';

  @override
  String get sort => 'Sortieren';

  @override
  String get sortByNameAsc => 'Name (A-Z)';

  @override
  String get sortByNameDesc => 'Name (Z-A)';

  @override
  String get sortByIdAsc => 'ID (aufsteigend)';

  @override
  String get sortByIdDesc => 'ID (absteigend)';

  @override
  String get sortByDateAsc => 'Datum (älteste zuerst)';

  @override
  String get sortByDateDesc => 'Datum (neueste zuerst)';

  @override
  String noSearchResults(Object searchTerm) {
    return 'Keine Container gefunden für \"$searchTerm\"';
  }
}

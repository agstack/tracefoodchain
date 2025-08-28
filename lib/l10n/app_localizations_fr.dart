// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Tracer les Chaînes Alimentaires';

  @override
  String get traceTheFoodchain => 'Tracer la Chaîne Alimentaire';

  @override
  String get selectRole => 'Veuillez sélectionner votre rôle !';

  @override
  String welcomeMessage(String role) {
    return 'Bienvenue, $role !';
  }

  @override
  String get actions => 'Actions';

  @override
  String get storage => 'Stockage';

  @override
  String get settings => 'Paramètres';

  @override
  String get farmerActions => 'Actions de l\'\'Agriculteur';

  @override
  String get farmManagerActions => 'Actions du Gestionnaire de Ferme';

  @override
  String get traderActions => 'Actions du Négociant';

  @override
  String get transporterActions => 'Actions du Transporteur';

  @override
  String get sellerActions => 'Actions du Vendeur';

  @override
  String get buyerActions => 'Actions de l\'\'Acheteur';

  @override
  String get identifyYourselfOnline => 'Identifiez-vous';

  @override
  String get startHarvestOffline => 'Commencer la Récolte';

  @override
  String get waitingForData => 'En Attente de Données...';

  @override
  String get handOverHarvestToTrader => 'Remettre la Récolte au Négociant';

  @override
  String get scanQrCodeOrNfcTag => 'Scannez le Code QR ou l\'\'Étiquette NFC';

  @override
  String get startNewHarvest => 'Nouvelle Récolte';

  @override
  String get scanTraderTag => 'Scannez l\'\'étiquette du négociant !';

  @override
  String get scanFarmerTag => 'Scannez l\'étiquette de l\'agriculteur !';

  @override
  String get unit => 'unité';

  @override
  String get changeRole => 'changer de rôle';

  @override
  String get inTransit => 'en transit';

  @override
  String get delivered => 'livré';

  @override
  String get completed => 'terminé';

  @override
  String get statusUpdatedSuccessfully => 'mis à jour avec succès';

  @override
  String get noRole => '-pas de rôle-';

  @override
  String get roleFarmer => 'Agriculteur';

  @override
  String get roleFarmManager => 'Gestionnaire de Ferme';

  @override
  String get roleTrader => 'Négociant';

  @override
  String get roleTransporter => 'Transporteur';

  @override
  String get roleProcessor => 'Transformateur de café';

  @override
  String get roleImporter => 'Importateur de l\'\'UE';

  @override
  String get activeImports => 'Importations en cours';

  @override
  String get noActiveImports => 'Aucune importation en cours';

  @override
  String get noActiveItems => 'Aucun stock trouvé';

  @override
  String get noImportHistory => 'Aucun historique d\'\'importation';

  @override
  String get importHistory => 'Historique des importations';

  @override
  String get roleSeller => 'Vendeur';

  @override
  String get roleBuyer => 'Acheteur';

  @override
  String get roleSystemAdministrator => 'Administrateur Système';

  @override
  String get roleDiascaAdmin => 'Administrateur Diasca';

  @override
  String get roleVerificationAuthority => 'Autorité de Vérification';

  @override
  String get enterNewFarmerID => 'Entrez un nouvel identifiant de ferme';

  @override
  String get enterNewFarmID => 'Entrez un nouvel identifiant d\'\'agriculteur';

  @override
  String scannedCode(String code) {
    return 'Code Scanné : $code';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get errorIncorrectData =>
      'ERREUR : Les données reçues ne sont pas valides !';

  @override
  String get provideValidSellerTag =>
      'Veuillez fournir une étiquette de vendeur valide.';

  @override
  String get confirmTransfer =>
      'L\'acheteur a-t-il reçu correctement les informations ?';

  @override
  String get peerTransfer => 'Transfert entre Pairs';

  @override
  String get generateTransferData => 'Générer les Données de Transfert';

  @override
  String get startScanning => 'Commencer le Scan';

  @override
  String get stopScanning => 'Arrêter le Scan';

  @override
  String get startPresenting => 'Commencer la Présentation';

  @override
  String get stopPresenting => 'Arrêter la Présentation';

  @override
  String get transferDataGenerated => 'Données de Transfert Générées';

  @override
  String get dataReceived => 'Données Reçues';

  @override
  String get ok => 'OK';

  @override
  String get feedbackEmailSubject =>
      'Retour d\'expérience pour l\'App TraceFoodchain';

  @override
  String get feedbackEmailBody => 'Veuillez saisir votre retour ici :';

  @override
  String get unableToLaunchEmail =>
      'Impossible d\'\'ouvrir le client de messagerie';

  @override
  String get activeItems => 'Articles Actifs';

  @override
  String get pastItems => 'Articles Passés';

  @override
  String get changeFarmerId => 'Changer l\'ID de l\'Agriculteur';

  @override
  String get associateWithDifferentFarm => 'Associer à une Autre Ferme';

  @override
  String get manageFarmEmployees => 'Gérer les Employés de la Ferme';

  @override
  String get manageHarvests => 'Gérer les Récoltes';

  @override
  String get manageContainers => 'Gérer les Conteneurs';

  @override
  String get buyHarvest => 'Acheter la Récolte';

  @override
  String get sellHarvest => 'Vendre la Récolte';

  @override
  String get manageInventory => 'Gérer l\'\'Inventaire';

  @override
  String get addEmployee => 'Ajouter un Employé';

  @override
  String get editEmployee => 'Modifier un Employé';

  @override
  String get addHarvest => 'Ajouter une Récolte';

  @override
  String get harvestDetails => 'Détails de la Récolte';

  @override
  String get addContainer => 'Ajouter un Conteneur';

  @override
  String get containerQRCode => 'Code QR du Conteneur';

  @override
  String get notImplementedYet =>
      'Cette fonctionnalité n\'\'est pas encore implémentée';

  @override
  String get add => 'Ajouter';

  @override
  String get save => 'Enregistrer';

  @override
  String get buy => 'Acheter';

  @override
  String get sell => 'Vendre';

  @override
  String get invalidInput =>
      'Saisie invalide. Veuillez entrer des nombres valides.';

  @override
  String get editInventoryItem => 'Modifier l\'Article d\'Inventaire';

  @override
  String get filterByCropType => 'Filtrer par type de culture';

  @override
  String get sortBy => 'Trier par';

  @override
  String get cropType => 'Type de Culture';

  @override
  String get quantity => 'Quantité';

  @override
  String get transactionHistory => 'Historique des Transactions';

  @override
  String get price => 'Prix';

  @override
  String get activeDeliveries => 'Livraisons Actives';

  @override
  String get deliveryHistory => 'Historique des Livraisons';

  @override
  String get updateStatus => 'Mettre à Jour le Statut';

  @override
  String get updateDeliveryStatus => 'Mettre à Jour le Statut de Livraison';

  @override
  String get noDeliveryHistory => 'Aucun historique de livraison';

  @override
  String get noActiveDeliveries => 'Aucune livraison active';

  @override
  String get listProducts => 'Lister les Produits';

  @override
  String get manageOrders => 'Gérer les Commandes';

  @override
  String get salesHistory => 'Historique des Ventes';

  @override
  String get goToActions => 'Aller aux Actions';

  @override
  String get setPrice => 'Définir le Prix';

  @override
  String get browseProducts => 'Parcourir les Produits';

  @override
  String get orderHistory => 'Historique des Commandes';

  @override
  String get addToCart => 'Ajouter au Panier';

  @override
  String get noDataAvailable => 'Aucune donnée disponible';

  @override
  String get total => 'Total';

  @override
  String get syncData => 'Synchroniser les Données';

  @override
  String get startSync => 'Démarrer la Synchronisation';

  @override
  String get syncSuccess => 'Données synchronisées avec succès';

  @override
  String get syncError => 'Erreur lors de la synchronisation des données';

  @override
  String get nfcNotAvailable => 'NFC non disponible';

  @override
  String get scanningForNfcTags => 'Recherche de balises NFC';

  @override
  String get nfcScanStopped => 'Balayage NFC arrêté';

  @override
  String get qrCode => 'Code QR';

  @override
  String get nfcTag => 'Balise NFC';

  @override
  String get nfcScanError => 'Erreur lors de la numérisation NFC';

  @override
  String get multiTagFoundIOS => 'Plusieurs balises trouvées!';

  @override
  String get scanInfoMessageIOS => 'Scannez votre balise';

  @override
  String get addEmptyItem => 'Ajouter un article vide';

  @override
  String get maxCapacity => 'Capacité maximale';

  @override
  String get uid => 'UID';

  @override
  String get bag => 'Sac';

  @override
  String get container => 'Conteneur';

  @override
  String get building => 'Bâtiment';

  @override
  String get transportVehicle => 'Véhicule de transport';

  @override
  String get pleaseCompleteAllFields => 'Veuillez remplir tous les champs';

  @override
  String get fieldRequired => 'Ce champ est obligatoire';

  @override
  String get invalidNumber => 'Veuillez entrer un nombre valide';

  @override
  String get geolocation => 'Géolocalisation';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get useCurrentLocation => 'Utiliser la position actuelle';

  @override
  String get locationError =>
      'Erreur lors de l\'\'obtention de la localisation';

  @override
  String get invalidLatitude => 'Latitude invalide';

  @override
  String get invalidLongitude => 'Longitude invalide';

  @override
  String get sellOnline => 'Vendre en ligne';

  @override
  String get recipientEmail => 'E-mail du destinataire';

  @override
  String get invalidEmail => 'Adresse e-mail invalide';

  @override
  String get userNotFound => 'Utilisateur non trouvé';

  @override
  String get saleCompleted => 'Vente effectuée avec succès';

  @override
  String get saleError => 'Une erreur s\'\'est produite lors de la vente';

  @override
  String get newTransferNotificationTitle => 'Nouveau transfert';

  @override
  String get newTransferNotificationBody =>
      'Vous avez reçu un nouveau transfert d\'\'article';

  @override
  String get coffee => 'Café';

  @override
  String get amount2 => 'Quantité';

  @override
  String speciesLabel(String species) {
    return 'Espèce: $species';
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
    return 'Acheté le: $date';
  }

  @override
  String fromPlot(String plotId) {
    return 'De la parcelle: $plotId';
  }

  @override
  String get noPlotFound => 'Aucune parcelle trouvée';

  @override
  String errorWithParam(String error) {
    return 'Erreur: $error';
  }

  @override
  String get loadingData => 'Chargement des données...';

  @override
  String get pdfGenerationError => 'Erreur lors de la génération du PDF';

  @override
  String containerIsEmpty(String containerType, String id) {
    return '$containerType $id est vide';
  }

  @override
  String idWithBrackets(String id) {
    return '(ID: $id)';
  }

  @override
  String get buyCoffee => 'Acheter du café';

  @override
  String get sellOffline => 'Vendre hors ligne';

  @override
  String get changeProcessingState => 'Modifier l\'état de traitement/qualité';

  @override
  String get changeLocation => 'Changer l\'emplacement';

  @override
  String get selectQualityCriteria => 'Sélectionner les critères de qualité';

  @override
  String get selectProcessingState => 'Sélectionner l\'état de traitement';

  @override
  String pdfError(String error) {
    return 'Erreur PDF: $error';
  }

  @override
  String get errorSendingEmailWithError =>
      'Erreur lors de l\'envoi de l\'e-mail';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get resendEmail => 'Renvoyer l\'e-mail !';

  @override
  String get waitingForEmailVerification =>
      'En attente de vérification de l\'e-mail. Veuillez vérifier votre boîte de réception et confirmer votre e-mail.';

  @override
  String get emailVerification => 'Vérification de l\'e-mail';

  @override
  String get securityError => 'Erreur de sécurité';

  @override
  String get securityErrorMessage =>
      'Les paramètres de sécurité pour les signatures numériques n\'ont pas pu être générés. Veuillez réessayer plus tard et assurez-vous d\'avoir une connexion Internet.';

  @override
  String get closeApp => 'Fermer l\'application';

  @override
  String get uidAlreadyExists =>
      'Cet identifiant existe déjà, veuillez en choisir un autre';

  @override
  String get selectItemToSell => 'Veuillez sélectionner un article à vendre';

  @override
  String get debugDeleteContainer => 'Supprimer le conteneur (Debug)';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageFrench => 'Français';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get generateDDS => 'Générer DDS';

  @override
  String get ddsGenerationDemo =>
      'La génération DDS n\'est disponible qu\'en mode démo';

  @override
  String get sampleOperator => 'Opérateur exemple';

  @override
  String get sampleAddress => 'Adresse exemple';

  @override
  String get sampleEori => 'EORI exemple';

  @override
  String get sampleHsCode => 'Code HS exemple';

  @override
  String get sampleDescription => 'Description exemple';

  @override
  String get sampleTradeName => 'Nom commercial exemple';

  @override
  String get sampleScientificName => 'Nom scientifique exemple';

  @override
  String get sampleQuantity => 'Quantité exemple';

  @override
  String get sampleCountry => 'Pays exemple';

  @override
  String get sampleName => 'Nom exemple';

  @override
  String get sampleFunction => 'Fonction exemple';

  @override
  String get scanQRCode => 'Scanner le code QR';

  @override
  String get errorLabel => 'Erreur';

  @override
  String get welcomeToApp => 'Bienvenue sur TraceFoodChain';

  @override
  String get signInMessage =>
      'Veuillez vous connecter ou vous inscrire pour assurer la sécurité et l\'intégrité de notre système de traçabilité alimentaire.';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get pleaseEnterEmail => 'Veuillez entrer votre e-mail';

  @override
  String get pleaseEnterPassword => 'Veuillez entrer votre mot de passe';

  @override
  String get signInSignUp => 'Se connecter / S\'inscrire';

  @override
  String get helpButtonTooltip => 'Ouvrir l\'aide';

  @override
  String get errorOpeningUrl => 'Impossible d\'ouvrir la page d\'aide';

  @override
  String get weakPasswordError => 'Le mot de passe fourni est trop faible.';

  @override
  String get emailAlreadyInUseError => 'Un compte existe déjà avec cet e-mail.';

  @override
  String get invalidEmailError => 'L\'adresse e-mail n\'est pas valide.';

  @override
  String get userDisabledError => 'Cet utilisateur a été désactivé.';

  @override
  String get wrongPasswordError =>
      'Mot de passe incorrect pour cet utilisateur.';

  @override
  String get undefinedError => 'Une erreur indéfinie s\'est produite.';

  @override
  String get error => 'Erreur';

  @override
  String get aggregateItems => 'Agréger les articles';

  @override
  String get addNewEmptyItem => 'Ajouter un nouvel article vide';

  @override
  String get selectBuyCoffeeOption => 'Sélectionner l\'option d\'achat de café';

  @override
  String get selectSellCoffeeOption =>
      'Sélectionner l\'option de vente de café';

  @override
  String get deviceToCloud => 'Appareil vers cloud';

  @override
  String get deviceToDevice => 'Appareil à appareil';

  @override
  String get ciatFirstSale => 'Première vente CIAT';

  @override
  String get buyCoffeeDeviceToDevice => 'Acheter du café (appareil à appareil)';

  @override
  String get scanSelectFutureContainer =>
      'Scanner/Sélectionner le futur conteneur';

  @override
  String get scanContainerInstructions =>
      'Utilisez le QR-Code/NFC ou sélectionnez manuellement pour spécifier où le café sera stocké.';

  @override
  String get presentInfoToSeller => 'Présenter les informations au vendeur';

  @override
  String get presentInfoToSellerInstructions =>
      'Montrez le code QR ou le tag NFC au vendeur pour initier la transaction.';

  @override
  String get receiveDataFromSeller => 'Recevoir les données du vendeur';

  @override
  String get receiveDataFromSellerInstructions =>
      'Scannez le code QR ou le tag NFC de l\'appareil du vendeur pour finaliser la transaction.';

  @override
  String get present => 'PRÉSENTER';

  @override
  String get receive => 'RECEVOIR';

  @override
  String get back => 'RETOUR';

  @override
  String get next => 'SUIVANT';

  @override
  String get buyCoffeeCiatFirstSale => 'Acheter du café (Première vente CIAT)';

  @override
  String get scanSellerTag => 'Scanner l\'étiquette fournie par le vendeur';

  @override
  String get scanSellerTagInstructions =>
      'Utilisez le code QR ou NFC du vendeur pour spécifier le café que vous allez acheter.';

  @override
  String get enterCoffeeInfo => 'Saisir les informations du café';

  @override
  String get enterCoffeeInfoInstructions =>
      'Fournissez les détails sur le café acheté.';

  @override
  String get scanReceivingContainer =>
      'Scanner l\'étiquette du conteneur de réception (sac, entrepôt, bâtiment, camion...)';

  @override
  String get scanReceivingContainerInstructions =>
      'Précisez où le café sera transféré.';

  @override
  String get coffeeInformation => 'Informations sur le Café';

  @override
  String get countryOfOrigin => 'Pays d\'origine';

  @override
  String get selectCountry => 'Sélectionner le pays';

  @override
  String get selectSpecies => 'Sélectionner l\'espèce';

  @override
  String get enterQuantity => 'Saisir la quantité';

  @override
  String get start => 'DÉMARRER!';

  @override
  String get scan => 'SCANNER';

  @override
  String get species => 'Espèce';

  @override
  String get processingState => 'État de traitement';

  @override
  String get qualityReductionCriteria => 'Critères de réduction de qualité';

  @override
  String get sellCoffeeDeviceToDevice => 'Vendre du café (appareil à appareil)';

  @override
  String get scanBuyerInfo => 'Scanner les informations de l\'acheteur';

  @override
  String get scanBuyerInfoInstructions =>
      'Scannez le code QR ou le tag NFC de l\'acheteur pour initier la transaction.';

  @override
  String get presentInfoToBuyer => 'Présenter les informations à l\'acheteur';

  @override
  String get presentInfoToBuyerInstructions =>
      'Montrez le code QR ou le tag NFC à l\'acheteur pour finaliser la transaction.';

  @override
  String get selectFromDatabase => 'Sélectionner depuis la base de données';

  @override
  String get notSynced => 'Non synchronisé avec le cloud';

  @override
  String get synced => 'Synchronisé avec le cloud';

  @override
  String get inbox => 'Boîte de réception';

  @override
  String get sendFeedback => 'Envoyer un Retour';

  @override
  String get fillInReminder => 'Veuillez remplir correctement tous les champs';

  @override
  String get manual => 'Saisie manuelle';

  @override
  String get selectCountryFirst => 'Veuillez d\'abord sélectionner un pays !';

  @override
  String get inputOfAdditionalInformation =>
      'La saisie d\'informations supplémentaires est obligatoire !';

  @override
  String get provideValidContainer =>
      'Veuillez fournir une étiquette valide du conteneur de réception.';

  @override
  String get buttonNext => 'SUIVANT';

  @override
  String get buttonScan => 'SCANNER !';

  @override
  String get buttonStart => 'DÉMARRER !';

  @override
  String get buttonBack => 'RETOUR';

  @override
  String get locationPermissionsDenied =>
      'Les permissions de localisation sont refusées';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'Les permissions de localisation sont refusées de façon permanente';

  @override
  String get errorSyncToCloud =>
      'Erreur lors de la synchronisation des données vers le cloud';

  @override
  String get errorBadRequest => 'Erreur serveur : Mauvaise requête';

  @override
  String get errorMergeConflict =>
      'Erreur du serveur : Conflit de fusion - Les données existent dans différentes versions';

  @override
  String get errorServiceUnavailable =>
      'Erreur du serveur : Service indisponible';

  @override
  String get errorUnauthorized => 'Erreur serveur : Non autorisé';

  @override
  String get errorForbidden => 'Erreur serveur : Interdit';

  @override
  String get errorNotFound => 'Erreur serveur : Introuvable';

  @override
  String get errorInternalServerError => 'Erreur serveur : Erreur interne';

  @override
  String get errorGatewayTimeout =>
      'Erreur serveur : Délai d\'attente de la passerelle';

  @override
  String get errorUnknown => 'Erreur inconnue';

  @override
  String get errorNoCloudConnectionProperties =>
      'Aucune propriété de connexion au cloud trouvée';

  @override
  String get syncToCloudSuccessful => 'Synchronisation vers le cloud réussie';

  @override
  String get testModeActive => 'Mode test activé';

  @override
  String get dataMode => 'Mode de données';

  @override
  String get testMode => 'Mode test';

  @override
  String get realMode => 'Mode de production';

  @override
  String get nologoutpossible =>
      'Déconnexion possible uniquement lorsqu\'une connexion Internet est établie';

  @override
  String get manuallySyncingWith => 'Synchronisation manuelle avec';

  @override
  String get syncingWith => 'Synchronisation avec';

  @override
  String get newKeypairNeeded =>
      'Aucune clé privée trouvée - génération d\'une nouvelle paire de clés...';

  @override
  String get failedToInitializeKeyManagement =>
      'ATTENTION : Échec de l\'initialisation de la gestion des clés !';

  @override
  String get newUserProfileNeeded =>
      'Profil utilisateur non trouvé dans la base de données locale - création d\'un nouveau...';

  @override
  String get coffeeIsBought => 'Le café est acheté';

  @override
  String get coffeeIsSold => 'Le café est vendu';

  @override
  String get generatingItem => 'Génération de l\'article...';

  @override
  String get processing => 'Traitement des données...';

  @override
  String get setItemName => 'Définir le nom';

  @override
  String get unnamedObject => 'Objet sans nom';

  @override
  String get capacity => 'Capacité';

  @override
  String get freeCapacity => 'Capacité libre';

  @override
  String get selectContainerForItems =>
      'Sélectionner conteneurs\npour les articles';

  @override
  String get selectContainer => 'Sélectionner un conteneur';

  @override
  String get enterUIDhere => 'Entrez l\'UID ici';

  @override
  String get excelFileDownloaded => 'Fichier Excel téléchargé';

  @override
  String get excelFileSavedAt => 'Fichier Excel enregistré à';

  @override
  String get failedToGenerateExcelFile =>
      'Échec de la génération du fichier Excel';

  @override
  String get exportToExcel => 'Exporter vers Excel';

  @override
  String get resetPasswordEmailSent =>
      'E-mail de réinitialisation du mot de passe envoyé';

  @override
  String get forgotPasswordQuestion => 'Mot de passe oublié?';

  @override
  String get weightEquivalentGreenBeanKg =>
      'Équivalent en poids de café vert (kg)';

  @override
  String get login => 'Connexion';

  @override
  String get pleaseEnterEmailAndPassword =>
      'Veuillez saisir l\'e-mail et le mot de passe';

  @override
  String get loggingIn => 'Connexion en cours...';

  @override
  String get loginFailed => 'Échec de la connexion';

  @override
  String get gettingAuthorityToken => 'Obtention du jeton d\'autorité...';

  @override
  String get fieldRegistry => 'Registre des Champs';

  @override
  String get fieldRegistryTitle => 'Champs Enregistrés';

  @override
  String get fieldName => 'Nom du Champ';

  @override
  String get geoId => 'ID Géographique';

  @override
  String get area => 'Surface';

  @override
  String get registerNewFields => 'Enregistrer de Nouveaux Champs';

  @override
  String get uploadCsv => 'Télécharger CSV';

  @override
  String get selectCsvFile => 'Sélectionner Fichier CSV';

  @override
  String get csvUploadSuccess => 'CSV téléchargé avec succès';

  @override
  String get csvUploadError => 'Erreur lors du téléchargement CSV';

  @override
  String get registering => 'Enregistrement...';

  @override
  String get registrationComplete => 'Enregistrement terminé';

  @override
  String get registrationError => 'Erreur d\'enregistrement';

  @override
  String get fieldAlreadyExists => 'Le champ existe déjà';

  @override
  String get noFieldsRegistered => 'Aucun champ enregistré';

  @override
  String get csvFormatInfo => 'Format CSV: Nom, Description, Coordonnées';

  @override
  String get invalidCsvFormat => 'Format CSV invalide';

  @override
  String get fieldRegisteredSuccessfully => 'Champ enregistré avec succès';

  @override
  String get progressStep1InitializingServices =>
      'Étape 1: Initialisation des services...';

  @override
  String get progressStep1UserRegistryLogin =>
      'Étape 1: Connexion au User Registry...';

  @override
  String get progressStep2RegisteringField =>
      'Étape 2: Enregistrement du champ avec Asset Registry...';

  @override
  String get progressStep2FieldRegisteredSuccessfully =>
      'Étape 2: Champ enregistré avec succès, extraction du GeoID...';

  @override
  String get progressStep2FieldAlreadyExists =>
      'Étape 2: Le champ existe déjà, extraction du GeoID...';

  @override
  String progressStep3CheckingCentralDatabase(String geoId) {
    return 'Étape 3: Vérification de la base de données centrale (GeoID: $geoId)...';
  }

  @override
  String get progressStep3FieldNotFoundInCentralDb =>
      'Étape 3: Champ non trouvé dans la base de données centrale - procédure d\'enregistrement local...';

  @override
  String get processingCsvFile => 'Traitement du fichier CSV...';

  @override
  String get fieldRegistrationInProgress =>
      'Enregistrement du champ en cours...';

  @override
  String fieldXOfTotal(String current, String total) {
    return 'Champ $current de $total';
  }

  @override
  String currentField(String fieldName) {
    return 'Champ actuel: $fieldName';
  }

  @override
  String fieldRegistrationSuccessMessage(String fieldName) {
    return '✅ Champ \"$fieldName\" enregistré avec succès!';
  }

  @override
  String fieldRegistrationErrorMessage(String fieldName, String error) {
    return '❌ Erreur avec \"$fieldName\": $error';
  }

  @override
  String fieldAlreadyExistsGeoIdExtracted(String geoId) {
    return '✅ Le champ existe déjà - GeoID extrait avec succès : $geoId';
  }

  @override
  String fieldAlreadyExistsGeoIdFailed(String error) {
    return '⚠️ Le champ existe déjà - Échec de l\'extraction de la GeoID : $error';
  }

  @override
  String fieldRegistrationNewGeoIdExtracted(String geoId) {
    return '✅ Nouveau champ enregistré - GeoID extrait avec succès : $geoId';
  }

  @override
  String fieldRegistrationNewGeoIdFailed(String error) {
    return '⚠️ Nouveau champ enregistré - Échec de l\'extraction de la GeoID : $error';
  }

  @override
  String get csvProcessingComplete => 'Traitement CSV Terminé';

  @override
  String get fieldsSuccessfullyRegistered => 'champs enregistrés avec succès';

  @override
  String get fieldsAlreadyExisted => 'champs existaient déjà';

  @override
  String get fieldsWithErrors => 'champs avec des erreurs';

  @override
  String get unnamedField => 'Champ Sans Nom';

  @override
  String get unknown => 'Inconnu';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String daysAgo(String days) {
    return 'il y a $days jours';
  }

  @override
  String weeksAgo(String weeks, String plural) {
    return 'il y a $weeks semaine$plural';
  }

  @override
  String monthsAgo(String months, String plural) {
    return 'il y a $months mois';
  }

  @override
  String yearsAgo(String years, String plural) {
    return 'il y a $years an$plural';
  }

  @override
  String get allFields => 'Tous les Champs';

  @override
  String get registeredToday => 'Enregistrés Aujourd\'hui';

  @override
  String get lastWeek => 'Semaine Dernière';

  @override
  String get lastMonth => 'Mois Dernier';

  @override
  String get lastYear => 'Année Dernière';

  @override
  String get filterByRegistrationDate => 'Filtrer par date d\'enregistrement';

  @override
  String get registrationErrors => 'Erreurs d\'Enregistrement';

  @override
  String get noFieldsForSelectedTimeframe =>
      'Aucun champ pour la période sélectionnée';

  @override
  String registeredOn(String date) {
    return 'Enregistré : $date';
  }

  @override
  String fieldsCountSorted(String count, String total, String totalSingular) {
    String _temp0 = intl.Intl.selectLogic(
      totalSingular,
      {
        '1': 'champ',
        'other': 'champs',
      },
    );
    return '$count sur $total $_temp0 (triés par date)';
  }

  @override
  String csvLineError(String line, String error) {
    return 'Ligne $line : $error';
  }

  @override
  String csvLineNameCoordinatesRequired(String line) {
    return 'Ligne $line : Nom et coordonnées sont requis';
  }

  @override
  String csvLineRegistrationError(String line, String error) {
    return 'Ligne $line : Erreur d\'enregistrement - $error';
  }

  @override
  String get registeredOnLabel => 'Enregistré le';

  @override
  String get specificDateLabel => 'Date spécifique';
}

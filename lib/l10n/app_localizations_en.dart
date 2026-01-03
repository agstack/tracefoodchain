// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trace Foodchains';

  @override
  String get traceTheFoodchain => 'Trace the Foodchain';

  @override
  String get selectRole => 'Select Role';

  @override
  String welcomeMessage(String role) {
    return 'Welcome, $role!';
  }

  @override
  String get actions => 'Actions';

  @override
  String get storage => 'Storage';

  @override
  String get settings => 'Settings';

  @override
  String get farmerActions => 'Farmer Actions';

  @override
  String get farmManagerActions => 'Farm Manager Actions';

  @override
  String get traderActions => 'Trader Actions';

  @override
  String get transporterActions => 'Transporter Actions';

  @override
  String get sellerActions => 'Seller Actions';

  @override
  String get buyerActions => 'Buyer Actions';

  @override
  String get identifyYourselfOnline => 'Identify Yourself';

  @override
  String get startHarvestOffline => 'Start Harvest';

  @override
  String get waitingForData => 'Waiting for Data...';

  @override
  String get handOverHarvestToTrader => 'Hand Over Harvest to Trader';

  @override
  String get scanQrCodeOrNfcTag => 'Scan QR Code or NFC Tag';

  @override
  String get startNewHarvest => 'new Harvest';

  @override
  String get scanTraderTag => 'scan trader tag!';

  @override
  String get scanFarmerTag => 'scan farmer tag!';

  @override
  String get unit => 'unit';

  @override
  String get changeRole => 'change role';

  @override
  String get inTransit => 'in transit';

  @override
  String get delivered => 'delivered';

  @override
  String get completed => 'completed';

  @override
  String get statusUpdatedSuccessfully => 'updated successfully';

  @override
  String get noRole => 'No Role';

  @override
  String get roleFarmer => 'Farmer';

  @override
  String get roleFarmManager => 'Farm Manager';

  @override
  String get roleTrader => 'Trader';

  @override
  String get roleTransporter => 'Transporter';

  @override
  String get roleProcessor => 'Coffee Processor';

  @override
  String get roleImporter => 'EU Importer';

  @override
  String get roleRegistrar => 'Registrar';

  @override
  String get activeImports => 'Current Imports';

  @override
  String get noActiveImports => 'No Current Imports';

  @override
  String get noActiveItems => 'No stock found';

  @override
  String get noImportHistory => 'No Import History';

  @override
  String get importHistory => 'Import History';

  @override
  String get roleSeller => 'Seller';

  @override
  String get roleBuyer => 'Buyer';

  @override
  String get roleSystemAdministrator => 'System Administrator';

  @override
  String get roleDiascaAdmin => 'Diasca Admin';

  @override
  String get roleSuperAdmin => 'Super Administrator';

  @override
  String get roleTfcAdmin => 'TFC Administrator';

  @override
  String get roleRegistrarCoordinator => 'Registrar Coordinator';

  @override
  String get roleVerificationAuthority => 'Verification Authority';

  @override
  String get roleAssignedSuccessfully => 'Role assigned successfully';

  @override
  String get errorAssigningRole => 'Error assigning role';

  @override
  String get userManagement => 'User Management';

  @override
  String get userManagementSubtitle => 'Manage and assign user roles';

  @override
  String get noPermissionForUserManagement =>
      'No permission for user management';

  @override
  String get qcReview => 'QC Review';

  @override
  String get qcReviewSubtitle => 'Review and approve pending registrations';

  @override
  String get userManagementOnlineOnly =>
      'User management is only available online';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get assignRole => 'Assign Role';

  @override
  String get currentRole => 'Current Role';

  @override
  String get newRole => 'New Role';

  @override
  String get reason => 'Reason';

  @override
  String get enterReasonForRoleChange => 'Enter reason for role change';

  @override
  String get enterReason => 'Enter reason for role change';

  @override
  String get cancel => 'Cancel';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmation => 'Are you sure you want to logout?';

  @override
  String get assign => 'Assign';

  @override
  String get userDetails => 'User Details';

  @override
  String get name => 'Name';

  @override
  String get email => 'Email';

  @override
  String get userID => 'User ID';

  @override
  String get manageable => 'Manageable';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get roleManagementDebugInfo => 'Role Management Debug Info';

  @override
  String get firestoreError => 'Firestore Error';

  @override
  String get appUserDocRepairedSuccessfully =>
      'appUserDoc successfully repaired';

  @override
  String get repairFailed => 'Repair failed';

  @override
  String get repairAppUserDoc => 'Repair appUserDoc';

  @override
  String get notManageable => 'Not manageable';

  @override
  String get possibleReasons =>
      'Possible reasons:\n• No manageable users found\n• Filter too restrictive\n• Missing permissions';

  @override
  String get noAvailableRolesForPermission =>
      'No available roles for your permission';

  @override
  String usersCount(int filtered, int total) {
    return '$filtered of $total users';
  }

  @override
  String get showUserDetails => 'Show user details';

  @override
  String get editRole => 'Edit role';

  @override
  String get superadminSecurityError =>
      'SECURITY ERROR: SUPERADMIN roles cannot be changed';

  @override
  String get superadminSecurityInfo =>
      'SUPERADMIN users are protected by security policies';

  @override
  String get superadminCannotBeAssigned => 'SUPERADMIN role cannot be assigned';

  @override
  String get superadminCannotBeChanged => 'SUPERADMIN role cannot be changed';

  @override
  String get searchUsers => 'Search Users';

  @override
  String get filterByRole => 'Filter by Role';

  @override
  String get allRoles => 'All Roles';

  @override
  String get roleSuccessfullyAssigned => 'Role successfully assigned';

  @override
  String get errorWhileAssigningRole => 'Error while assigning role';

  @override
  String get reasonForRoleChange => 'Reason for role change';

  @override
  String get enterNewFarmerID => 'Enter new Farmer ID';

  @override
  String get enterNewFarmID => 'Enter new Farm ID';

  @override
  String scannedCode(String code) {
    return 'Scanned Code: $code';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String get errorIncorrectData => 'ERROR: The received data are not valid!';

  @override
  String get provideValidSellerTag => 'Please provide a valid seller tag.';

  @override
  String get confirmTransfer =>
      'Did the buyer receive the information correctly?';

  @override
  String get peerTransfer => 'Peer Transfer';

  @override
  String get generateTransferData => 'Generate Transfer Data';

  @override
  String get startScanning => 'Start Scanning';

  @override
  String get stopScanning => 'Stop Scanning';

  @override
  String get startPresenting => 'Start Presenting';

  @override
  String get stopPresenting => 'Stop Presenting';

  @override
  String get transferDataGenerated => 'Transfer Data Generated';

  @override
  String get dataReceived => 'Data Received';

  @override
  String get ok => 'OK';

  @override
  String get feedbackEmailSubject => 'Feedback for TraceFoodchain App';

  @override
  String get feedbackEmailBody => 'Please enter your feedback here:';

  @override
  String get unableToLaunchEmail => 'Unable to launch email client';

  @override
  String get activeItems => 'Active Items';

  @override
  String get pastItems => 'Past Items';

  @override
  String get changeFarmerId => 'Change Farmer ID';

  @override
  String get changeFarm => 'Change Farm';

  @override
  String get associateWithDifferentFarm => 'Associate with a Different Farm';

  @override
  String get manageFarmEmployees => 'Manage Farm Employees';

  @override
  String get manageHarvests => 'Manage Harvests';

  @override
  String get manageContainers => 'Manage Containers';

  @override
  String get buyHarvest => 'Buy Harvest';

  @override
  String get sellHarvest => 'Sell Harvest';

  @override
  String get manageInventory => 'Manage Inventory';

  @override
  String get addEmployee => 'Add Employee';

  @override
  String get editEmployee => 'Edit Employee';

  @override
  String get addHarvest => 'Add Harvest';

  @override
  String get harvestDetails => 'Harvest Details';

  @override
  String get addContainer => 'Add Container';

  @override
  String get containerQRCode => 'Container QR Code';

  @override
  String get notImplementedYet => 'This functionality is not implemented yet';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get invalidInput => 'Invalid input. Please enter valid numbers.';

  @override
  String get editInventoryItem => 'Edit Inventory Item';

  @override
  String get filterByCropType => 'Filter by crop type';

  @override
  String get sortBy => 'Sort by';

  @override
  String get cropType => 'Crop Type';

  @override
  String get quantity => 'Quantity';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String get price => 'Price';

  @override
  String get activeDeliveries => 'Active Deliveries';

  @override
  String get deliveryHistory => 'Delivery History';

  @override
  String get updateStatus => 'Update Status';

  @override
  String get updateDeliveryStatus => 'Update Delivery Status';

  @override
  String get noDeliveryHistory => 'No delivery history';

  @override
  String get noActiveDeliveries => 'No active deliveries';

  @override
  String get listProducts => 'List Products';

  @override
  String get manageOrders => 'Manage Orders';

  @override
  String get salesHistory => 'Sales History';

  @override
  String get goToActions => 'Go to Actions';

  @override
  String get setPrice => 'Set Price';

  @override
  String get browseProducts => 'Browse Products';

  @override
  String get orderHistory => 'Order History';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get total => 'Total';

  @override
  String get syncData => 'Sync Data';

  @override
  String get startSync => 'Start Sync';

  @override
  String get syncSuccess => 'Data synchronized successfully';

  @override
  String get syncError => 'Error synchronizing data';

  @override
  String get nfcNotAvailable => 'NFC not available';

  @override
  String get scanningForNfcTags => 'Scanning for NFC tags';

  @override
  String get nfcScanStopped => 'NFC scan stopped';

  @override
  String get qrCode => 'QR code';

  @override
  String get nfcTag => 'NFC tag';

  @override
  String get nfcScanError => 'Error during NFC scan';

  @override
  String get multiTagFoundIOS => 'Multiple tags found!';

  @override
  String get scanInfoMessageIOS => 'Scan your tag';

  @override
  String get addEmptyItem => 'Add Empty Item';

  @override
  String get maxCapacity => 'Maximum Capacity';

  @override
  String get uid => 'UID';

  @override
  String get bag => 'Bag';

  @override
  String get container => 'Container';

  @override
  String get building => 'Building';

  @override
  String get transportVehicle => 'Transport Vehicle';

  @override
  String get pleaseCompleteAllFields => 'Please complete all fields';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidNumber => 'Please enter a valid number';

  @override
  String get geolocation => 'Geolocation';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get useCurrentLocation => 'Use Current Location';

  @override
  String get locationError => 'Error getting location';

  @override
  String get invalidLatitude => 'Invalid latitude';

  @override
  String get invalidLongitude => 'Invalid longitude';

  @override
  String get sellOnline => 'Sell Online';

  @override
  String get recipientEmail => 'Email of recipient';

  @override
  String get invalidEmail => 'Invalid email address';

  @override
  String get userNotFound => 'User not found';

  @override
  String get saleCompleted => 'Sale completed successfully';

  @override
  String get saleError => 'An error occurred during the sale';

  @override
  String get newTransferNotificationTitle => 'New Transfer';

  @override
  String get newTransferNotificationBody =>
      'You have received a new item transfer';

  @override
  String get coffee => 'Coffee';

  @override
  String get amount2 => 'Amount';

  @override
  String speciesLabel(String species) {
    return 'Species: $species';
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
    return 'Bought on: $date';
  }

  @override
  String fromPlot(String plotId) {
    return 'From plot: $plotId';
  }

  @override
  String get noPlotFound => 'No plot found';

  @override
  String errorWithParam(String error) {
    return 'Error: $error';
  }

  @override
  String get loadingData => 'Loading data...';

  @override
  String get pdfGenerationError => 'Error generating PDF';

  @override
  String containerIsEmpty(String containerType, String id) {
    return '$containerType $id is empty';
  }

  @override
  String idWithBrackets(String id) {
    return '(ID: $id)';
  }

  @override
  String get buyCoffee => 'Buy coffee';

  @override
  String get sellOffline => 'Sell offline';

  @override
  String get changeProcessingState => 'Change processing/quality state';

  @override
  String get changeLocation => 'Change location';

  @override
  String get selectQualityCriteria => 'Select quality criteria';

  @override
  String get selectProcessingState => 'Select processing state';

  @override
  String pdfError(String error) {
    return 'PDF error: $error';
  }

  @override
  String get errorSendingEmailWithError => 'Error sending email';

  @override
  String get signOut => 'Sign out';

  @override
  String get resendEmail => 'Resend email!';

  @override
  String get waitingForEmailVerification =>
      'Waiting for email verification. Please check your inbox and confirm your email.';

  @override
  String get emailVerification => 'Email verification';

  @override
  String get securityError => 'Security error';

  @override
  String get securityErrorMessage =>
      'We could not generate the setup for digital signage. Please try again later making sure you have internet connection.';

  @override
  String get closeApp => 'Close App';

  @override
  String get uidAlreadyExists =>
      'This ID already exists, please chose another one';

  @override
  String get selectItemToSell => 'Please select an item to sell';

  @override
  String get debugDeleteContainer => 'Delete container (Debug)';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'German';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageFrench => 'French';

  @override
  String get selectAll => 'Select All';

  @override
  String get generateDDS => 'Generate DDS';

  @override
  String get ddsGenerationDemo =>
      'DDS generation is only available in demo mode';

  @override
  String get sampleOperator => 'Sample Operator';

  @override
  String get sampleAddress => 'Sample Address';

  @override
  String get sampleEori => 'Sample EORI';

  @override
  String get sampleHsCode => 'Sample HS Code';

  @override
  String get sampleDescription => 'Sample Description';

  @override
  String get sampleTradeName => 'Sample Trade Name';

  @override
  String get sampleScientificName => 'Sample Scientific Name';

  @override
  String get sampleQuantity => 'Sample Quantity';

  @override
  String get sampleCountry => 'Sample Country';

  @override
  String get sampleName => 'Sample Name';

  @override
  String get sampleFunction => 'Sample Function';

  @override
  String get scanQRCode => 'Scan QR Code';

  @override
  String get errorLabel => 'Error';

  @override
  String get welcomeToApp => 'Welcome to TraceFoodChain';

  @override
  String get signInMessage =>
      'Please sign in or sign up to ensure the security and integrity of our food chain tracking system.';

  @override
  String get password => 'Password';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get signInSignUp => 'Sign In / Sign Up';

  @override
  String get helpButtonTooltip => 'Open Help';

  @override
  String get errorOpeningUrl => 'Could not open help page';

  @override
  String get weakPasswordError => 'The password provided is too weak.';

  @override
  String get emailAlreadyInUseError =>
      'An account already exists for that email.';

  @override
  String get invalidEmailError => 'The email address is not valid.';

  @override
  String get userDisabledError => 'This user has been disabled.';

  @override
  String get wrongPasswordError => 'Wrong password provided for that user.';

  @override
  String get undefinedError => 'An undefined error happened.';

  @override
  String get error => 'Error';

  @override
  String get aggregateItems => 'Aggregate items';

  @override
  String get addNewEmptyItem => 'Add new empty item';

  @override
  String get selectBuyCoffeeOption => 'Select Buy Coffee Option';

  @override
  String get selectSellCoffeeOption => 'Select Sell Coffee Option';

  @override
  String get deviceToCloud => 'Device-to-cloud';

  @override
  String get deviceToDevice => 'Device-to-device';

  @override
  String get ciatFirstSale => 'CIAT first sale';

  @override
  String get buyCoffeeDeviceToDevice => 'Buy Coffee (device-to-device)';

  @override
  String get scanSelectFutureContainer => 'Scan/select target container';

  @override
  String get scanContainerInstructions =>
      'Use QR-Code/NFC or select manually to specify where the coffee will be stored.';

  @override
  String get presentInfoToSeller => 'Present information to seller';

  @override
  String get presentInfoToSellerInstructions =>
      'Show the QR code or NFC tag to the seller to initiate the transaction.';

  @override
  String get receiveDataFromSeller => 'Receive data from seller';

  @override
  String get receiveDataFromSellerInstructions =>
      'Scan the QR code or NFC tag from the seller\'s device to complete the transaction.';

  @override
  String get present => 'PRESENT';

  @override
  String get receive => 'RECEIVE';

  @override
  String get back => 'BACK';

  @override
  String get next => 'NEXT';

  @override
  String get buyCoffeeCiatFirstSale => 'Buy Coffee (CIAT First Sale)';

  @override
  String get scanSellerTag => 'Scan tag provided by seller';

  @override
  String get scanSellerTagInstructions =>
      'Use QR-Code or NFC from seller to specify the coffee that you are about to buy.';

  @override
  String get enterCoffeeInfo => 'Enter coffee information';

  @override
  String get enterCoffeeInfoInstructions =>
      'Provide details about the coffee being purchased.';

  @override
  String get scanReceivingContainer =>
      'Scan tag of the receiving container (sack, storage, building, truck...)';

  @override
  String get scanReceivingContainerInstructions =>
      'Specify where the coffee is transferred to.';

  @override
  String get coffeeInformation => 'Coffee Information';

  @override
  String get countryOfOrigin => 'Country of Origin';

  @override
  String get selectCountry => 'Select Country';

  @override
  String get selectSpecies => 'Select Species';

  @override
  String get enterQuantity => 'Enter quantity';

  @override
  String get start => 'START!';

  @override
  String get scan => 'SCAN!';

  @override
  String get species => 'Species';

  @override
  String get processingState => 'Processing State';

  @override
  String get qualityReductionCriteria => 'Quality Reduction Criteria';

  @override
  String get sellCoffeeDeviceToDevice => 'Sell Coffee (device-to-device)';

  @override
  String get scanBuyerInfo => 'Scan information provided by buyer';

  @override
  String get scanBuyerInfoInstructions =>
      'Use your smartphone camera or NFC to read initial information from buyer';

  @override
  String get presentInfoToBuyer =>
      'Present information to the buyer to finish sale';

  @override
  String get presentInfoToBuyerInstructions =>
      'Specify where the coffee is transferred to.';

  @override
  String get selectFromDatabase => 'Select from database';

  @override
  String get notSynced => 'Not synced to cloud';

  @override
  String get synced => 'Synced with cloud';

  @override
  String get inbox => 'Inbox';

  @override
  String get sendFeedback => 'Send Feedback';

  @override
  String get fillInReminder => 'Please fill all fields correctly';

  @override
  String get manual => 'Manual entry';

  @override
  String get selectCountryFirst => 'Please select country first!';

  @override
  String get inputOfAdditionalInformation =>
      'Input of additional information is mandatory!';

  @override
  String get provideValidContainer =>
      'Please provide a valid receiving container tag.';

  @override
  String get buttonNext => 'NEXT';

  @override
  String get buttonScan => 'SCAN!';

  @override
  String get buttonStart => 'START!';

  @override
  String get buttonBack => 'BACK';

  @override
  String get locationPermissionsDenied => 'Location permissions are denied';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'Location permissions are permanently denied';

  @override
  String get errorSyncToCloud => 'Error syncing data to cloud';

  @override
  String get errorBadRequest =>
      'Server Error: Bad Request - Invalid data or incorrect digital signature';

  @override
  String get errorMergeConflict =>
      'Server Error: Merge Conflict - Data exists in different versions';

  @override
  String get errorServiceUnavailable => 'Server Error: Service Unavailable';

  @override
  String get errorUnauthorized => 'Server Error: Unauthorized';

  @override
  String get errorForbidden => 'Server Error: Forbidden';

  @override
  String get errorNotFound => 'Server Error: Not Found';

  @override
  String get errorInternalServerError => 'Server Error: Internal Server Error';

  @override
  String get errorGatewayTimeout => 'Server Error: Gateway Timeout';

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get errorNoCloudConnectionProperties =>
      'No cloud connection properties found';

  @override
  String get syncToCloudSuccessful => 'Sync to cloud successful';

  @override
  String get testModeActive => 'Test mode active';

  @override
  String get dataMode => 'Data mode';

  @override
  String get testMode => 'Test mode';

  @override
  String get realMode => 'Production mode';

  @override
  String get nologoutpossible =>
      'Logout only possible when connected to the internet';

  @override
  String get manuallySyncingWith => 'Manually syncing with';

  @override
  String get syncingWith => 'Syncing with';

  @override
  String get syncInProgress => 'Synchronization in progress...';

  @override
  String get newKeypairNeeded =>
      'No private key found - generating new keypair...';

  @override
  String get failedToInitializeKeyManagement =>
      'WARNING: Failed to initialize key management!';

  @override
  String get newUserProfileNeeded =>
      'User profile not found in local database - creating new one...';

  @override
  String get coffeeIsBought => 'Coffee is bought';

  @override
  String get coffeeIsSold => 'Coffee is sold';

  @override
  String get generatingItem => 'Generating item...';

  @override
  String get processing => 'Processing data...';

  @override
  String get setItemName => 'Set item name';

  @override
  String get unnamedObject => 'Unnamed object';

  @override
  String get capacity => 'Capacity';

  @override
  String get freeCapacity => 'Free capacity';

  @override
  String get selectContainerForItems => 'Select container for items';

  @override
  String get selectContainer => 'Select container';

  @override
  String get enterUIDhere => 'Enter UID here';

  @override
  String get excelFileDownloaded => 'Excel file downloaded';

  @override
  String get excelFileSavedAt => 'Excel file saved at';

  @override
  String get failedToGenerateExcelFile => 'Failed to generate Excel file';

  @override
  String get exportToExcel => 'Export to Excel';

  @override
  String get resetPasswordEmailSent => 'Reset password email sent';

  @override
  String get forgotPasswordQuestion => 'Forgot your password?';

  @override
  String get weightEquivalentGreenBeanKg =>
      'weight equivalent in kg green beans';

  @override
  String get login => 'Login';

  @override
  String get pleaseEnterEmailAndPassword => 'Please enter email and password';

  @override
  String get loggingIn => 'Logging in...';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get gettingAuthorityToken => 'Getting authority token...';

  @override
  String get fieldRegistry => 'Field Registry';

  @override
  String get fieldRegistryTitle => 'Registered Fields';

  @override
  String get fieldName => 'Field Name';

  @override
  String get geoId => 'Geo ID';

  @override
  String get area => 'Area';

  @override
  String get registerNewFields => 'Register New Fields';

  @override
  String get uploadCsv => 'Upload CSV';

  @override
  String get selectCsvFile => 'Select CSV File';

  @override
  String get csvUploadSuccess => 'CSV uploaded successfully';

  @override
  String get csvUploadError => 'Error uploading CSV';

  @override
  String get registering => 'Registering...';

  @override
  String get registrationComplete => 'Registration complete';

  @override
  String get registrationError => 'Registration error';

  @override
  String get fieldAlreadyExists => 'Field already exists';

  @override
  String get noFieldsRegistered => 'No fields registered';

  @override
  String get csvFormatInfo => 'CSV Format: Name, Description, Coordinates';

  @override
  String get invalidCsvFormat => 'Invalid CSV format';

  @override
  String get fieldRegisteredSuccessfully => 'Field registered successfully';

  @override
  String get progressStep1InitializingServices =>
      'Step 1: Initializing services...';

  @override
  String get progressStep1UserRegistryLogin => 'Step 1: User Registry login...';

  @override
  String get progressStep2RegisteringField =>
      'Step 2: Registering field with Asset Registry...';

  @override
  String get progressStep2FieldRegisteredSuccessfully =>
      'Step 2: Field successfully registered, extracting GeoID...';

  @override
  String get progressStep2FieldAlreadyExists =>
      'Step 2: Field already exists, extracting GeoID...';

  @override
  String progressStep3CheckingCentralDatabase(String geoId) {
    return 'Step 3: Checking central database (GeoID: $geoId)...';
  }

  @override
  String get progressStep3FieldNotFoundInCentralDb =>
      'Step 3: Field not found in central database - proceeding with local registration...';

  @override
  String get processingCsvFile => 'Processing CSV file...';

  @override
  String get fieldRegistrationInProgress => 'Field registration in progress...';

  @override
  String fieldXOfTotal(String current, String total) {
    return 'Field $current of $total';
  }

  @override
  String currentField(String fieldName) {
    return 'Current field: $fieldName';
  }

  @override
  String fieldRegistrationSuccessMessage(String fieldName) {
    return '✅ Field \"$fieldName\" successfully registered!';
  }

  @override
  String fieldRegistrationErrorMessage(String fieldName, String error) {
    return '❌ Error with \"$fieldName\": $error';
  }

  @override
  String fieldAlreadyExistsGeoIdExtracted(String geoId) {
    return '✅ Field already exists - GeoID successfully extracted: $geoId';
  }

  @override
  String fieldAlreadyExistsGeoIdFailed(String error) {
    return '⚠️ Field already exists - Failed to extract GeoID: $error';
  }

  @override
  String fieldRegistrationNewGeoIdExtracted(String geoId) {
    return '✅ New field registered - GeoID successfully extracted: $geoId';
  }

  @override
  String fieldRegistrationNewGeoIdFailed(String error) {
    return '⚠️ New field registered - Failed to extract GeoID: $error';
  }

  @override
  String get csvProcessingComplete => 'CSV Processing Complete';

  @override
  String get fieldsSuccessfullyRegistered => 'fields successfully registered';

  @override
  String get fieldsAlreadyExisted => 'fields already existed';

  @override
  String get fieldsWithErrors => 'fields had errors';

  @override
  String get unnamedField => 'Unnamed Field';

  @override
  String get unknown => 'Unknown';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(String days) {
    return '$days days ago';
  }

  @override
  String weeksAgo(String weeks, String plural) {
    return '$weeks week$plural ago';
  }

  @override
  String monthsAgo(String months, String plural) {
    return '$months month$plural ago';
  }

  @override
  String yearsAgo(String years, String plural) {
    return '$years year$plural ago';
  }

  @override
  String get allFields => 'All Fields';

  @override
  String get registeredToday => 'Registered Today';

  @override
  String get lastWeek => 'Last Week';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get lastYear => 'Last Year';

  @override
  String get filterByRegistrationDate => 'Filter by registration date';

  @override
  String get registrationErrors => 'Registration Errors';

  @override
  String get noFieldsForSelectedTimeframe =>
      'No fields for the selected timeframe';

  @override
  String registeredOn(String date) {
    return 'Registered: $date';
  }

  @override
  String fieldsCountSorted(String count, String total, String totalSingular) {
    String _temp0 = intl.Intl.selectLogic(
      totalSingular,
      {
        '1': 'field',
        'other': 'fields',
      },
    );
    return '$count of $total $_temp0 (sorted by date)';
  }

  @override
  String csvLineError(String line, String error) {
    return 'Line $line: $error';
  }

  @override
  String csvLineNameCoordinatesRequired(String line) {
    return 'Line $line: Name and coordinates are required';
  }

  @override
  String csvLineRegistrationError(String line, String error) {
    return 'Line $line: Registration error - $error';
  }

  @override
  String get registeredOnLabel => 'Registered on';

  @override
  String get specificDateLabel => 'Specific Date';

  @override
  String get archiveContainer => 'Archive Container';

  @override
  String get containerSuccessfullyArchived =>
      'Container was successfully archived.';

  @override
  String get showArchivedContainers => 'Show also archived containers';

  @override
  String get archivedContainersVisible => 'Archived containers are shown';

  @override
  String get archivedContainersHidden => 'Archived containers are hidden';

  @override
  String get searchContainers => 'Search containers...';

  @override
  String get sort => 'Sort';

  @override
  String get sortByNameAsc => 'Name (A-Z)';

  @override
  String get sortByNameDesc => 'Name (Z-A)';

  @override
  String get sortByIdAsc => 'ID (ascending)';

  @override
  String get sortByIdDesc => 'ID (descending)';

  @override
  String get sortByDateAsc => 'Date (oldest first)';

  @override
  String get sortByDateDesc => 'Date (newest first)';

  @override
  String noSearchResults(Object searchTerm) {
    return 'No containers found matching \"$searchTerm\"';
  }

  @override
  String get profileSetup => 'Complete Profile';

  @override
  String get welcomeCompleteProfile => 'Welcome! Complete your profile';

  @override
  String get profileSetupDescription =>
      'Please provide some additional information to complete your profile.';

  @override
  String get profilePicture => 'Profile Picture';

  @override
  String get tapToAddPhoto => 'Tap here to add a photo';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get nationality => 'Nationality';

  @override
  String get role => 'Role';

  @override
  String get pleaseEnterFirstName => 'Please enter your first name';

  @override
  String get pleaseEnterLastName => 'Please enter your last name';

  @override
  String get pleaseSelectRole => 'Please select a role';

  @override
  String get saving => 'Saving...';

  @override
  String get completeProfile => 'Complete Profile';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get userProfile => 'User Profile';

  @override
  String get viewAndEditProfile => 'View and edit profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get roleAndLocation => 'Role & Location';

  @override
  String get notSpecified => 'Not specified';

  @override
  String get yourAssignedRole => 'Your assigned role';

  @override
  String get roleRequestedWaitingApproval =>
      'Role requested - waiting for admin approval';

  @override
  String get rolesLoading => 'Loading roles...';

  @override
  String get requestDesiredRole => 'Request desired role';

  @override
  String get roleRequestMustBeApproved =>
      'Your role request must be approved by an admin';

  @override
  String get cropImage => 'Crop Image';

  @override
  String get imageUploadError => 'Error uploading image. Please try again.';

  @override
  String imageProcessingError(String error) {
    return 'Error processing image: $error';
  }

  @override
  String get pleaseSelectCountry => 'Please select your country.';

  @override
  String profileSaveError(String error) {
    return 'Error saving profile: $error';
  }

  @override
  String get plotRegistrationNotPossible => 'Plot registration is not possible';

  @override
  String get deviceHasNoGps =>
      'This device has no GPS, please use another device';

  @override
  String get gpsDisabledMessage =>
      'Please switch on GPS and allow this device to access GPS data';

  @override
  String get enableGpsButton => 'Enable GPS & Permissions';

  @override
  String get openSettingsButton => 'Open Settings';

  @override
  String get registerFarmFarmer => 'Register Farm/Farmer';

  @override
  String get registerFarm => 'Register Farm';

  @override
  String get registerFarmer => 'Register Farmer';

  @override
  String get registerField => 'Register Field';

  @override
  String get recordFieldBoundary => 'Record Field Boundary';

  @override
  String get fieldMustBeLinkedToFarm => 'Field must be linked to a farm';

  @override
  String get noFarmsRegisteredYet => 'No farms registered yet';

  @override
  String get startRecording => 'Start Recording';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get addPoint => 'Add Point';

  @override
  String pointsRecorded(int count) {
    return '$count points recorded';
  }

  @override
  String estimatedArea(String area) {
    return 'Estimated area: $area ha';
  }

  @override
  String get qcPending => 'Pending Approval';

  @override
  String get qcApproved => 'Approved';

  @override
  String get qcRejected => 'Rejected';

  @override
  String get approveRegistration => 'Approve';

  @override
  String get rejectRegistration => 'Reject';

  @override
  String get reviewRegistration => 'Review Registration';

  @override
  String get reviewPendingRegistrations => 'Review Pending Registrations';

  @override
  String get farmerDetails => 'Farmer Details';

  @override
  String get farmDetails => 'Farm Details';

  @override
  String get fieldDetails => 'Field Details';

  @override
  String get nationalID => 'National ID';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get fieldArea => 'Field Area (ha)';

  @override
  String get polygonNotClosed => 'Polygon is not closed';

  @override
  String get minimumPointsRequired => 'At least 3 points required';

  @override
  String get farmerInformation => 'Farmer Information';

  @override
  String get farmInformation => 'Farm Information';

  @override
  String get fieldInformation => 'Field Information';

  @override
  String get reviewAllData => 'Review All Data';

  @override
  String get farmName => 'Farm Name';

  @override
  String get farmAddress => 'Farm Address';

  @override
  String get addAnotherField => 'Add Another Field';

  @override
  String get completeRegistration => 'Complete Registration';

  @override
  String get registrationSuccessful => 'Registration successful';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get gpsRequired => 'GPS must be enabled for registration';

  @override
  String get pleaseEnableGps => 'Please enable GPS to continue';

  @override
  String get waitingForGps => 'Waiting for GPS signal...';

  @override
  String get recordingInProgress => 'Recording in progress...';

  @override
  String get cancelRegistration => 'Leave Registration?';

  @override
  String get cancelRegistrationMessage =>
      'Do you want to leave the field registration?';

  @override
  String get continueRegistration => 'Continue';

  @override
  String get saveAndExit => 'Save and Exit';

  @override
  String get discardData => 'Discard';

  @override
  String get tapToAddPoint => 'Tap button or walk to add points';

  @override
  String minimumDistanceWarning(int meters) {
    return 'Point too close to previous point (min ${meters}m)';
  }

  @override
  String get clearPolygon => 'Clear Polygon';

  @override
  String get undoLastPoint => 'Undo Last Point';

  @override
  String get deletePoint => 'Delete Point?';

  @override
  String deletePointConfirmation(int index) {
    return 'Remove point $index from polygon?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get recordedPoints => 'Recorded Points:';

  @override
  String get current => 'Current';

  @override
  String get accuracy => 'Accuracy';

  @override
  String get closeAutomatically => 'Close automatically?';

  @override
  String get cityName => 'City/Town';

  @override
  String get stateName => 'State/Department';

  @override
  String get noPendingRegistrations => 'No pending registrations';

  @override
  String get registrationApproved => 'Registration approved';

  @override
  String get registrationRejected => 'Registration rejected';

  @override
  String get rejectionReason => 'Rejection Reason';

  @override
  String get approvalNotes => 'Approval Notes';

  @override
  String fieldsCount(int count) {
    return '$count field(s)';
  }

  @override
  String get registeredBy => 'Registered by';

  @override
  String get registrationDate => 'Registration Date';

  @override
  String pendingCount(int count) {
    return '$count pending';
  }

  @override
  String get todaysRegistrations => 'Today\'s Registrations';

  @override
  String get registrarDashboard => 'Registrar Dashboard';

  @override
  String get welcome => 'Welcome';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get todaysStatistics => 'Today\'s Statistics';

  @override
  String get registered => 'Registered';

  @override
  String get verified => 'Verified';

  @override
  String get pending => 'Pending';

  @override
  String get continueOrStartNew => 'Continue or start new?';

  @override
  String get unfinishedFieldRecordings =>
      'There are unfinished field recordings:';

  @override
  String get points => 'points';

  @override
  String get startNewField => 'Start new field';

  @override
  String get pinchToZoom => 'Pinch to zoom, long press to edit';

  @override
  String get point => 'Point';

  @override
  String get optionalNotes =>
      'Optional notes (e.g., checked documents, quality assessment)';

  @override
  String get pleaseProvideReason => 'Please provide a reason for rejection';

  @override
  String get objectNotFound => 'Object not found';

  @override
  String get invalidObjectData => 'Invalid object data';

  @override
  String get errorLoadingDetails => 'Error loading details';

  @override
  String get tapToEnlarge => 'Tap to enlarge';

  @override
  String get tapToEnlargeMap => 'Tap to enlarge map';

  @override
  String get nationalIDPhoto => 'National ID Photo';

  @override
  String get errorLoadingImage => 'Error loading image';

  @override
  String get unnamed => 'Unnamed';

  @override
  String get mapView => 'Map View';

  @override
  String get debugDeleteAllObjects => 'DEBUG: Delete All Displayed Objects';

  @override
  String confirmDeleteAllObjects(int count) {
    return 'Are you sure you want to delete all $count displayed objects? This action cannot be undone!';
  }

  @override
  String objectsDeleted(int count) {
    return '$count object(s) deleted';
  }

  @override
  String get errorDeleting => 'Error deleting';

  @override
  String get uidCopiedToClipboard => 'UID copied to clipboard';

  @override
  String get status => 'Status';

  @override
  String get type => 'Type';

  @override
  String get created => 'Created';

  @override
  String get all => 'All';

  @override
  String get farms => 'Farms';

  @override
  String get farmers => 'Farmers';

  @override
  String get fields => 'Fields';

  @override
  String get totalArea => 'Total Area';

  @override
  String get owner => 'Owner';

  @override
  String get country => 'Country';

  @override
  String get polygonPoints => 'Polygon Points';

  @override
  String get takeIDPhoto => 'Take ID Photo';

  @override
  String get retakeIDPhoto => 'Retake ID Photo';

  @override
  String get farmID => 'Farm ID';

  @override
  String get nationalIDPhotoRequired => 'National ID Photo is required';

  @override
  String get idPhotoTaken => 'ID Photo taken successfully';

  @override
  String get capture => 'Capture';

  @override
  String get errorLoadingUserData =>
      'Error loading user data. Please log out and log in again.';

  @override
  String get gpsSignalExcellent => 'GPS Signal: Excellent';

  @override
  String get gpsSignalGood => 'GPS Signal: Good';

  @override
  String get gpsSignalPoor => 'GPS Signal: Poor';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace Foodchains'**
  String get appTitle;

  /// No description provided for @traceTheFoodchain.
  ///
  /// In en, this message translates to:
  /// **'Trace the Foodchain'**
  String get traceTheFoodchain;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Please select your role!'**
  String get selectRole;

  /// Welcome message with user role
  ///
  /// In en, this message translates to:
  /// **'Welcome, {role}!'**
  String welcomeMessage(String role);

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @farmerActions.
  ///
  /// In en, this message translates to:
  /// **'Farmer Actions'**
  String get farmerActions;

  /// No description provided for @farmManagerActions.
  ///
  /// In en, this message translates to:
  /// **'Farm Manager Actions'**
  String get farmManagerActions;

  /// No description provided for @traderActions.
  ///
  /// In en, this message translates to:
  /// **'Trader Actions'**
  String get traderActions;

  /// No description provided for @transporterActions.
  ///
  /// In en, this message translates to:
  /// **'Transporter Actions'**
  String get transporterActions;

  /// No description provided for @sellerActions.
  ///
  /// In en, this message translates to:
  /// **'Seller Actions'**
  String get sellerActions;

  /// No description provided for @buyerActions.
  ///
  /// In en, this message translates to:
  /// **'Buyer Actions'**
  String get buyerActions;

  /// No description provided for @identifyYourselfOnline.
  ///
  /// In en, this message translates to:
  /// **'Identify Yourself'**
  String get identifyYourselfOnline;

  /// No description provided for @startHarvestOffline.
  ///
  /// In en, this message translates to:
  /// **'Start Harvest'**
  String get startHarvestOffline;

  /// No description provided for @waitingForData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Data...'**
  String get waitingForData;

  /// No description provided for @handOverHarvestToTrader.
  ///
  /// In en, this message translates to:
  /// **'Hand Over Harvest to Trader'**
  String get handOverHarvestToTrader;

  /// No description provided for @scanQrCodeOrNfcTag.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code or NFC Tag'**
  String get scanQrCodeOrNfcTag;

  /// No description provided for @startNewHarvest.
  ///
  /// In en, this message translates to:
  /// **'new Harvest'**
  String get startNewHarvest;

  /// No description provided for @scanTraderTag.
  ///
  /// In en, this message translates to:
  /// **'scan trader tag!'**
  String get scanTraderTag;

  /// No description provided for @scanFarmerTag.
  ///
  /// In en, this message translates to:
  /// **'scan farmer tag!'**
  String get scanFarmerTag;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'unit'**
  String get unit;

  /// No description provided for @changeRole.
  ///
  /// In en, this message translates to:
  /// **'change role'**
  String get changeRole;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'in transit'**
  String get inTransit;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'delivered'**
  String get delivered;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get completed;

  /// No description provided for @statusUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'updated successfully'**
  String get statusUpdatedSuccessfully;

  /// No description provided for @noRole.
  ///
  /// In en, this message translates to:
  /// **'No Role'**
  String get noRole;

  /// No description provided for @roleFarmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get roleFarmer;

  /// No description provided for @roleFarmManager.
  ///
  /// In en, this message translates to:
  /// **'Farm Manager'**
  String get roleFarmManager;

  /// No description provided for @roleTrader.
  ///
  /// In en, this message translates to:
  /// **'Trader'**
  String get roleTrader;

  /// No description provided for @roleTransporter.
  ///
  /// In en, this message translates to:
  /// **'Transporter'**
  String get roleTransporter;

  /// No description provided for @roleProcessor.
  ///
  /// In en, this message translates to:
  /// **'Coffee Processor'**
  String get roleProcessor;

  /// No description provided for @roleImporter.
  ///
  /// In en, this message translates to:
  /// **'EU Importer'**
  String get roleImporter;

  /// No description provided for @activeImports.
  ///
  /// In en, this message translates to:
  /// **'Current Imports'**
  String get activeImports;

  /// No description provided for @noActiveImports.
  ///
  /// In en, this message translates to:
  /// **'No Current Imports'**
  String get noActiveImports;

  /// No description provided for @noActiveItems.
  ///
  /// In en, this message translates to:
  /// **'No stock found'**
  String get noActiveItems;

  /// No description provided for @noImportHistory.
  ///
  /// In en, this message translates to:
  /// **'No Import History'**
  String get noImportHistory;

  /// No description provided for @importHistory.
  ///
  /// In en, this message translates to:
  /// **'Import History'**
  String get importHistory;

  /// No description provided for @roleSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get roleSeller;

  /// No description provided for @roleBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get roleBuyer;

  /// No description provided for @roleSystemAdministrator.
  ///
  /// In en, this message translates to:
  /// **'System Administrator'**
  String get roleSystemAdministrator;

  /// No description provided for @roleDiascaAdmin.
  ///
  /// In en, this message translates to:
  /// **'Diasca Admin'**
  String get roleDiascaAdmin;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Administrator'**
  String get roleSuperAdmin;

  /// No description provided for @roleTfcAdmin.
  ///
  /// In en, this message translates to:
  /// **'TFC Administrator'**
  String get roleTfcAdmin;

  /// No description provided for @roleRegistrarCoordinator.
  ///
  /// In en, this message translates to:
  /// **'Registrar Coordinator'**
  String get roleRegistrarCoordinator;

  /// No description provided for @roleVerificationAuthority.
  ///
  /// In en, this message translates to:
  /// **'Verification Authority'**
  String get roleVerificationAuthority;

  /// No description provided for @roleAssignedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Role assigned successfully'**
  String get roleAssignedSuccessfully;

  /// No description provided for @errorAssigningRole.
  ///
  /// In en, this message translates to:
  /// **'Error assigning role'**
  String get errorAssigningRole;

  /// No description provided for @userManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// No description provided for @userManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage and assign user roles'**
  String get userManagementSubtitle;

  /// No description provided for @noPermissionForUserManagement.
  ///
  /// In en, this message translates to:
  /// **'No permission for user management'**
  String get noPermissionForUserManagement;

  /// No description provided for @userManagementOnlineOnly.
  ///
  /// In en, this message translates to:
  /// **'User management is only available online'**
  String get userManagementOnlineOnly;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @assignRole.
  ///
  /// In en, this message translates to:
  /// **'Assign Role'**
  String get assignRole;

  /// No description provided for @currentRole.
  ///
  /// In en, this message translates to:
  /// **'Current Role'**
  String get currentRole;

  /// No description provided for @newRole.
  ///
  /// In en, this message translates to:
  /// **'New Role'**
  String get newRole;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @enterReasonForRoleChange.
  ///
  /// In en, this message translates to:
  /// **'Enter reason for role change'**
  String get enterReasonForRoleChange;

  /// No description provided for @enterReason.
  ///
  /// In en, this message translates to:
  /// **'Enter reason for role change'**
  String get enterReason;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @userDetails.
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get userDetails;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @userID.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userID;

  /// No description provided for @manageable.
  ///
  /// In en, this message translates to:
  /// **'Manageable'**
  String get manageable;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @roleManagementDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'Role Management Debug Info'**
  String get roleManagementDebugInfo;

  /// No description provided for @firestoreError.
  ///
  /// In en, this message translates to:
  /// **'Firestore Error'**
  String get firestoreError;

  /// No description provided for @appUserDocRepairedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'appUserDoc successfully repaired'**
  String get appUserDocRepairedSuccessfully;

  /// No description provided for @repairFailed.
  ///
  /// In en, this message translates to:
  /// **'Repair failed'**
  String get repairFailed;

  /// No description provided for @repairAppUserDoc.
  ///
  /// In en, this message translates to:
  /// **'Repair appUserDoc'**
  String get repairAppUserDoc;

  /// No description provided for @notManageable.
  ///
  /// In en, this message translates to:
  /// **'Not manageable'**
  String get notManageable;

  /// No description provided for @possibleReasons.
  ///
  /// In en, this message translates to:
  /// **'Possible reasons:\n• No manageable users found\n• Filter too restrictive\n• Missing permissions'**
  String get possibleReasons;

  /// No description provided for @noAvailableRolesForPermission.
  ///
  /// In en, this message translates to:
  /// **'No available roles for your permission'**
  String get noAvailableRolesForPermission;

  /// No description provided for @usersCount.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total} users'**
  String usersCount(int filtered, int total);

  /// No description provided for @showUserDetails.
  ///
  /// In en, this message translates to:
  /// **'Show user details'**
  String get showUserDetails;

  /// No description provided for @editRole.
  ///
  /// In en, this message translates to:
  /// **'Edit role'**
  String get editRole;

  /// No description provided for @superadminSecurityError.
  ///
  /// In en, this message translates to:
  /// **'SECURITY ERROR: SUPERADMIN roles cannot be changed'**
  String get superadminSecurityError;

  /// No description provided for @superadminSecurityInfo.
  ///
  /// In en, this message translates to:
  /// **'SUPERADMIN users are protected by security policies'**
  String get superadminSecurityInfo;

  /// No description provided for @superadminCannotBeAssigned.
  ///
  /// In en, this message translates to:
  /// **'SUPERADMIN role cannot be assigned'**
  String get superadminCannotBeAssigned;

  /// No description provided for @superadminCannotBeChanged.
  ///
  /// In en, this message translates to:
  /// **'SUPERADMIN role cannot be changed'**
  String get superadminCannotBeChanged;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search Users'**
  String get searchUsers;

  /// No description provided for @filterByRole.
  ///
  /// In en, this message translates to:
  /// **'Filter by Role'**
  String get filterByRole;

  /// No description provided for @allRoles.
  ///
  /// In en, this message translates to:
  /// **'All Roles'**
  String get allRoles;

  /// No description provided for @roleSuccessfullyAssigned.
  ///
  /// In en, this message translates to:
  /// **'Role successfully assigned'**
  String get roleSuccessfullyAssigned;

  /// No description provided for @errorWhileAssigningRole.
  ///
  /// In en, this message translates to:
  /// **'Error while assigning role'**
  String get errorWhileAssigningRole;

  /// No description provided for @reasonForRoleChange.
  ///
  /// In en, this message translates to:
  /// **'Reason for role change'**
  String get reasonForRoleChange;

  /// No description provided for @enterNewFarmerID.
  ///
  /// In en, this message translates to:
  /// **'Enter new Farmer ID'**
  String get enterNewFarmerID;

  /// No description provided for @enterNewFarmID.
  ///
  /// In en, this message translates to:
  /// **'Enter new Farm ID'**
  String get enterNewFarmID;

  /// Displays the scanned QR code or NFC tag
  ///
  /// In en, this message translates to:
  /// **'Scanned Code: {code}'**
  String scannedCode(String code);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @errorIncorrectData.
  ///
  /// In en, this message translates to:
  /// **'ERROR: The received data are not valid!'**
  String get errorIncorrectData;

  /// No description provided for @provideValidSellerTag.
  ///
  /// In en, this message translates to:
  /// **'Please provide a valid seller tag.'**
  String get provideValidSellerTag;

  /// No description provided for @confirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Did the buyer receive the information correctly?'**
  String get confirmTransfer;

  /// No description provided for @peerTransfer.
  ///
  /// In en, this message translates to:
  /// **'Peer Transfer'**
  String get peerTransfer;

  /// No description provided for @generateTransferData.
  ///
  /// In en, this message translates to:
  /// **'Generate Transfer Data'**
  String get generateTransferData;

  /// No description provided for @startScanning.
  ///
  /// In en, this message translates to:
  /// **'Start Scanning'**
  String get startScanning;

  /// No description provided for @stopScanning.
  ///
  /// In en, this message translates to:
  /// **'Stop Scanning'**
  String get stopScanning;

  /// No description provided for @startPresenting.
  ///
  /// In en, this message translates to:
  /// **'Start Presenting'**
  String get startPresenting;

  /// No description provided for @stopPresenting.
  ///
  /// In en, this message translates to:
  /// **'Stop Presenting'**
  String get stopPresenting;

  /// No description provided for @transferDataGenerated.
  ///
  /// In en, this message translates to:
  /// **'Transfer Data Generated'**
  String get transferDataGenerated;

  /// No description provided for @dataReceived.
  ///
  /// In en, this message translates to:
  /// **'Data Received'**
  String get dataReceived;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @feedbackEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Feedback for TraceFoodchain App'**
  String get feedbackEmailSubject;

  /// No description provided for @feedbackEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Please enter your feedback here:'**
  String get feedbackEmailBody;

  /// No description provided for @unableToLaunchEmail.
  ///
  /// In en, this message translates to:
  /// **'Unable to launch email client'**
  String get unableToLaunchEmail;

  /// No description provided for @activeItems.
  ///
  /// In en, this message translates to:
  /// **'Active Items'**
  String get activeItems;

  /// No description provided for @pastItems.
  ///
  /// In en, this message translates to:
  /// **'Past Items'**
  String get pastItems;

  /// No description provided for @changeFarmerId.
  ///
  /// In en, this message translates to:
  /// **'Change Farmer ID'**
  String get changeFarmerId;

  /// No description provided for @associateWithDifferentFarm.
  ///
  /// In en, this message translates to:
  /// **'Associate with a Different Farm'**
  String get associateWithDifferentFarm;

  /// No description provided for @manageFarmEmployees.
  ///
  /// In en, this message translates to:
  /// **'Manage Farm Employees'**
  String get manageFarmEmployees;

  /// No description provided for @manageHarvests.
  ///
  /// In en, this message translates to:
  /// **'Manage Harvests'**
  String get manageHarvests;

  /// No description provided for @manageContainers.
  ///
  /// In en, this message translates to:
  /// **'Manage Containers'**
  String get manageContainers;

  /// No description provided for @buyHarvest.
  ///
  /// In en, this message translates to:
  /// **'Buy Harvest'**
  String get buyHarvest;

  /// No description provided for @sellHarvest.
  ///
  /// In en, this message translates to:
  /// **'Sell Harvest'**
  String get sellHarvest;

  /// No description provided for @manageInventory.
  ///
  /// In en, this message translates to:
  /// **'Manage Inventory'**
  String get manageInventory;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add Employee'**
  String get addEmployee;

  /// No description provided for @editEmployee.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get editEmployee;

  /// No description provided for @addHarvest.
  ///
  /// In en, this message translates to:
  /// **'Add Harvest'**
  String get addHarvest;

  /// No description provided for @harvestDetails.
  ///
  /// In en, this message translates to:
  /// **'Harvest Details'**
  String get harvestDetails;

  /// No description provided for @addContainer.
  ///
  /// In en, this message translates to:
  /// **'Add Container'**
  String get addContainer;

  /// No description provided for @containerQRCode.
  ///
  /// In en, this message translates to:
  /// **'Container QR Code'**
  String get containerQRCode;

  /// No description provided for @notImplementedYet.
  ///
  /// In en, this message translates to:
  /// **'This functionality is not implemented yet'**
  String get notImplementedYet;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input. Please enter valid numbers.'**
  String get invalidInput;

  /// No description provided for @editInventoryItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Inventory Item'**
  String get editInventoryItem;

  /// No description provided for @filterByCropType.
  ///
  /// In en, this message translates to:
  /// **'Filter by crop type'**
  String get filterByCropType;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @cropType.
  ///
  /// In en, this message translates to:
  /// **'Crop Type'**
  String get cropType;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @activeDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Active Deliveries'**
  String get activeDeliveries;

  /// No description provided for @deliveryHistory.
  ///
  /// In en, this message translates to:
  /// **'Delivery History'**
  String get deliveryHistory;

  /// No description provided for @updateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Status'**
  String get updateStatus;

  /// No description provided for @updateDeliveryStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Delivery Status'**
  String get updateDeliveryStatus;

  /// No description provided for @noDeliveryHistory.
  ///
  /// In en, this message translates to:
  /// **'No delivery history'**
  String get noDeliveryHistory;

  /// No description provided for @noActiveDeliveries.
  ///
  /// In en, this message translates to:
  /// **'No active deliveries'**
  String get noActiveDeliveries;

  /// No description provided for @listProducts.
  ///
  /// In en, this message translates to:
  /// **'List Products'**
  String get listProducts;

  /// No description provided for @manageOrders.
  ///
  /// In en, this message translates to:
  /// **'Manage Orders'**
  String get manageOrders;

  /// No description provided for @salesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get salesHistory;

  /// No description provided for @goToActions.
  ///
  /// In en, this message translates to:
  /// **'Go to Actions'**
  String get goToActions;

  /// No description provided for @setPrice.
  ///
  /// In en, this message translates to:
  /// **'Set Price'**
  String get setPrice;

  /// No description provided for @browseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get browseProducts;

  /// No description provided for @orderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistory;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @syncData.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get syncData;

  /// No description provided for @startSync.
  ///
  /// In en, this message translates to:
  /// **'Start Sync'**
  String get startSync;

  /// No description provided for @syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data synchronized successfully'**
  String get syncSuccess;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Error synchronizing data'**
  String get syncError;

  /// No description provided for @nfcNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'NFC not available'**
  String get nfcNotAvailable;

  /// No description provided for @scanningForNfcTags.
  ///
  /// In en, this message translates to:
  /// **'Scanning for NFC tags'**
  String get scanningForNfcTags;

  /// No description provided for @nfcScanStopped.
  ///
  /// In en, this message translates to:
  /// **'NFC scan stopped'**
  String get nfcScanStopped;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrCode;

  /// No description provided for @nfcTag.
  ///
  /// In en, this message translates to:
  /// **'NFC tag'**
  String get nfcTag;

  /// No description provided for @nfcScanError.
  ///
  /// In en, this message translates to:
  /// **'Error during NFC scan'**
  String get nfcScanError;

  /// No description provided for @multiTagFoundIOS.
  ///
  /// In en, this message translates to:
  /// **'Multiple tags found!'**
  String get multiTagFoundIOS;

  /// No description provided for @scanInfoMessageIOS.
  ///
  /// In en, this message translates to:
  /// **'Scan your tag'**
  String get scanInfoMessageIOS;

  /// No description provided for @addEmptyItem.
  ///
  /// In en, this message translates to:
  /// **'Add Empty Item'**
  String get addEmptyItem;

  /// No description provided for @maxCapacity.
  ///
  /// In en, this message translates to:
  /// **'Maximum Capacity'**
  String get maxCapacity;

  /// No description provided for @uid.
  ///
  /// In en, this message translates to:
  /// **'UID'**
  String get uid;

  /// No description provided for @bag.
  ///
  /// In en, this message translates to:
  /// **'Bag'**
  String get bag;

  /// No description provided for @container.
  ///
  /// In en, this message translates to:
  /// **'Container'**
  String get container;

  /// No description provided for @building.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get building;

  /// No description provided for @transportVehicle.
  ///
  /// In en, this message translates to:
  /// **'Transport Vehicle'**
  String get transportVehicle;

  /// No description provided for @pleaseCompleteAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete all fields'**
  String get pleaseCompleteAllFields;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get invalidNumber;

  /// No description provided for @geolocation.
  ///
  /// In en, this message translates to:
  /// **'Geolocation'**
  String get geolocation;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Error getting location'**
  String get locationError;

  /// No description provided for @invalidLatitude.
  ///
  /// In en, this message translates to:
  /// **'Invalid latitude'**
  String get invalidLatitude;

  /// No description provided for @invalidLongitude.
  ///
  /// In en, this message translates to:
  /// **'Invalid longitude'**
  String get invalidLongitude;

  /// No description provided for @sellOnline.
  ///
  /// In en, this message translates to:
  /// **'Sell Online'**
  String get sellOnline;

  /// No description provided for @recipientEmail.
  ///
  /// In en, this message translates to:
  /// **'Email of recipient'**
  String get recipientEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @saleCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sale completed successfully'**
  String get saleCompleted;

  /// No description provided for @saleError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during the sale'**
  String get saleError;

  /// No description provided for @newTransferNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'New Transfer'**
  String get newTransferNotificationTitle;

  /// No description provided for @newTransferNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'You have received a new item transfer'**
  String get newTransferNotificationBody;

  /// No description provided for @coffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get coffee;

  /// No description provided for @amount2.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount2;

  /// No description provided for @speciesLabel.
  ///
  /// In en, this message translates to:
  /// **'Species: {species}'**
  String speciesLabel(String species);

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'{value} {unit}'**
  String amount(String value, String unit);

  /// No description provided for @processingStep.
  ///
  /// In en, this message translates to:
  /// **'{step}'**
  String processingStep(String step);

  /// No description provided for @boughtOn.
  ///
  /// In en, this message translates to:
  /// **'Bought on: {date}'**
  String boughtOn(String date);

  /// No description provided for @fromPlot.
  ///
  /// In en, this message translates to:
  /// **'From plot: {plotId}'**
  String fromPlot(String plotId);

  /// No description provided for @noPlotFound.
  ///
  /// In en, this message translates to:
  /// **'No plot found'**
  String get noPlotFound;

  /// No description provided for @errorWithParam.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithParam(String error);

  /// No description provided for @loadingData.
  ///
  /// In en, this message translates to:
  /// **'Loading data...'**
  String get loadingData;

  /// No description provided for @pdfGenerationError.
  ///
  /// In en, this message translates to:
  /// **'Error generating PDF'**
  String get pdfGenerationError;

  /// No description provided for @containerIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'{containerType} {id} is empty'**
  String containerIsEmpty(String containerType, String id);

  /// No description provided for @idWithBrackets.
  ///
  /// In en, this message translates to:
  /// **'(ID: {id})'**
  String idWithBrackets(String id);

  /// No description provided for @buyCoffee.
  ///
  /// In en, this message translates to:
  /// **'Buy coffee'**
  String get buyCoffee;

  /// No description provided for @sellOffline.
  ///
  /// In en, this message translates to:
  /// **'Sell offline'**
  String get sellOffline;

  /// No description provided for @changeProcessingState.
  ///
  /// In en, this message translates to:
  /// **'Change processing/quality state'**
  String get changeProcessingState;

  /// No description provided for @changeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get changeLocation;

  /// No description provided for @selectQualityCriteria.
  ///
  /// In en, this message translates to:
  /// **'Select quality criteria'**
  String get selectQualityCriteria;

  /// No description provided for @selectProcessingState.
  ///
  /// In en, this message translates to:
  /// **'Select processing state'**
  String get selectProcessingState;

  /// No description provided for @pdfError.
  ///
  /// In en, this message translates to:
  /// **'PDF error: {error}'**
  String pdfError(String error);

  /// No description provided for @errorSendingEmailWithError.
  ///
  /// In en, this message translates to:
  /// **'Error sending email'**
  String get errorSendingEmailWithError;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email!'**
  String get resendEmail;

  /// No description provided for @waitingForEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for email verification. Please check your inbox and confirm your email.'**
  String get waitingForEmailVerification;

  /// No description provided for @emailVerification.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get emailVerification;

  /// No description provided for @securityError.
  ///
  /// In en, this message translates to:
  /// **'Security error'**
  String get securityError;

  /// No description provided for @securityErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not generate the setup for digital signage. Please try again later making sure you have internet connection.'**
  String get securityErrorMessage;

  /// No description provided for @closeApp.
  ///
  /// In en, this message translates to:
  /// **'Close App'**
  String get closeApp;

  /// No description provided for @uidAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This ID already exists, please chose another one'**
  String get uidAlreadyExists;

  /// No description provided for @selectItemToSell.
  ///
  /// In en, this message translates to:
  /// **'Please select an item to sell'**
  String get selectItemToSell;

  /// No description provided for @debugDeleteContainer.
  ///
  /// In en, this message translates to:
  /// **'Delete container (Debug)'**
  String get debugDeleteContainer;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @generateDDS.
  ///
  /// In en, this message translates to:
  /// **'Generate DDS'**
  String get generateDDS;

  /// No description provided for @ddsGenerationDemo.
  ///
  /// In en, this message translates to:
  /// **'DDS generation is only available in demo mode'**
  String get ddsGenerationDemo;

  /// No description provided for @sampleOperator.
  ///
  /// In en, this message translates to:
  /// **'Sample Operator'**
  String get sampleOperator;

  /// No description provided for @sampleAddress.
  ///
  /// In en, this message translates to:
  /// **'Sample Address'**
  String get sampleAddress;

  /// No description provided for @sampleEori.
  ///
  /// In en, this message translates to:
  /// **'Sample EORI'**
  String get sampleEori;

  /// No description provided for @sampleHsCode.
  ///
  /// In en, this message translates to:
  /// **'Sample HS Code'**
  String get sampleHsCode;

  /// No description provided for @sampleDescription.
  ///
  /// In en, this message translates to:
  /// **'Sample Description'**
  String get sampleDescription;

  /// No description provided for @sampleTradeName.
  ///
  /// In en, this message translates to:
  /// **'Sample Trade Name'**
  String get sampleTradeName;

  /// No description provided for @sampleScientificName.
  ///
  /// In en, this message translates to:
  /// **'Sample Scientific Name'**
  String get sampleScientificName;

  /// No description provided for @sampleQuantity.
  ///
  /// In en, this message translates to:
  /// **'Sample Quantity'**
  String get sampleQuantity;

  /// No description provided for @sampleCountry.
  ///
  /// In en, this message translates to:
  /// **'Sample Country'**
  String get sampleCountry;

  /// No description provided for @sampleName.
  ///
  /// In en, this message translates to:
  /// **'Sample Name'**
  String get sampleName;

  /// No description provided for @sampleFunction.
  ///
  /// In en, this message translates to:
  /// **'Sample Function'**
  String get sampleFunction;

  /// No description provided for @scanQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCode;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @welcomeToApp.
  ///
  /// In en, this message translates to:
  /// **'Welcome to TraceFoodChain'**
  String get welcomeToApp;

  /// No description provided for @signInMessage.
  ///
  /// In en, this message translates to:
  /// **'Please sign in or sign up to ensure the security and integrity of our food chain tracking system.'**
  String get signInMessage;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @signInSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Sign Up'**
  String get signInSignUp;

  /// No description provided for @helpButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Help'**
  String get helpButtonTooltip;

  /// No description provided for @errorOpeningUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not open help page'**
  String get errorOpeningUrl;

  /// No description provided for @weakPasswordError.
  ///
  /// In en, this message translates to:
  /// **'The password provided is too weak.'**
  String get weakPasswordError;

  /// No description provided for @emailAlreadyInUseError.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for that email.'**
  String get emailAlreadyInUseError;

  /// No description provided for @invalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'The email address is not valid.'**
  String get invalidEmailError;

  /// No description provided for @userDisabledError.
  ///
  /// In en, this message translates to:
  /// **'This user has been disabled.'**
  String get userDisabledError;

  /// No description provided for @wrongPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Wrong password provided for that user.'**
  String get wrongPasswordError;

  /// No description provided for @undefinedError.
  ///
  /// In en, this message translates to:
  /// **'An undefined error happened.'**
  String get undefinedError;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @aggregateItems.
  ///
  /// In en, this message translates to:
  /// **'Aggregate items'**
  String get aggregateItems;

  /// No description provided for @addNewEmptyItem.
  ///
  /// In en, this message translates to:
  /// **'Add new empty item'**
  String get addNewEmptyItem;

  /// No description provided for @selectBuyCoffeeOption.
  ///
  /// In en, this message translates to:
  /// **'Select Buy Coffee Option'**
  String get selectBuyCoffeeOption;

  /// No description provided for @selectSellCoffeeOption.
  ///
  /// In en, this message translates to:
  /// **'Select Sell Coffee Option'**
  String get selectSellCoffeeOption;

  /// No description provided for @deviceToCloud.
  ///
  /// In en, this message translates to:
  /// **'Device-to-cloud'**
  String get deviceToCloud;

  /// No description provided for @deviceToDevice.
  ///
  /// In en, this message translates to:
  /// **'Device-to-device'**
  String get deviceToDevice;

  /// No description provided for @ciatFirstSale.
  ///
  /// In en, this message translates to:
  /// **'CIAT first sale'**
  String get ciatFirstSale;

  /// No description provided for @buyCoffeeDeviceToDevice.
  ///
  /// In en, this message translates to:
  /// **'Buy Coffee (device-to-device)'**
  String get buyCoffeeDeviceToDevice;

  /// No description provided for @scanSelectFutureContainer.
  ///
  /// In en, this message translates to:
  /// **'Scan/select target container'**
  String get scanSelectFutureContainer;

  /// No description provided for @scanContainerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Use QR-Code/NFC or select manually to specify where the coffee will be stored.'**
  String get scanContainerInstructions;

  /// No description provided for @presentInfoToSeller.
  ///
  /// In en, this message translates to:
  /// **'Present information to seller'**
  String get presentInfoToSeller;

  /// No description provided for @presentInfoToSellerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Show the QR code or NFC tag to the seller to initiate the transaction.'**
  String get presentInfoToSellerInstructions;

  /// No description provided for @receiveDataFromSeller.
  ///
  /// In en, this message translates to:
  /// **'Receive data from seller'**
  String get receiveDataFromSeller;

  /// No description provided for @receiveDataFromSellerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code or NFC tag from the seller\'s device to complete the transaction.'**
  String get receiveDataFromSellerInstructions;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'PRESENT'**
  String get present;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'RECEIVE'**
  String get receive;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get next;

  /// No description provided for @buyCoffeeCiatFirstSale.
  ///
  /// In en, this message translates to:
  /// **'Buy Coffee (CIAT First Sale)'**
  String get buyCoffeeCiatFirstSale;

  /// No description provided for @scanSellerTag.
  ///
  /// In en, this message translates to:
  /// **'Scan tag provided by seller'**
  String get scanSellerTag;

  /// No description provided for @scanSellerTagInstructions.
  ///
  /// In en, this message translates to:
  /// **'Use QR-Code or NFC from seller to specify the coffee that you are about to buy.'**
  String get scanSellerTagInstructions;

  /// No description provided for @enterCoffeeInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter coffee information'**
  String get enterCoffeeInfo;

  /// No description provided for @enterCoffeeInfoInstructions.
  ///
  /// In en, this message translates to:
  /// **'Provide details about the coffee being purchased.'**
  String get enterCoffeeInfoInstructions;

  /// No description provided for @scanReceivingContainer.
  ///
  /// In en, this message translates to:
  /// **'Scan tag of the receiving container (sack, storage, building, truck...)'**
  String get scanReceivingContainer;

  /// No description provided for @scanReceivingContainerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Specify where the coffee is transferred to.'**
  String get scanReceivingContainerInstructions;

  /// No description provided for @coffeeInformation.
  ///
  /// In en, this message translates to:
  /// **'Coffee Information'**
  String get coffeeInformation;

  /// No description provided for @countryOfOrigin.
  ///
  /// In en, this message translates to:
  /// **'Country of Origin'**
  String get countryOfOrigin;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountry;

  /// No description provided for @selectSpecies.
  ///
  /// In en, this message translates to:
  /// **'Select Species'**
  String get selectSpecies;

  /// No description provided for @enterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity'**
  String get enterQuantity;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'START!'**
  String get start;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'SCAN!'**
  String get scan;

  /// No description provided for @species.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get species;

  /// No description provided for @processingState.
  ///
  /// In en, this message translates to:
  /// **'Processing State'**
  String get processingState;

  /// No description provided for @qualityReductionCriteria.
  ///
  /// In en, this message translates to:
  /// **'Quality Reduction Criteria'**
  String get qualityReductionCriteria;

  /// No description provided for @sellCoffeeDeviceToDevice.
  ///
  /// In en, this message translates to:
  /// **'Sell Coffee (device-to-device)'**
  String get sellCoffeeDeviceToDevice;

  /// No description provided for @scanBuyerInfo.
  ///
  /// In en, this message translates to:
  /// **'Scan information provided by buyer'**
  String get scanBuyerInfo;

  /// No description provided for @scanBuyerInfoInstructions.
  ///
  /// In en, this message translates to:
  /// **'Use your smartphone camera or NFC to read initial information from buyer'**
  String get scanBuyerInfoInstructions;

  /// No description provided for @presentInfoToBuyer.
  ///
  /// In en, this message translates to:
  /// **'Present information to the buyer to finish sale'**
  String get presentInfoToBuyer;

  /// No description provided for @presentInfoToBuyerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Specify where the coffee is transferred to.'**
  String get presentInfoToBuyerInstructions;

  /// No description provided for @selectFromDatabase.
  ///
  /// In en, this message translates to:
  /// **'Select from database'**
  String get selectFromDatabase;

  /// No description provided for @notSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced to cloud'**
  String get notSynced;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced with cloud'**
  String get synced;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @fillInReminder.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields correctly'**
  String get fillInReminder;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get manual;

  /// No description provided for @selectCountryFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select country first!'**
  String get selectCountryFirst;

  /// No description provided for @inputOfAdditionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Input of additional information is mandatory!'**
  String get inputOfAdditionalInformation;

  /// No description provided for @provideValidContainer.
  ///
  /// In en, this message translates to:
  /// **'Please provide a valid receiving container tag.'**
  String get provideValidContainer;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get buttonNext;

  /// No description provided for @buttonScan.
  ///
  /// In en, this message translates to:
  /// **'SCAN!'**
  String get buttonScan;

  /// No description provided for @buttonStart.
  ///
  /// In en, this message translates to:
  /// **'START!'**
  String get buttonStart;

  /// No description provided for @buttonBack.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get buttonBack;

  /// No description provided for @locationPermissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied'**
  String get locationPermissionsDenied;

  /// No description provided for @locationPermissionsPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied'**
  String get locationPermissionsPermanentlyDenied;

  /// No description provided for @errorSyncToCloud.
  ///
  /// In en, this message translates to:
  /// **'Error syncing data to cloud'**
  String get errorSyncToCloud;

  /// No description provided for @errorBadRequest.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Bad Request - Invalid data or incorrect digital signature'**
  String get errorBadRequest;

  /// No description provided for @errorMergeConflict.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Merge Conflict - Data exists in different versions'**
  String get errorMergeConflict;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Service Unavailable'**
  String get errorServiceUnavailable;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Unauthorized'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Forbidden'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Not Found'**
  String get errorNotFound;

  /// No description provided for @errorInternalServerError.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Internal Server Error'**
  String get errorInternalServerError;

  /// No description provided for @errorGatewayTimeout.
  ///
  /// In en, this message translates to:
  /// **'Server Error: Gateway Timeout'**
  String get errorGatewayTimeout;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get errorUnknown;

  /// No description provided for @errorNoCloudConnectionProperties.
  ///
  /// In en, this message translates to:
  /// **'No cloud connection properties found'**
  String get errorNoCloudConnectionProperties;

  /// No description provided for @syncToCloudSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Sync to cloud successful'**
  String get syncToCloudSuccessful;

  /// No description provided for @testModeActive.
  ///
  /// In en, this message translates to:
  /// **'Test mode active'**
  String get testModeActive;

  /// No description provided for @dataMode.
  ///
  /// In en, this message translates to:
  /// **'Data mode'**
  String get dataMode;

  /// No description provided for @testMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode'**
  String get testMode;

  /// No description provided for @realMode.
  ///
  /// In en, this message translates to:
  /// **'Production mode'**
  String get realMode;

  /// No description provided for @nologoutpossible.
  ///
  /// In en, this message translates to:
  /// **'Logout only possible when connected to the internet'**
  String get nologoutpossible;

  /// No description provided for @manuallySyncingWith.
  ///
  /// In en, this message translates to:
  /// **'Manually syncing with'**
  String get manuallySyncingWith;

  /// No description provided for @syncingWith.
  ///
  /// In en, this message translates to:
  /// **'Syncing with'**
  String get syncingWith;

  /// No description provided for @newKeypairNeeded.
  ///
  /// In en, this message translates to:
  /// **'No private key found - generating new keypair...'**
  String get newKeypairNeeded;

  /// No description provided for @failedToInitializeKeyManagement.
  ///
  /// In en, this message translates to:
  /// **'WARNING: Failed to initialize key management!'**
  String get failedToInitializeKeyManagement;

  /// No description provided for @newUserProfileNeeded.
  ///
  /// In en, this message translates to:
  /// **'User profile not found in local database - creating new one...'**
  String get newUserProfileNeeded;

  /// No description provided for @coffeeIsBought.
  ///
  /// In en, this message translates to:
  /// **'Coffee is bought'**
  String get coffeeIsBought;

  /// No description provided for @coffeeIsSold.
  ///
  /// In en, this message translates to:
  /// **'Coffee is sold'**
  String get coffeeIsSold;

  /// No description provided for @generatingItem.
  ///
  /// In en, this message translates to:
  /// **'Generating item...'**
  String get generatingItem;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing data...'**
  String get processing;

  /// No description provided for @setItemName.
  ///
  /// In en, this message translates to:
  /// **'Set item name'**
  String get setItemName;

  /// No description provided for @unnamedObject.
  ///
  /// In en, this message translates to:
  /// **'Unnamed object'**
  String get unnamedObject;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get capacity;

  /// No description provided for @freeCapacity.
  ///
  /// In en, this message translates to:
  /// **'Free capacity'**
  String get freeCapacity;

  /// No description provided for @selectContainerForItems.
  ///
  /// In en, this message translates to:
  /// **'Select container for items'**
  String get selectContainerForItems;

  /// No description provided for @selectContainer.
  ///
  /// In en, this message translates to:
  /// **'Select container'**
  String get selectContainer;

  /// No description provided for @enterUIDhere.
  ///
  /// In en, this message translates to:
  /// **'Enter UID here'**
  String get enterUIDhere;

  /// No description provided for @excelFileDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Excel file downloaded'**
  String get excelFileDownloaded;

  /// No description provided for @excelFileSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Excel file saved at'**
  String get excelFileSavedAt;

  /// No description provided for @failedToGenerateExcelFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate Excel file'**
  String get failedToGenerateExcelFile;

  /// No description provided for @exportToExcel.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportToExcel;

  /// No description provided for @resetPasswordEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Reset password email sent'**
  String get resetPasswordEmailSent;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @weightEquivalentGreenBeanKg.
  ///
  /// In en, this message translates to:
  /// **'weight equivalent in kg green beans'**
  String get weightEquivalentGreenBeanKg;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @pleaseEnterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter email and password'**
  String get pleaseEnterEmailAndPassword;

  /// No description provided for @loggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get loggingIn;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @gettingAuthorityToken.
  ///
  /// In en, this message translates to:
  /// **'Getting authority token...'**
  String get gettingAuthorityToken;

  /// No description provided for @fieldRegistry.
  ///
  /// In en, this message translates to:
  /// **'Field Registry'**
  String get fieldRegistry;

  /// No description provided for @fieldRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'Registered Fields'**
  String get fieldRegistryTitle;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Field Name'**
  String get fieldName;

  /// No description provided for @geoId.
  ///
  /// In en, this message translates to:
  /// **'Geo ID'**
  String get geoId;

  /// No description provided for @area.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get area;

  /// No description provided for @registerNewFields.
  ///
  /// In en, this message translates to:
  /// **'Register New Fields'**
  String get registerNewFields;

  /// No description provided for @uploadCsv.
  ///
  /// In en, this message translates to:
  /// **'Upload CSV'**
  String get uploadCsv;

  /// No description provided for @selectCsvFile.
  ///
  /// In en, this message translates to:
  /// **'Select CSV File'**
  String get selectCsvFile;

  /// No description provided for @csvUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'CSV uploaded successfully'**
  String get csvUploadSuccess;

  /// No description provided for @csvUploadError.
  ///
  /// In en, this message translates to:
  /// **'Error uploading CSV'**
  String get csvUploadError;

  /// No description provided for @registering.
  ///
  /// In en, this message translates to:
  /// **'Registering...'**
  String get registering;

  /// No description provided for @registrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Registration complete'**
  String get registrationComplete;

  /// No description provided for @registrationError.
  ///
  /// In en, this message translates to:
  /// **'Registration error'**
  String get registrationError;

  /// No description provided for @fieldAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Field already exists'**
  String get fieldAlreadyExists;

  /// No description provided for @noFieldsRegistered.
  ///
  /// In en, this message translates to:
  /// **'No fields registered'**
  String get noFieldsRegistered;

  /// No description provided for @csvFormatInfo.
  ///
  /// In en, this message translates to:
  /// **'CSV Format: Name, Description, Coordinates'**
  String get csvFormatInfo;

  /// No description provided for @invalidCsvFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid CSV format'**
  String get invalidCsvFormat;

  /// No description provided for @fieldRegisteredSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Field registered successfully'**
  String get fieldRegisteredSuccessfully;

  /// No description provided for @progressStep1InitializingServices.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Initializing services...'**
  String get progressStep1InitializingServices;

  /// No description provided for @progressStep1UserRegistryLogin.
  ///
  /// In en, this message translates to:
  /// **'Step 1: User Registry login...'**
  String get progressStep1UserRegistryLogin;

  /// No description provided for @progressStep2RegisteringField.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Registering field with Asset Registry...'**
  String get progressStep2RegisteringField;

  /// No description provided for @progressStep2FieldRegisteredSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Field successfully registered, extracting GeoID...'**
  String get progressStep2FieldRegisteredSuccessfully;

  /// No description provided for @progressStep2FieldAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Field already exists, extracting GeoID...'**
  String get progressStep2FieldAlreadyExists;

  /// No description provided for @progressStep3CheckingCentralDatabase.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Checking central database (GeoID: {geoId})...'**
  String progressStep3CheckingCentralDatabase(String geoId);

  /// No description provided for @progressStep3FieldNotFoundInCentralDb.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Field not found in central database - proceeding with local registration...'**
  String get progressStep3FieldNotFoundInCentralDb;

  /// No description provided for @processingCsvFile.
  ///
  /// In en, this message translates to:
  /// **'Processing CSV file...'**
  String get processingCsvFile;

  /// No description provided for @fieldRegistrationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Field registration in progress...'**
  String get fieldRegistrationInProgress;

  /// No description provided for @fieldXOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Field {current} of {total}'**
  String fieldXOfTotal(String current, String total);

  /// No description provided for @currentField.
  ///
  /// In en, this message translates to:
  /// **'Current field: {fieldName}'**
  String currentField(String fieldName);

  /// No description provided for @fieldRegistrationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'✅ Field \"{fieldName}\" successfully registered!'**
  String fieldRegistrationSuccessMessage(String fieldName);

  /// No description provided for @fieldRegistrationErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'❌ Error with \"{fieldName}\": {error}'**
  String fieldRegistrationErrorMessage(String fieldName, String error);

  /// Message when field already exists and GeoID was successfully extracted
  ///
  /// In en, this message translates to:
  /// **'✅ Field already exists - GeoID successfully extracted: {geoId}'**
  String fieldAlreadyExistsGeoIdExtracted(String geoId);

  /// Message when field already exists but GeoID extraction failed
  ///
  /// In en, this message translates to:
  /// **'⚠️ Field already exists - Failed to extract GeoID: {error}'**
  String fieldAlreadyExistsGeoIdFailed(String error);

  /// Message when new field is registered and GeoID was successfully extracted
  ///
  /// In en, this message translates to:
  /// **'✅ New field registered - GeoID successfully extracted: {geoId}'**
  String fieldRegistrationNewGeoIdExtracted(String geoId);

  /// Message when new field is registered but GeoID extraction failed
  ///
  /// In en, this message translates to:
  /// **'⚠️ New field registered - Failed to extract GeoID: {error}'**
  String fieldRegistrationNewGeoIdFailed(String error);

  /// No description provided for @csvProcessingComplete.
  ///
  /// In en, this message translates to:
  /// **'CSV Processing Complete'**
  String get csvProcessingComplete;

  /// No description provided for @fieldsSuccessfullyRegistered.
  ///
  /// In en, this message translates to:
  /// **'fields successfully registered'**
  String get fieldsSuccessfullyRegistered;

  /// No description provided for @fieldsAlreadyExisted.
  ///
  /// In en, this message translates to:
  /// **'fields already existed'**
  String get fieldsAlreadyExisted;

  /// No description provided for @fieldsWithErrors.
  ///
  /// In en, this message translates to:
  /// **'fields had errors'**
  String get fieldsWithErrors;

  /// No description provided for @unnamedField.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Field'**
  String get unnamedField;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(String days);

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks} week{plural} ago'**
  String weeksAgo(String weeks, String plural);

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{months} month{plural} ago'**
  String monthsAgo(String months, String plural);

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{years} year{plural} ago'**
  String yearsAgo(String years, String plural);

  /// No description provided for @allFields.
  ///
  /// In en, this message translates to:
  /// **'All Fields'**
  String get allFields;

  /// No description provided for @registeredToday.
  ///
  /// In en, this message translates to:
  /// **'Registered Today'**
  String get registeredToday;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get lastWeek;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @lastYear.
  ///
  /// In en, this message translates to:
  /// **'Last Year'**
  String get lastYear;

  /// No description provided for @filterByRegistrationDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by registration date'**
  String get filterByRegistrationDate;

  /// No description provided for @registrationErrors.
  ///
  /// In en, this message translates to:
  /// **'Registration Errors'**
  String get registrationErrors;

  /// No description provided for @noFieldsForSelectedTimeframe.
  ///
  /// In en, this message translates to:
  /// **'No fields for the selected timeframe'**
  String get noFieldsForSelectedTimeframe;

  /// No description provided for @registeredOn.
  ///
  /// In en, this message translates to:
  /// **'Registered: {date}'**
  String registeredOn(String date);

  /// No description provided for @fieldsCountSorted.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} {totalSingular, select, 1{field} other{fields}} (sorted by date)'**
  String fieldsCountSorted(String count, String total, String totalSingular);

  /// No description provided for @csvLineError.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: {error}'**
  String csvLineError(String line, String error);

  /// No description provided for @csvLineNameCoordinatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: Name and coordinates are required'**
  String csvLineNameCoordinatesRequired(String line);

  /// No description provided for @csvLineRegistrationError.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: Registration error - {error}'**
  String csvLineRegistrationError(String line, String error);

  /// No description provided for @registeredOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Registered on'**
  String get registeredOnLabel;

  /// No description provided for @specificDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Specific Date'**
  String get specificDateLabel;

  /// No description provided for @archiveContainer.
  ///
  /// In en, this message translates to:
  /// **'Archive Container'**
  String get archiveContainer;

  /// No description provided for @containerSuccessfullyArchived.
  ///
  /// In en, this message translates to:
  /// **'Container was successfully archived.'**
  String get containerSuccessfullyArchived;

  /// No description provided for @showArchivedContainers.
  ///
  /// In en, this message translates to:
  /// **'Show also archived containers'**
  String get showArchivedContainers;

  /// No description provided for @archivedContainersVisible.
  ///
  /// In en, this message translates to:
  /// **'Archived containers are shown'**
  String get archivedContainersVisible;

  /// No description provided for @archivedContainersHidden.
  ///
  /// In en, this message translates to:
  /// **'Archived containers are hidden'**
  String get archivedContainersHidden;

  /// No description provided for @searchContainers.
  ///
  /// In en, this message translates to:
  /// **'Search containers...'**
  String get searchContainers;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortByNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name (A-Z)'**
  String get sortByNameAsc;

  /// No description provided for @sortByNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name (Z-A)'**
  String get sortByNameDesc;

  /// No description provided for @sortByIdAsc.
  ///
  /// In en, this message translates to:
  /// **'ID (ascending)'**
  String get sortByIdAsc;

  /// No description provided for @sortByIdDesc.
  ///
  /// In en, this message translates to:
  /// **'ID (descending)'**
  String get sortByIdDesc;

  /// No description provided for @sortByDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Date (oldest first)'**
  String get sortByDateAsc;

  /// No description provided for @sortByDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Date (newest first)'**
  String get sortByDateDesc;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No containers found matching \"{searchTerm}\"'**
  String noSearchResults(Object searchTerm);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

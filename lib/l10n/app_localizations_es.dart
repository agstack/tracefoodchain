// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Rastrea Cadenas Alimentarias';

  @override
  String get traceTheFoodchain => 'Rastrea la Cadena Alimentaria';

  @override
  String get selectRole => 'Seleccionar rol';

  @override
  String welcomeMessage(String role) {
    return '¡Bienvenido, $role!';
  }

  @override
  String get actions => 'Acciones';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get settings => 'Configuración';

  @override
  String get farmerActions => 'Acciones del Agricultor';

  @override
  String get farmManagerActions => 'Acciones del Gerente de Granja';

  @override
  String get traderActions => 'Acciones del Comerciante';

  @override
  String get transporterActions => 'Acciones del Transportista';

  @override
  String get sellerActions => 'Acciones del Vendedor';

  @override
  String get buyerActions => 'Acciones del Comprador';

  @override
  String get identifyYourselfOnline => 'Identifícate';

  @override
  String get startHarvestOffline => 'Iniciar Cosecha';

  @override
  String get waitingForData => 'Esperando Datos...';

  @override
  String get handOverHarvestToTrader => 'Entregar Cosecha al Comerciante';

  @override
  String get scanQrCodeOrNfcTag => 'Escanea el Código QR o Etiqueta NFC';

  @override
  String get startNewHarvest => 'Nueva Cosecha';

  @override
  String get scanTraderTag => '¡Escanea la etiqueta del comerciante!';

  @override
  String get scanFarmerTag => '¡Escanea la etiqueta del agricultor!';

  @override
  String get unit => 'unidad';

  @override
  String get changeRole => 'cambiar rol';

  @override
  String get inTransit => 'en tránsito';

  @override
  String get delivered => 'entregado';

  @override
  String get completed => 'completado';

  @override
  String get statusUpdatedSuccessfully => 'actualizado con éxito';

  @override
  String get noRole => '-sin rol-';

  @override
  String get roleFarmer => 'Agriculteur';

  @override
  String get roleFarmManager => 'Gestionnaire de Ferme';

  @override
  String get roleTrader => 'Négociant';

  @override
  String get roleTransporter => 'Transporteur';

  @override
  String get roleProcessor => 'Procesador de café';

  @override
  String get roleImporter => 'Importador de la UE';

  @override
  String get roleRegistrar => 'Registrador';

  @override
  String get activeImports => 'Importaciones actuales';

  @override
  String get noActiveImports => 'No hay importaciones actuales';

  @override
  String get noActiveItems => ' No se encontró stock';

  @override
  String get noImportHistory => 'Sin historial de importación';

  @override
  String get importHistory => 'Historial de importaciones';

  @override
  String get roleSeller => 'Vendeur';

  @override
  String get roleBuyer => 'Acheteur';

  @override
  String get roleSystemAdministrator => 'Administrateur Système';

  @override
  String get roleDiascaAdmin => 'Administrateur Diasca';

  @override
  String get roleSuperAdmin => 'Super Administrator';

  @override
  String get roleTfcAdmin => 'TFC Administrator';

  @override
  String get roleRegistrarCoordinator => 'Registrar Coordinator';

  @override
  String get roleVerificationAuthority => 'Autorité de Vérification';

  @override
  String get roleAssignedSuccessfully => 'Role assigned successfully';

  @override
  String get errorAssigningRole => 'Error assigning role';

  @override
  String get userManagement => 'Gestión de Usuarios';

  @override
  String get userManagementSubtitle => 'Manage and assign user roles';

  @override
  String get noPermissionForUserManagement =>
      'No permission for user management';

  @override
  String get qcReview => 'Revisión de QC';

  @override
  String get qcReviewSubtitle => 'Revisar y aprobar registros pendientes';

  @override
  String get userManagementOnlineOnly =>
      'User management is only available online';

  @override
  String get noUsersFound => 'No se encontraron usuarios';

  @override
  String get assignRole => 'Asignar Rol';

  @override
  String get currentRole => 'Rol Actual';

  @override
  String get newRole => 'Nuevo Rol';

  @override
  String get reason => 'Razón';

  @override
  String get enterReasonForRoleChange => 'Ingrese la razón del cambio de rol';

  @override
  String get enterReason => 'Enter reason for role change';

  @override
  String get cancel => 'Cancelar';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get logoutConfirmation =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get assign => 'Assign';

  @override
  String get userDetails => 'Detalles del Usuario';

  @override
  String get name => 'Name';

  @override
  String get email => 'Correo electrónico';

  @override
  String get userID => 'User ID';

  @override
  String get manageable => 'Manageable';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Reintentar';

  @override
  String get roleManagementDebugInfo =>
      'Info de Depuración de Gestión de Roles';

  @override
  String get firestoreError => 'Error de Firestore';

  @override
  String get appUserDocRepairedSuccessfully =>
      'appUserDoc reparado exitosamente';

  @override
  String get repairFailed => 'Reparación fallida';

  @override
  String get repairAppUserDoc => 'Reparar appUserDoc';

  @override
  String get notManageable => 'No administrable';

  @override
  String get possibleReasons =>
      'Posibles razones:\n• No se encontraron usuarios administrables\n• Filtro muy restrictivo\n• Permisos faltantes';

  @override
  String get noAvailableRolesForPermission =>
      'No hay roles disponibles para su permiso';

  @override
  String usersCount(int filtered, int total) {
    return 'usuarios';
  }

  @override
  String get showUserDetails => 'Mostrar detalles del usuario';

  @override
  String get editRole => 'Editar rol';

  @override
  String get superadminSecurityError =>
      'ERROR DE SEGURIDAD: Los roles de SUPERADMIN no se pueden cambiar';

  @override
  String get superadminSecurityInfo =>
      'Los usuarios SUPERADMIN están protegidos por políticas de seguridad';

  @override
  String get superadminCannotBeAssigned =>
      'El rol de SUPERADMIN no se puede asignar';

  @override
  String get superadminCannotBeChanged =>
      'El rol de SUPERADMIN no se puede cambiar';

  @override
  String get searchUsers => 'Buscar usuarios...';

  @override
  String get filterByRole => 'Filtrar por Rol';

  @override
  String get allRoles => 'Todos los Roles';

  @override
  String get roleSuccessfullyAssigned => 'Role successfully assigned';

  @override
  String get errorWhileAssigningRole => 'Error while assigning role';

  @override
  String get reasonForRoleChange => 'Reason for role change';

  @override
  String get enterNewFarmerID => 'Ingrese un nuevo ID de agricultor';

  @override
  String get enterNewFarmID => 'Ingrese un nuevo ID de granja';

  @override
  String scannedCode(String code) {
    return 'Código Escaneado: $code';
  }

  @override
  String get confirm => 'Confirmar';

  @override
  String get errorIncorrectData =>
      'ERROR: ¡Los datos recibidos no son válidos!';

  @override
  String get provideValidSellerTag =>
      'Por favor, proporciona una etiqueta de vendedor válida.';

  @override
  String get confirmTransfer =>
      '¿El comprador recibió la información correctamente?';

  @override
  String get peerTransfer => 'Transferencia entre Pares';

  @override
  String get generateTransferData => 'Generar Datos de Transferencia';

  @override
  String get startScanning => 'Iniciar Escaneo';

  @override
  String get stopScanning => 'Detener Escaneo';

  @override
  String get startPresenting => 'Comenzar Presentación';

  @override
  String get stopPresenting => 'Detener Presentación';

  @override
  String get transferDataGenerated => 'Datos de Transferencia Generados';

  @override
  String get dataReceived => 'Datos Recibidos';

  @override
  String get ok => 'OK';

  @override
  String get feedbackEmailSubject => 'Comentarios para la App TraceFoodchain';

  @override
  String get feedbackEmailBody => 'Por favor, ingresa tus comentarios aquí:';

  @override
  String get unableToLaunchEmail => 'No se pudo abrir el cliente de correo';

  @override
  String get activeItems => 'Artículos Activos';

  @override
  String get pastItems => 'Artículos Pasados';

  @override
  String get changeFarmerId => 'Cambiar ID del Agricultor';

  @override
  String get changeFarm => 'Cambiar Finca';

  @override
  String get associateWithDifferentFarm => 'Asociar con Otra Granja';

  @override
  String get manageFarmEmployees => 'Gestionar Empleados de la Granja';

  @override
  String get manageHarvests => 'Gestionar Cosechas';

  @override
  String get manageContainers => 'Gestionar Contenedores';

  @override
  String get buyHarvest => 'Comprar Cosecha';

  @override
  String get sellHarvest => 'Vender Cosecha';

  @override
  String get manageInventory => 'Gestionar Inventario';

  @override
  String get addEmployee => 'Añadir Empleado';

  @override
  String get editEmployee => 'Editar Empleado';

  @override
  String get addHarvest => 'Añadir Cosecha';

  @override
  String get harvestDetails => 'Detalles de la Cosecha';

  @override
  String get addContainer => 'Añadir Contenedor';

  @override
  String get containerQRCode => 'Código QR del Contenedor';

  @override
  String get notImplementedYet => 'Esta funcionalidad aún no está implementada';

  @override
  String get add => 'Añadir';

  @override
  String get save => 'Guardar';

  @override
  String get buy => 'Comprar';

  @override
  String get sell => 'Vender';

  @override
  String get invalidInput =>
      'Entrada inválida. Por favor, ingresa números válidos.';

  @override
  String get editInventoryItem => 'Editar Artículo del Inventario';

  @override
  String get filterByCropType => 'Filtrar por tipo de cultivo';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get cropType => 'Tipo de Cultivo';

  @override
  String get quantity => 'Cantidad';

  @override
  String get transactionHistory => 'Historial de Transacciones';

  @override
  String get price => 'Precio';

  @override
  String get activeDeliveries => 'Entregas Activas';

  @override
  String get deliveryHistory => 'Historial de Entregas';

  @override
  String get updateStatus => 'Actualizar Estado';

  @override
  String get updateDeliveryStatus => 'Actualizar Estado de Entrega';

  @override
  String get noDeliveryHistory => 'No hay historial de entregas';

  @override
  String get noActiveDeliveries => 'No hay entregas activas';

  @override
  String get listProducts => 'Listar Productos';

  @override
  String get manageOrders => 'Gestionar Pedidos';

  @override
  String get salesHistory => 'Historial de Ventas';

  @override
  String get goToActions => 'Ir a Acciones';

  @override
  String get setPrice => 'Establecer Precio';

  @override
  String get browseProducts => 'Explorar Productos';

  @override
  String get orderHistory => 'Historial de Pedidos';

  @override
  String get addToCart => 'Añadir al Carrito';

  @override
  String get noDataAvailable => 'No hay datos disponibles';

  @override
  String get total => 'Total';

  @override
  String get syncData => 'Sincronizar Datos';

  @override
  String get startSync => 'Iniciar Sincronización';

  @override
  String get syncSuccess => 'Datos sincronizados con éxito';

  @override
  String get syncError => 'Error al sincronizar datos';

  @override
  String get nfcNotAvailable => 'NFC no disponible';

  @override
  String get scanningForNfcTags => 'Buscando etiquetas NFC';

  @override
  String get nfcScanStopped => 'Escaneo NFC detenido';

  @override
  String get qrCode => 'Código QR';

  @override
  String get nfcTag => 'Etiqueta NFC';

  @override
  String get nfcScanError => 'Error durante el escaneo NFC';

  @override
  String get multiTagFoundIOS => '¡Se encontraron múltiples etiquetas!';

  @override
  String get scanInfoMessageIOS => 'Escanea tu etiqueta';

  @override
  String get addEmptyItem => 'Agregar artículo vacío';

  @override
  String get maxCapacity => 'Capacidad máxima';

  @override
  String get uid => 'UID';

  @override
  String get bag => 'Bolsa';

  @override
  String get container => 'Contenedor';

  @override
  String get building => 'Edificio';

  @override
  String get transportVehicle => 'Vehículo de transporte';

  @override
  String get pleaseCompleteAllFields => 'Por favor complete todos los campos';

  @override
  String get fieldRequired => 'Este campo es obligatorio';

  @override
  String get invalidNumber => 'Por favor, introduce un número válido';

  @override
  String get geolocation => 'Geolocalización';

  @override
  String get latitude => 'Latitud';

  @override
  String get longitude => 'Longitud';

  @override
  String get useCurrentLocation => 'Usar ubicación actual';

  @override
  String get locationError => 'Error al obtener la ubicación';

  @override
  String get invalidLatitude => 'Latitud no válida';

  @override
  String get invalidLongitude => 'Longitud no válida';

  @override
  String get sellOnline => 'Vender en línea';

  @override
  String get recipientEmail => 'Correo electrónico del destinatario';

  @override
  String get invalidEmail => 'Dirección de correo electrónico no válida';

  @override
  String get userNotFound => 'Usuario no encontrado';

  @override
  String get saleCompleted => 'Venta completada con éxito';

  @override
  String get saleError => 'Se produjo un error durante la venta';

  @override
  String get newTransferNotificationTitle => 'Nueva transferencia';

  @override
  String get newTransferNotificationBody =>
      'Ha recibido una nueva transferencia de artículo';

  @override
  String get coffee => 'Café';

  @override
  String get amount2 => 'Cantidad';

  @override
  String speciesLabel(String species) {
    return 'Especie: $species';
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
    return 'Comprado el: $date';
  }

  @override
  String fromPlot(String plotId) {
    return 'De la parcela: $plotId';
  }

  @override
  String get noPlotFound => 'No se encontró parcela';

  @override
  String errorWithParam(String error) {
    return 'Error: $error';
  }

  @override
  String get loadingData => 'Cargando datos...';

  @override
  String get pdfGenerationError => 'Error al generar PDF';

  @override
  String containerIsEmpty(String containerType, String id) {
    return '$containerType $id está vacío';
  }

  @override
  String idWithBrackets(String id) {
    return '(ID: $id)';
  }

  @override
  String get buyCoffee => 'Comprar café';

  @override
  String get sellOffline => 'Vender sin conexión';

  @override
  String get changeProcessingState => 'Cambiar estado de procesamiento/calidad';

  @override
  String get changeLocation => 'Cambiar ubicación';

  @override
  String get selectQualityCriteria => 'Seleccionar criterios de calidad';

  @override
  String get selectProcessingState => 'Seleccionar estado de procesamiento';

  @override
  String pdfError(String error) {
    return 'Error PDF: $error';
  }

  @override
  String get errorSendingEmailWithError =>
      'Error al enviar el correo electrónico';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get resendEmail => '¡Reenviar correo electrónico!';

  @override
  String get waitingForEmailVerification =>
      'Esperando verificación de correo electrónico. Por favor, revise su bandeja de entrada y confirme su correo.';

  @override
  String get emailVerification => 'Verificación de correo electrónico';

  @override
  String get securityError => 'Error de seguridad';

  @override
  String get securityErrorMessage =>
      'No se pudieron generar los ajustes de seguridad para firmas digitales. Por favor, inténtelo más tarde y asegúrese de tener una conexión a Internet.';

  @override
  String get closeApp => 'Cerrar aplicación';

  @override
  String get activateAppFirstTime =>
      'Para activar la aplicación por primera vez, conéctese a Internet para la autenticación!';

  @override
  String get localizationConfigError =>
      'Error de configuración de localización';

  @override
  String get localizationErrorCannotSend =>
      'Error de localización - no se puede enviar el correo de verificación';

  @override
  String get localizationErrorAppLocalizationsDelegateIsMissing =>
      'AppLocalizations.delegate falta en main.dart\nconfiguración de localizationsDelegates';

  @override
  String get poweredByOpenRAL => 'impulsado por openRAL de permarobotics';

  @override
  String get debugUploadingUserProfile =>
      'DEBUG: Subiendo perfil de usuario a la nube...';

  @override
  String get uidAlreadyExists => 'Este ID ya existe, por favor elija otro';

  @override
  String get selectItemToSell => 'Por favor seleccione un artículo para vender';

  @override
  String get debugDeleteContainer => 'Eliminar contenedor (Debug)';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Francés';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get generateDDS => 'Generar DDS';

  @override
  String get ddsGenerationDemo =>
      'La generación de DDS solo está disponible en modo demo';

  @override
  String get sampleOperator => 'Operador de muestra';

  @override
  String get sampleAddress => 'Dirección de muestra';

  @override
  String get sampleEori => 'EORI de muestra';

  @override
  String get sampleHsCode => 'Código HS de muestra';

  @override
  String get sampleDescription => 'Descripción de muestra';

  @override
  String get sampleTradeName => 'Nombre comercial de muestra';

  @override
  String get sampleScientificName => 'Nombre científico de muestra';

  @override
  String get sampleQuantity => 'Cantidad de muestra';

  @override
  String get sampleCountry => 'País de muestra';

  @override
  String get sampleName => 'Nombre de muestra';

  @override
  String get sampleFunction => 'Función de muestra';

  @override
  String get scanQRCode => 'Escanear código QR';

  @override
  String get errorLabel => 'Error';

  @override
  String get welcomeToApp => 'Bienvenido a TraceFoodChain';

  @override
  String get signInMessage =>
      'Por favor, inicie sesión o regístrese para garantizar la seguridad e integridad de nuestro sistema de seguimiento de la cadena alimentaria.';

  @override
  String get password => 'Contraseña';

  @override
  String get pleaseEnterEmail => 'Por favor, introduzca su correo electrónico';

  @override
  String get pleaseEnterPassword => 'Por favor, introduzca su contraseña';

  @override
  String get signInSignUp => 'Iniciar sesión / Registrarse';

  @override
  String get helpButtonTooltip => 'Abrir ayuda';

  @override
  String get errorOpeningUrl => 'No se pudo abrir la página de ayuda';

  @override
  String get weakPasswordError =>
      'La contraseña proporcionada es demasiado débil.';

  @override
  String get emailAlreadyInUseError =>
      'Ya existe una cuenta con este correo electrónico.';

  @override
  String get invalidEmailError =>
      'La dirección de correo electrónico no es válida.';

  @override
  String get userDisabledError => 'Este usuario ha sido deshabilitado.';

  @override
  String get wrongPasswordError => 'Contraseña incorrecta para este usuario.';

  @override
  String get undefinedError => 'Ha ocurrido un error indefinido.';

  @override
  String get error => 'Error';

  @override
  String get aggregateItems => 'Agregar artículos';

  @override
  String get addNewEmptyItem => 'Agregar nuevo artículo vacío';

  @override
  String get selectBuyCoffeeOption => 'Seleccionar opción de compra de café';

  @override
  String get selectSellCoffeeOption => 'Seleccionar opción de venta de café';

  @override
  String get deviceToCloud => 'Dispositivo a la nube';

  @override
  String get deviceToDevice => 'Dispositivo a dispositivo';

  @override
  String get ciatFirstSale => 'Primera venta CIAT';

  @override
  String get buyCoffeeDeviceToDevice =>
      'Comprar café (dispositivo a dispositivo)';

  @override
  String get scanSelectFutureContainer =>
      'Escanear/Seleccionar contenedor futuro';

  @override
  String get scanContainerInstructions =>
      'Use código QR/NFC o seleccione manualmente para especificar dónde se almacenará el café.';

  @override
  String get presentInfoToSeller => 'Presentar información al vendedor';

  @override
  String get presentInfoToSellerInstructions =>
      'Muestre el código QR o etiqueta NFC al vendedor para iniciar la transacción.';

  @override
  String get receiveDataFromSeller => 'Recibir datos del vendedor';

  @override
  String get receiveDataFromSellerInstructions =>
      'Escanee el código QR o etiqueta NFC del dispositivo del vendedor para completar la transacción.';

  @override
  String get present => 'PRESENTAR';

  @override
  String get receive => 'RECIBIR';

  @override
  String get back => 'ATRÁS';

  @override
  String get next => 'SIGUIENTE';

  @override
  String get buyCoffeeCiatFirstSale => 'Comprar café (Primera venta CIAT)';

  @override
  String get scanSellerTag => 'Escanear etiqueta proporcionada por el vendedor';

  @override
  String get scanSellerTagInstructions =>
      'Use el código QR o NFC del vendedor para especificar el café que va a comprar.';

  @override
  String get enterCoffeeInfo => 'Ingresar información del café';

  @override
  String get enterCoffeeInfoInstructions =>
      'Proporcione detalles sobre el café que se está comprando.';

  @override
  String get scanReceivingContainer =>
      'Escanear etiqueta del contenedor receptor (saco, almacén, edificio, camión...)';

  @override
  String get scanReceivingContainerInstructions =>
      'Especifique dónde se transferirá el café.';

  @override
  String get coffeeInformation => 'Información del Café';

  @override
  String get countryOfOrigin => 'País de origen';

  @override
  String get selectCountry => 'Seleccionar país';

  @override
  String get selectSpecies => 'Seleccionar especie';

  @override
  String get enterQuantity => 'Ingresar cantidad';

  @override
  String get start => '¡INICIAR!';

  @override
  String get scan => '¡ESCANEAR!';

  @override
  String get species => 'Especie';

  @override
  String get processingState => 'Estado de procesamiento';

  @override
  String get qualityReductionCriteria => 'Criterios de reducción de calidad';

  @override
  String get sellCoffeeDeviceToDevice =>
      'Vender café (dispositivo a dispositivo)';

  @override
  String get scanBuyerInfo =>
      'Escanear información proporcionada por el comprador';

  @override
  String get scanBuyerInfoInstructions =>
      'Use la cámara del smartphone o NFC para leer la información inicial del comprador';

  @override
  String get presentInfoToBuyer =>
      'Presentar información al comprador para finalizar la venta';

  @override
  String get presentInfoToBuyerInstructions =>
      'Especifique dónde se transfiere el café.';

  @override
  String get selectFromDatabase => 'Seleccionar de la base de datos';

  @override
  String get notSynced => 'No sincronizado con la nube';

  @override
  String get synced => 'Sincronizado con la nube';

  @override
  String get inbox => 'Bandeja de entrada';

  @override
  String get sendFeedback => 'Enviar comentarios';

  @override
  String get fillInReminder =>
      'Por favor complete todos los campos correctamente';

  @override
  String get manual => 'Entrada manual';

  @override
  String get selectCountryFirst => '¡Por favor, seleccione primero un país!';

  @override
  String get inputOfAdditionalInformation =>
      '¡Es obligatorio ingresar información adicional!';

  @override
  String get provideValidContainer =>
      'Por favor proporcione una etiqueta válida del contenedor receptor.';

  @override
  String get buttonNext => 'SIGUIENTE';

  @override
  String get buttonScan => '¡ESCANEAR!';

  @override
  String get buttonStart => '¡INICIAR!';

  @override
  String get buttonBack => 'ATRÁS';

  @override
  String get locationPermissionsDenied =>
      'Los permisos de ubicación están denegados';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'Los permisos de ubicación están denegados permanentemente';

  @override
  String get errorSyncToCloud => 'Error al sincronizar datos con la nube';

  @override
  String get errorBadRequest => 'Error del servidor: Solicitud incorrecta';

  @override
  String get errorMergeConflict =>
      'Error del servidor: Conflicto de fusión - Los datos existen en diferentes versiones';

  @override
  String get errorServiceUnavailable =>
      'Error del servidor: Servicio no disponible';

  @override
  String get errorUnauthorized => 'Error del servidor: No autorizado';

  @override
  String get errorForbidden => 'Error del servidor: Prohibido';

  @override
  String get errorNotFound => 'Error del servidor: No encontrado';

  @override
  String get errorInternalServerError =>
      'Error del servidor: Error interno del servidor';

  @override
  String get errorGatewayTimeout =>
      'Error del servidor: Tiempo de espera en la puerta de enlace';

  @override
  String get errorUnknown => 'Error desconocido';

  @override
  String get errorNoCloudConnectionProperties =>
      'No se encontraron propiedades de conexión a la nube';

  @override
  String get syncToCloudSuccessful => 'Sincronización con la nube exitosa';

  @override
  String get testModeActive => 'Modo de prueba activo';

  @override
  String get dataMode => 'Modo de datos';

  @override
  String get testMode => 'Modo de prueba';

  @override
  String get realMode => 'Modo de producción';

  @override
  String get nologoutpossible =>
      'Cerrar sesión solo es posible cuando está conectado a internet';

  @override
  String get manuallySyncingWith => 'Sincronizando manualmente con';

  @override
  String get syncingWith => 'Sincronizando con';

  @override
  String get syncInProgress => 'Sincronización en curso...';

  @override
  String get newKeypairNeeded =>
      'No se encontró clave privada - generando nuevo par de claves...';

  @override
  String get failedToInitializeKeyManagement =>
      'ADVERTENCIA: ¡Error al inicializar la gestión de claves!';

  @override
  String get newUserProfileNeeded =>
      'Perfil de usuario no encontrado en la base de datos local - creando uno nuevo...';

  @override
  String get coffeeIsBought => 'El café se compra';

  @override
  String get coffeeIsSold => 'El café se vende';

  @override
  String get generatingItem => 'Generando artículo...';

  @override
  String get processing => 'Procesando datos...';

  @override
  String get setItemName => 'Establecer nombre';

  @override
  String get unnamedObject => 'Objeto sin nombre';

  @override
  String get capacity => 'Capacidad';

  @override
  String get freeCapacity => 'Capacidad libre';

  @override
  String get selectContainerForItems =>
      'Seleccionar contenedor\npara los artículos';

  @override
  String get selectContainer => 'Seleccionar contenedor';

  @override
  String get enterUIDhere => 'Ingrese el UID aquí';

  @override
  String get excelFileDownloaded => 'Archivo Excel descargado';

  @override
  String get excelFileSavedAt => 'Archivo Excel guardado en';

  @override
  String get failedToGenerateExcelFile => 'Error al generar el archivo Excel';

  @override
  String get exportToExcel => 'Exportar a Excel';

  @override
  String get resetPasswordEmailSent =>
      'Se ha enviado un correo electrónico para restablecer la contraseña';

  @override
  String get forgotPasswordQuestion => '¿Olvidaste tu contraseña?';

  @override
  String get weightEquivalentGreenBeanKg => 'Peso equivalente de oro (kg)';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get pleaseEnterEmailAndPassword =>
      'Por favor, introduce el correo electrónico y la contraseña';

  @override
  String get loggingIn => 'Iniciando sesión...';

  @override
  String get loginFailed => 'Error al iniciar sesión';

  @override
  String get gettingAuthorityToken => 'Obteniendo token de autoridad...';

  @override
  String get fieldRegistry => 'Registro de Campos';

  @override
  String get fieldRegistryTitle => 'Campos Registrados';

  @override
  String get fieldName => 'Nombre de la Parcela';

  @override
  String get geoId => 'ID Geográfico';

  @override
  String get area => 'Área';

  @override
  String get registerNewFields => 'Registrar Nuevos Campos';

  @override
  String get uploadCsv => 'Subir CSV';

  @override
  String get selectCsvFile => 'Seleccionar Archivo CSV';

  @override
  String get csvUploadSuccess => 'CSV subido exitosamente';

  @override
  String get csvUploadError => 'Error al subir CSV';

  @override
  String get registering => 'Registrando...';

  @override
  String get registrationComplete => 'Registro completo';

  @override
  String get registrationError => 'Error de registro';

  @override
  String get fieldAlreadyExists => 'El campo ya existe';

  @override
  String get noFieldsRegistered => 'No hay campos registrados';

  @override
  String get csvFormatInfo => 'Formato CSV: Nombre, Descripción, Coordenadas';

  @override
  String get invalidCsvFormat => 'Formato CSV inválido';

  @override
  String get fieldRegisteredSuccessfully => 'Campo registrado exitosamente';

  @override
  String get progressStep1InitializingServices =>
      'Paso 1: Inicializando servicios...';

  @override
  String get progressStep1UserRegistryLogin =>
      'Paso 1: Inicio de sesión en User Registry...';

  @override
  String get progressStep2RegisteringField =>
      'Paso 2: Registrando campo con Asset Registry...';

  @override
  String get progressStep2FieldRegisteredSuccessfully =>
      'Paso 2: Campo registrado exitosamente, extrayendo GeoID...';

  @override
  String get progressStep2FieldAlreadyExists =>
      'Paso 2: El campo ya existe, extrayendo GeoID...';

  @override
  String progressStep3CheckingCentralDatabase(String geoId) {
    return 'Paso 3: Verificando base de datos central (GeoID: $geoId)...';
  }

  @override
  String get progressStep3FieldNotFoundInCentralDb =>
      'Paso 3: Campo no encontrado en base de datos central - procediendo con registro local...';

  @override
  String get processingCsvFile => 'Procesando archivo CSV...';

  @override
  String get fieldRegistrationInProgress => 'Registro de campo en progreso...';

  @override
  String fieldXOfTotal(String current, String total) {
    return 'Campo $current de $total';
  }

  @override
  String currentField(String fieldName) {
    return 'Campo actual: $fieldName';
  }

  @override
  String fieldRegistrationSuccessMessage(String fieldName) {
    return '✅ Campo \"$fieldName\" registrado exitosamente!';
  }

  @override
  String fieldRegistrationErrorMessage(String fieldName, String error) {
    return '❌ Error con \"$fieldName\": $error';
  }

  @override
  String fieldAlreadyExistsGeoIdExtracted(String geoId) {
    return '✅ El campo ya existe - GeoID extraído exitosamente: $geoId';
  }

  @override
  String fieldAlreadyExistsGeoIdFailed(String error) {
    return '⚠️ El campo ya existe - Error al extraer GeoID: $error';
  }

  @override
  String fieldRegistrationNewGeoIdExtracted(String geoId) {
    return '✅ Nuevo campo registrado - GeoID extraído exitosamente: $geoId';
  }

  @override
  String fieldRegistrationNewGeoIdFailed(String error) {
    return '⚠️ Nuevo campo registrado - Error al extraer GeoID: $error';
  }

  @override
  String get csvProcessingComplete => 'Procesamiento de CSV Completado';

  @override
  String get fieldsSuccessfullyRegistered => 'campos registrados exitosamente';

  @override
  String get fieldsAlreadyExisted => 'campos ya existían';

  @override
  String get fieldsWithErrors => 'campos con errores';

  @override
  String get unnamedField => 'Campo Sin Nombre';

  @override
  String get unknown => 'Desconocido';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String daysAgo(String days) {
    return 'hace $days días';
  }

  @override
  String weeksAgo(String weeks, String plural) {
    return 'hace $weeks semana$plural';
  }

  @override
  String monthsAgo(String months, String plural) {
    return 'hace $months mes$plural';
  }

  @override
  String yearsAgo(String years, String plural) {
    return 'hace $years año$plural';
  }

  @override
  String get allFields => 'Todos los Campos';

  @override
  String get registeredToday => 'Registrados Hoy';

  @override
  String get lastWeek => 'Última Semana';

  @override
  String get lastMonth => 'Último Mes';

  @override
  String get lastYear => 'Último Año';

  @override
  String get filterByRegistrationDate => 'Filtrar por fecha de registro';

  @override
  String get registrationErrors => 'Errores de Registro';

  @override
  String get noFieldsForSelectedTimeframe =>
      'No hay campos para el período seleccionado';

  @override
  String registeredOn(String date) {
    return 'Registrado el';
  }

  @override
  String fieldsCountSorted(String count, String total, String totalSingular) {
    String _temp0 = intl.Intl.selectLogic(
      totalSingular,
      {
        '1': 'campo',
        'other': 'campos',
      },
    );
    return '$count de $total $_temp0 (ordenados por fecha)';
  }

  @override
  String csvLineError(String line, String error) {
    return 'Línea $line: $error';
  }

  @override
  String csvLineNameCoordinatesRequired(String line) {
    return 'Línea $line: Nombre y coordenadas son requeridos';
  }

  @override
  String csvLineRegistrationError(String line, String error) {
    return 'Línea $line: Error de registro - $error';
  }

  @override
  String get registeredOnLabel => 'Registrado el';

  @override
  String get specificDateLabel => 'Fecha específica';

  @override
  String get archiveContainer => 'Archivar Contenedor';

  @override
  String get containerSuccessfullyArchived =>
      'El contenedor fue archivado exitosamente.';

  @override
  String get showArchivedContainers =>
      'Mostrar también contenedores archivados';

  @override
  String get archivedContainersVisible =>
      'Los contenedores archivados se muestran';

  @override
  String get archivedContainersHidden =>
      'Los contenedores archivados están ocultos';

  @override
  String get searchContainers => 'Buscar contenedores...';

  @override
  String get sort => 'Ordenar';

  @override
  String get sortByNameAsc => 'Nombre (A-Z)';

  @override
  String get sortByNameDesc => 'Nombre (Z-A)';

  @override
  String get sortByIdAsc => 'ID (ascendente)';

  @override
  String get sortByIdDesc => 'ID (descendente)';

  @override
  String get sortByDateAsc => 'Fecha (más antiguos primero)';

  @override
  String get sortByDateDesc => 'Fecha (más recientes primero)';

  @override
  String noSearchResults(Object searchTerm) {
    return 'No se encontraron contenedores que coincidan con \"$searchTerm\"';
  }

  @override
  String get profileSetup => 'Completar perfil';

  @override
  String get welcomeCompleteProfile => '¡Bienvenido! Completa tu perfil';

  @override
  String get profileSetupDescription =>
      'Por favor proporciona información adicional para completar tu perfil.';

  @override
  String get profilePicture => 'Foto de perfil';

  @override
  String get tapToAddPhoto => 'Toca aquí para agregar una foto';

  @override
  String get personalInformation => 'Información personal';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get nationality => 'Nacionalidad';

  @override
  String get role => 'Rol';

  @override
  String get pleaseEnterFirstName => 'Por favor ingresa tu nombre';

  @override
  String get pleaseEnterLastName => 'Por favor ingresa tu apellido';

  @override
  String get pleaseSelectRole => 'Por favor selecciona un rol';

  @override
  String get saving => 'Guardando...';

  @override
  String get completeProfile => 'Completar perfil';

  @override
  String get skipForNow => 'Omitir por ahora';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get userProfile => 'Perfil de usuario';

  @override
  String get viewAndEditProfile => 'Ver y editar perfil';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get roleAndLocation => 'Rol y ubicación';

  @override
  String get notSpecified => 'No especificado';

  @override
  String get yourAssignedRole => 'Tu rol asignado';

  @override
  String get roleRequestedWaitingApproval =>
      'Rol solicitado - esperando aprobación del administrador';

  @override
  String get rolesLoading => 'Cargando roles...';

  @override
  String get requestDesiredRole => 'Solicitar rol deseado';

  @override
  String get roleRequestMustBeApproved =>
      'Su solicitud de rol debe ser aprobada por un administrador';

  @override
  String get cropImage => 'Recortar imagen';

  @override
  String get imageUploadError =>
      'Error al subir la imagen. Por favor, inténtalo de nuevo.';

  @override
  String imageProcessingError(String error) {
    return 'Error al procesar la imagen: $error';
  }

  @override
  String get pleaseSelectCountry => 'Por favor, selecciona tu país.';

  @override
  String profileSaveError(String error) {
    return 'Error al guardar el perfil: $error';
  }

  @override
  String get plotRegistrationNotPossible =>
      'El registro de la parcela no es posible';

  @override
  String get deviceHasNoGps =>
      'Este dispositivo no tiene GPS, utiliza otro dispositivo';

  @override
  String get gpsDisabledMessage =>
      'Por favor, activa el GPS y permite que este dispositivo acceda a los datos de GPS';

  @override
  String get enableGpsButton => 'Activar GPS y permisos';

  @override
  String get openSettingsButton => 'Abrir configuración';

  @override
  String get registerFarmFarmer => 'Registrar Finca/Agricultor';

  @override
  String get registerFarm => 'Registrar Finca';

  @override
  String get registerFarmer => 'Registrar Agricultor';

  @override
  String get registerField => 'Registrar Parcela';

  @override
  String get recordFieldBoundary => 'Grabar Límites de Parcela';

  @override
  String get fieldMustBeLinkedToFarm =>
      'El campo debe estar vinculado a una finca';

  @override
  String get noFarmsRegisteredYet => 'Aún no hay fincas registradas';

  @override
  String get startRecording => 'Iniciar Grabación';

  @override
  String get stopRecording => 'Detener Grabación';

  @override
  String get addPoint => 'Agregar Punto';

  @override
  String pointsRecorded(int count) {
    return '$count puntos grabados';
  }

  @override
  String estimatedArea(String area) {
    return 'Área estimada: $area ha';
  }

  @override
  String get qcPending => 'Pendiente de Aprobación';

  @override
  String get qcApproved => 'Aprobado';

  @override
  String get qcRejected => 'Rechazado';

  @override
  String get approveRegistration => 'Aprobar';

  @override
  String get rejectRegistration => 'Rechazar';

  @override
  String get reviewRegistration => 'Revisar Registro';

  @override
  String get reviewPendingRegistrations => 'Revisar Registros Pendientes';

  @override
  String get farmerDetails => 'Detalles del Agricultor';

  @override
  String get farmDetails => 'Detalles de la Finca';

  @override
  String get fieldDetails => 'Detalles de la Parcela';

  @override
  String get nationalID => 'Cédula de Identidad';

  @override
  String get phoneNumber => 'Número de Teléfono';

  @override
  String get fieldArea => 'Área de Parcela (ha)';

  @override
  String get polygonNotClosed => 'El polígono no está cerrado';

  @override
  String get minimumPointsRequired => 'Se requieren al menos 3 puntos';

  @override
  String get farmerInformation => 'Información del Agricultor';

  @override
  String get farmInformation => 'Información de la Finca';

  @override
  String get fieldInformation => 'Información de la Parcela';

  @override
  String get reviewAllData => 'Revisar Todos los Datos';

  @override
  String get farmName => 'Nombre de la Finca';

  @override
  String get farmAddress => 'Dirección de la Finca';

  @override
  String get addAnotherField => 'Agregar Otra Parcela';

  @override
  String get completeRegistration => 'Completar Registro';

  @override
  String get registrationSuccessful => 'Registro exitoso';

  @override
  String get registrationFailed => 'Registro fallido';

  @override
  String get gpsRequired => 'El GPS debe estar activado para el registro';

  @override
  String get pleaseEnableGps => 'Por favor activa el GPS para continuar';

  @override
  String get waitingForGps => 'Esperando señal GPS...';

  @override
  String get recordingInProgress => 'Grabación en progreso...';

  @override
  String get cancelRegistration => '¿Salir del Registro?';

  @override
  String get cancelRegistrationMessage => '¿Desea salir del registro de campo?';

  @override
  String get continueRegistration => 'Continuar';

  @override
  String get saveAndExit => 'Guardar y Salir';

  @override
  String get discardData => 'Descartar';

  @override
  String get tapToAddPoint => 'Presiona el botón o camina para agregar puntos';

  @override
  String minimumDistanceWarning(int meters) {
    return 'Punto demasiado cerca del punto anterior (mín ${meters}m)';
  }

  @override
  String get clearPolygon => 'Borrar Polígono';

  @override
  String get undoLastPoint => 'Deshacer Último Punto';

  @override
  String get deletePoint => '¿Eliminar Punto?';

  @override
  String deletePointConfirmation(int index) {
    return '¿Eliminar punto $index del polígono?';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get recordedPoints => 'Puntos Registrados:';

  @override
  String get current => 'Actual';

  @override
  String get accuracy => 'Precisión';

  @override
  String get closeAutomatically => '¿Cerrar automáticamente?';

  @override
  String get cityName => 'Ciudad/Pueblo';

  @override
  String get stateName => 'Estado/Departamento';

  @override
  String get noPendingRegistrations => 'No hay registros pendientes';

  @override
  String get registrationApproved => 'Registro aprobado';

  @override
  String get registrationRejected => 'Registro rechazado';

  @override
  String get rejectionReason => 'Motivo del Rechazo';

  @override
  String get approvalNotes => 'Notas de Aprobación';

  @override
  String assetRegistryRegistrationFailed(String error) {
    return 'El registro inicial en Asset Registry falló al llamar a la API: $error';
  }

  @override
  String get assetRegistryWillBeAttempted =>
      'Nota: Esta parcela será registrada en el Asset Registry para obtener un GeoID.';

  @override
  String fieldsCount(int count) {
    return '$count parcela(s)';
  }

  @override
  String get registeredBy => 'Registrado por';

  @override
  String get registrationDate => 'Fecha de Registro';

  @override
  String pendingCount(int count) {
    return '$count pendiente(s)';
  }

  @override
  String get todaysRegistrations => 'Registros de Hoy';

  @override
  String get registrarDashboard => 'Panel de Registro';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get quickActions => 'Acciones Rápidas';

  @override
  String get todaysStatistics => 'Estadísticas de Hoy';

  @override
  String get registered => 'Registrado';

  @override
  String get verified => 'Verificado';

  @override
  String get pending => 'Pendiente';

  @override
  String get continueOrStartNew => '¿Continuar o empezar nuevo?';

  @override
  String get unfinishedFieldRecordings =>
      'Hay grabaciones de campo sin terminar:';

  @override
  String get points => 'puntos';

  @override
  String get startNewField => 'Comenzar nuevo campo';

  @override
  String get pinchToZoom => 'Pellizca para zoom, mantén presionado para editar';

  @override
  String get point => 'Punto';

  @override
  String get optionalNotes =>
      'Notas opcionales (p. ej., documentos verificados, evaluación de calidad)';

  @override
  String get pleaseProvideReason =>
      'Por favor proporcione una razón para el rechazo';

  @override
  String get objectNotFound => 'Objeto no encontrado';

  @override
  String get invalidObjectData => 'Datos de objeto inválidos';

  @override
  String get errorLoadingDetails => 'Error al cargar detalles';

  @override
  String get tapToEnlarge => 'Toque para ampliar';

  @override
  String get tapToEnlargeMap => 'Toque para ampliar el mapa';

  @override
  String get nationalIDPhoto => 'Foto de Identificación Nacional';

  @override
  String get errorLoadingImage => 'Error al cargar la imagen';

  @override
  String get unnamed => 'Sin nombre';

  @override
  String get mapView => 'Vista de Mapa';

  @override
  String get debugDeleteAllObjects =>
      'DEBUG: Eliminar Todos los Objetos Mostrados';

  @override
  String confirmDeleteAllObjects(int count) {
    return '¿Está seguro de que desea eliminar todos los $count objetos mostrados? ¡Esta acción no se puede deshacer!';
  }

  @override
  String objectsDeleted(int count) {
    return '$count objeto(s) eliminado(s)';
  }

  @override
  String get errorDeleting => 'Error al eliminar';

  @override
  String get uidCopiedToClipboard => 'UID copiado al portapapeles';

  @override
  String get status => 'Estado';

  @override
  String get type => 'Tipo';

  @override
  String get created => 'Creado';

  @override
  String get all => 'Todos';

  @override
  String get farms => 'Fincas';

  @override
  String get farmers => 'Agricultores';

  @override
  String get fields => 'Campos';

  @override
  String get totalArea => 'Área Total';

  @override
  String get owner => 'Propietario';

  @override
  String get country => 'País';

  @override
  String get polygonPoints => 'Puntos del Polígono';

  @override
  String get takeIDPhoto => 'Tomar Foto de Identificación';

  @override
  String get retakeIDPhoto => 'Volver a Tomar Foto de Identificación';

  @override
  String get farmID => 'ID de Finca';

  @override
  String get nationalIDPhotoRequired =>
      'Se requiere foto de identificación nacional';

  @override
  String get idPhotoTaken => 'Foto de identificación tomada exitosamente';

  @override
  String get placeIDCardInFrame =>
      'Coloque la tarjeta de identificación dentro del marco';

  @override
  String get capture => 'Capturar';

  @override
  String get errorLoadingUserData =>
      'Error al cargar datos de usuario. Por favor, cierre sesión y vuelva a iniciar sesión.';

  @override
  String get gpsSignalExcellent => 'Señal GPS: Excelente';

  @override
  String get gpsSignalGood => 'Señal GPS: Buena';

  @override
  String get gpsSignalPoor => 'Señal GPS: Débil';

  @override
  String get viewHistory => 'Ver Historial';

  @override
  String get registrationHistory => 'Historial de Registros';

  @override
  String get noRegistrationsFound => 'No se encontraron registros';

  @override
  String get farm => 'Finca';

  @override
  String get farmer => 'Agricultor';

  @override
  String get field => 'Campo';

  @override
  String get consentFormPhoto => 'Foto del Formulario de Consentimiento';

  @override
  String get dataUsageConsent => 'Consentimiento de Uso de Datos';

  @override
  String get dataUsageConsentDetails =>
      'Por favor, tome una foto del formulario de consentimiento de uso de datos firmado';

  @override
  String get consentFormPhotoRequired =>
      'Se requiere foto del formulario de consentimiento';

  @override
  String get consentPhotoTaken =>
      'Foto del formulario de consentimiento tomada exitosamente';

  @override
  String get takeConsentFormPhoto =>
      'Tomar Foto del Formulario de Consentimiento';

  @override
  String get retakeConsentFormPhoto =>
      'Volver a Tomar Foto del Formulario de Consentimiento';

  @override
  String get placeConsentFormInFrame =>
      'Coloque el formulario de consentimiento firmado dentro del marco';

  @override
  String get fieldPhoto => 'Foto del Campo';

  @override
  String get takeFieldPhoto => 'Tomar Foto del Campo';

  @override
  String get retakeFieldPhoto => 'Volver a Tomar Foto del Campo';

  @override
  String get fieldPhotoRequired =>
      'Se recomienda encarecidamente la foto del campo';

  @override
  String get fieldPhotoTaken => 'Foto del campo tomada exitosamente';

  @override
  String get photoTaken => 'Foto tomada exitosamente';

  @override
  String get pleasePhotoField =>
      'Por favor, tome una foto del campo antes de completar el registro';

  @override
  String get fieldPhotoNotInPolygon =>
      '¡La foto no fue tomada dentro del campo! Por favor, vuelva a tomar la foto dentro de los límites del campo (tolerancia: 50m).';

  @override
  String get fieldPhotoInvalid => '¡La ubicación de la foto es INVÁLIDA!';
}

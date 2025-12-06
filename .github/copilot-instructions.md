# TraceFoodChain AI Agent Guidelines

## Project Overview
TraceFoodChain is a cross-platform Flutter app for coffee supply chain tracking with EUDR compliance. It operates **offline-first** using Hive for local storage, syncs with Firebase, and integrates with external APIs (WHISP for deforestation risk, AgStack Asset Registry). The app supports farmers, traders, processors, and importers across the coffee supply chain.

## Core Architecture

### Data Layer: openRAL Framework
- **All data structures use openRAL** (open Resource Abstraction Layer) - a standardized JSON schema for supply chain objects
- Templates stored in `openRALTemplates` Hive box, actual data in user-specific `localStorage_<userId>` boxes
- Key functions in `lib/services/open_ral_service.dart`:
  - `getOpenRALTemplate(templateName)` - fetch object/method templates
  - `getSpecificPropertyfromJSON(doc, property)` - extract nested properties via JSONPath
  - Templates include: `farm`, `human`, `coffee`, `changeOwner`, `changeContainer`, `generateDigitalSibling`
- Initial templates loaded from `lib/repositories/initial_data.dart` on first startup
- All generation and change processes of objects need to use generateDigitalSibling and changeObject or similar methods to ensure proper method history tracking
- All openRAL processes MUST be signed digitally using Ed25519 keys (see `lib/helpers/digital_signature.dart`)

### User-Specific Storage Pattern
```dart
// CRITICAL: Never access localStorage before user login
await initializeUserLocalStorage(userId);  // Opens 'localStorage_<userId>' box
// On logout:
await closeUserLocalStorage();  // Closes box, clears cache, resets UI notifiers
```

### State Management
- **Provider** for global state (`lib/providers/app_state.dart`)
  - Manages: user role, authentication, connectivity, device capabilities (GPS/NFC/camera), locale
- **TrackedValueNotifier** for UI reactivity (custom ValueNotifier in `lib/widgets/tracked_value_notifier.dart`)
  - Global notifiers in `main.dart`: `repaintContainerList`, `rebuildSpeedDial`, `inboxCount`, `syncStatusNotifier`
  - Pattern: Set `.value = true` to trigger UI rebuild, widgets listen via `ValueListenableBuilder`

### Offline-First Sync
- All operations save to local Hive first, queue for cloud sync when online
- `CloudSyncService` (`lib/services/cloud_sync_service.dart`) handles bi-directional sync with Firebase/cloud connectors
- Connectivity listener in `AppState.startConnectivityListener()` auto-triggers sync on reconnect
- Digital signatures (`lib/helpers/digital_signature.dart`) using Ed25519 for secure data exchange

## Key Development Patterns

### Localization (l10n) - CRITICAL
- **NEVER use hardcoded strings in UI** - all user-facing text MUST be localized via ARB files
- **Generate new translations**: `flutter gen-l10n` after editing ARB files (see `main.dart` line 1 comment)
- ARB files in `lib/l10n/` (`app_en.arb`, `app_es.arb`, `app_de.arb`, `app_fr.arb`), configured in `l10n.yaml`
- **Usage pattern**:
  ```dart
  final l10n = AppLocalizations.of(context)!;
  Text(l10n.roleFarmer)  // Good ✓
  Text('Farmer')         // Bad ✗ - never hardcode strings!
  ```
- **Supported locales**: English (en), Spanish (es), German (de), French (fr)
- **After adding new keys**: Run `flutter gen-l10n` to regenerate localizations, build will fail otherwise

### Role-Based Actions
- Roles defined in `lib/repositories/roles.dart`: Farmer, Trader, Processor, Importer, registrar, System Administrator
- Speed dial menu (`lib/widgets/role_based_speed_dial.dart`) dynamically shows actions per role
- Permission checks via `PermissionService` (cached role data, invalidate on logout)

### Container-Item Relationships
- "Containers" (storage units) hold nested "items" (coffee batches)
- Recursive scanning of `localStorage` to find all items in container via `currentGeolocation.container.UID`
- Pattern in `lib/widgets/items_list_widget.dart` lines 105-120

### Deforestation Risk (EUDR Compliance)
- WHISP API integration (`lib/services/whisp_api_service.dart`) analyzes farm plot geo-IDs
- Risk data stored as `deforestation_risk` / `risk_pcrop` property on plots
- Due Diligence Statements (DDS) generated via `lib/services/pdf_generator_service.dart`

## Critical Developer Workflows

### Build & Run
```powershell
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device/emulator
flutter run -d chrome              # Run as web app
flutter build apk --release        # Android release build
```

### Localization Regeneration
```powershell
flutter gen-l10n                   # Regenerate after editing .arb files
```

### Code Formatting (Dart-specific)
- Use `dart_format` tool for Dart files (handles unsaved changes), **never** terminal `dart format`
- Analysis options in `analysis_options.yaml` (ignores `unused_local_variable`)

### Firebase Setup
- Android: `android/app/google-services.json` required
- iOS: `ios/Runner/GoogleService-Info.plist` required
- Firebase config in `lib/firebase_options.dart`

### Testing
- Unit tests in `test/` (e.g., `json_full_double_to_int_test.dart`)
- Integration tests in `integration_test/app_test.dart`
- Run: `flutter test` (unit) or `flutter test integration_test/` (integration)

## Code Conventions

### UI Text - MANDATORY Localization
- **CRITICAL**: All user-facing text must use localized strings from ARB files
- **Never use hardcoded strings** in `Text()`, button labels, dialogs, error messages, etc.
- Always obtain `AppLocalizations`: `final l10n = AppLocalizations.of(context)!;`
- For new text: Add to all 4 ARB files (`app_en.arb`, `app_es.arb`, `app_de.arb`, `app_fr.arb`), then run `flutter gen-l10n`
- Exception: Debug/development logs can use English strings

### Text Color and Visibility - CRITICAL
- **ALWAYS explicitly set text colors** to ensure visibility across all themes
- **NEVER rely on default text colors** - they may be white-on-white or invisible
- **Standard color scheme for readability**:
  ```dart
  // Titles (dialogs, cards, headers)
  style: const TextStyle(color: Colors.black)
  
  // Body text (content, descriptions)
  style: const TextStyle(color: Colors.black87)
  
  // Subtitles, hints, secondary text
  style: TextStyle(color: Colors.grey[700])
  
  // TextField input text
  style: const TextStyle(color: Colors.black)
  ```
- **Apply to ALL text widgets**: `Text()`, `TextField`, dialog titles/content, stepper titles/subtitles, button labels
- **Common places to check**: AlertDialog (title, content), Stepper (title, subtitle), TextField (style), SnackBar, ListTile

### JSON Handling
- **Always** use `jsonFullDoubleToInt()` helper before saving openRAL docs (converts `.0` floats to ints for consistency)
- Sort JSON alphabetically with `sortJsonMapAlphabetically()` for deterministic output

### Error Handling
- Extensive null-safety checks (SDK 3.0+)
- Try-catch blocks around all API calls and Hive operations
- User-friendly error dialogs via `fshowInfoDialog(context, message)` - **message must be localized**

### Async Patterns
- Use `await` for all Hive/Firebase operations
- Background tasks handled via `workmanager` package for periodic sync
- NFC/QR operations use `ValueNotifier` for async state updates

### File Organization
- **Repositories** (`lib/repositories/`) - static data, initial templates, role definitions
- **Services** (`lib/services/`) - business logic, API clients, background tasks
- **Helpers** (`lib/helpers/`) - utility functions (cryptography, JSON manipulation, sorting)
- **Widgets** (`lib/widgets/`) - reusable UI components (steppers for multi-step processes, dialogs)

## External Integrations

### WHISP (Deforestation Risk)
- Base URL: `https://whisp.openforis.org/`
- Requires API key (stored in `.env` as `WHISP_API_KEY`)
- Submits geo-IDs, returns risk scores per plot

### AgStack Asset Registry
- Service class: `lib/services/asset_registry_api_service.dart`
- OpenAPI spec: https://agstack.github.io/agstack-website/apis/asset_registry.json
- Uses HMAC-SHA256 signing with access/private keys
## Common Pitfalls

1. **NEVER hardcode UI strings** - all text must be localized via ARB files (`lib/l10n/app_*.arb`), then run `flutter gen-l10n`
2. **ALWAYS set explicit text colors** - default colors cause white-on-white visibility issues (use `TextStyle(color: Colors.black)`)
3. **Don't access `localStorage` before user login** - it's user-specific, check `isLocalStorageInitialized()` first
4. **Invalidate caches on logout** - call `closeUserLocalStorage()` to clear all user data and UI notifiers
5. **Use TrackedValueNotifier for cross-widget updates** - regular setState() won't work for global state changes
6. **Don't forget `flutter gen-l10n`** after adding new localization keys - build will fail with missing strings
7. **OpenRAL UIDs must be unique** - use `uuid.v4()` for new objects, never duplicate
8. **Country-specific logic** - currently hardcoded to "Honduras" in multiple places (search for `country = "Honduras"`)

## Debugging Tips
- Check `repaintContainerList.value` and `rebuildSpeedDial.value` if UI doesn't update after data changes
- Firebase emulator logs: Enable detailed logging in `cloud_sync_service.dart` (print statements exist but may be commented out)
- Hive inspector: Use `Hive.box('boxName').values` in debugger to inspect local data
- NFC issues: Check `NFCAvailability` enum, won't work on web/desktop builds

## Project-Specific Terminology
- **Digital Sibling**: A digital twin of a physical coffee batch (created via `generateDigitalSibling` method)
- **First Sale**: Initial sale from farmer to trader (special workflow in `lib/widgets/stepper_first_sale.dart`)
- **Container**: Logical storage unit (warehouse, truck, etc.) containing coffee items
- **Method History**: Audit trail of all operations on an openRAL object (stored as `methodHistoryRef`)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/profiles/profile_import_service.dart';
import '../core/security/app_logger.dart';
import '../core/storage/app_database.dart';
import '../core/storage/drift_profile_store.dart';
import '../core/storage/panel_store.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/settings_store.dart';
import '../core/storage/standalone_profile_store.dart';
import '../platform/windows/windows_secure_storage.dart';
import '../platform/windows/windows_startup_registration.dart';
import 'app_runtime_controller.dart';
import 'app_runtime_state.dart';

final loggerProvider = Provider<AppLogger>((ref) => const RedactingLogger());

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => const WindowsSecureStorage(),
);

final panelStoreProvider = Provider<PanelStore>(
  (ref) => PanelStore(ref.watch(databaseProvider)),
);

final profileStoreProvider = Provider<DriftProfileStore>(
  (ref) => DriftProfileStore(
    database: ref.watch(databaseProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

final standaloneProfileStoreProvider = Provider<StandaloneProfileStore>(
  (ref) => StandaloneProfileStore(
    database: ref.watch(databaseProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

final profileImportServiceProvider = Provider<ProfileImportService>((ref) {
  final service = ProfileImportService();
  ref.onDispose(service.dispose);
  return service;
});

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(databaseProvider)),
);

final startupRegistrationProvider = Provider<StartupRegistration>(
  (ref) => WindowsStartupRegistration(),
);

final runtimeControllerProvider =
    StateNotifierProvider<AppRuntimeController, AppRuntimeState>((ref) {
      return AppRuntimeController(
        logger: ref.watch(loggerProvider),
        secureStorage: ref.watch(secureStorageProvider),
        panelStore: ref.watch(panelStoreProvider),
        profileStore: ref.watch(profileStoreProvider),
        standaloneProfileStore: ref.watch(standaloneProfileStoreProvider),
        profileImportService: ref.watch(profileImportServiceProvider),
        settingsStore: ref.watch(settingsStoreProvider),
        startupRegistration: ref.watch(startupRegistrationProvider),
      );
    });

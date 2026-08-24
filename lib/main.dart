import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:clashxy/l10n/app_localizations.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'app/providers.dart';
import 'l10n/l10n.dart';
import 'models/connection_models.dart';
import 'platform/windows/windows_legacy_data_migration.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await migrateLegacyWindowsData();
  await windowManager.ensureInitialized();
  final startHidden = arguments.contains('--startup');
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(900, 600),
      center: true,
      title: 'ClashXY',
    ),
    () async {
      if (startHidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    },
  );
  runApp(const ProviderScope(child: ClashXYApp()));
}

class ClashXYApp extends ConsumerStatefulWidget {
  const ClashXYApp({super.key});

  @override
  ConsumerState<ClashXYApp> createState() => _ClashXYAppState();
}

class _ClashXYAppState extends ConsumerState<ClashXYApp>
    with WindowListener, tray.TrayListener {
  bool _trayReady = false;
  bool _quitting = false;
  String? _traySignature;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    tray.trayManager.addListener(this);
    unawaited(_initializeDesktop());
    unawaited(
      Future<void>.microtask(
        ref.read(runtimeControllerProvider.notifier).initialize,
      ),
    );
  }

  Future<void> _initializeDesktop() async {
    await windowManager.setPreventClose(true);
    await tray.trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await tray.trayManager.setToolTip('ClashXY');
    _trayReady = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(
      runtimeControllerProvider.select((state) => state.settings.localeCode),
    );
    final trayState = ref.watch(
      runtimeControllerProvider.select(
        (state) => (
          connected: state.connection is Connected,
          busy: state.busy,
          hasProfiles: state.profiles.isNotEmpty,
        ),
      ),
    );
    final trayL10n = lookupAppLocalizations(_resolvedLocale(localeCode));
    final signature = <Object>[
      trayL10n.localeName,
      trayState.connected,
      trayState.busy,
      trayState.hasProfiles,
      _trayReady,
    ].join('|');
    if (_trayReady && signature != _traySignature) {
      _traySignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_updateTrayMenu(trayL10n, trayState));
      });
    }
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: localeForSetting(localeCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }

  Future<void> _updateTrayMenu(
    AppLocalizations l10n,
    ({bool connected, bool busy, bool hasProfiles}) state,
  ) async {
    await tray.trayManager.setContextMenu(
      tray.Menu(
        items: [
          tray.MenuItem(key: 'show', label: l10n.trayShow),
          tray.MenuItem(
            key: 'toggle',
            label: state.connected ? l10n.disconnect : l10n.connect,
            disabled: state.busy || (!state.connected && !state.hasProfiles),
          ),
          tray.MenuItem.separator(),
          tray.MenuItem(key: 'quit', label: l10n.trayQuit),
        ],
      ),
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    await ref.read(runtimeControllerProvider.notifier).disconnect();
    await tray.trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (!_quitting) unawaited(windowManager.hide());
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showWindow());
      case 'toggle':
        final controller = ref.read(runtimeControllerProvider.notifier);
        final connected =
            ref.read(runtimeControllerProvider).connection is Connected;
        unawaited(connected ? controller.disconnect() : controller.connect());
      case 'quit':
        unawaited(_quit());
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    tray.trayManager.removeListener(this);
    super.dispose();
  }
}

Locale _resolvedLocale(String localeCode) {
  final explicit = localeForSetting(localeCode);
  if (explicit != null) return explicit;
  final system = WidgetsBinding.instance.platformDispatcher.locale;
  return AppLocalizations.supportedLocales.firstWhere(
    (locale) => locale.languageCode == system.languageCode,
    orElse: () => AppLocalizations.supportedLocales.first,
  );
}

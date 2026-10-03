import 'package:adb_helper/app_shell.dart';
import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/gateway/fake_device_gateway.dart';
import 'package:adb_helper/core/settings/app_settings.dart';
import 'package:adb_helper/features/devices/devices_screen.dart';
import 'package:adb_helper/features/files/files_screen.dart';
import 'package:adb_helper/features/settings/settings_screen.dart';
import 'package:adb_helper/features/terminal/terminal_screen.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/devices',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/devices', builder: (context, state) => const DevicesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/terminal', builder: (context, state) => const TerminalScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/files', builder: (context, state) => const FilesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

void main() {
  runApp(const AdbHelperApp());
}

class AdbHelperApp extends StatelessWidget {
  const AdbHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        deviceGatewayProvider.overrideWithValue(FakeDeviceGateway()),
      ],
      child: const _AdbHelperMaterialApp(),
    );
  }
}

class _AdbHelperMaterialApp extends ConsumerWidget {
  const _AdbHelperMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lightScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF287A52));
    final darkScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: const Color(0xFF69C492),
    );
    final amoledScheme = darkScheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF080808),
      surfaceContainer: const Color(0xFF101010),
      surfaceContainerHigh: const Color(0xFF171717),
      surfaceContainerHighest: const Color(0xFF202020),
    );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: settings.theme == AppTheme.amoled ? amoledScheme : darkScheme,
        scaffoldBackgroundColor: settings.theme == AppTheme.amoled ? Colors.black : null,
      ),
      themeMode: settings.themeMode,
    );
  }
}

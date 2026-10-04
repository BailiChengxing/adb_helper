import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, simplifiedChinese, traditionalChinese, english }
enum AppTheme { system, light, dark, amoled }

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.system,
    this.theme = AppTheme.system,
    this.terminalFontSize = 13,
    this.confirmDangerousActions = true,
    this.platformToolsPath = '',
    this.shellTransport = Transport.local,
  });

  final AppLanguage language;
  final AppTheme theme;
  final double terminalFontSize;
  final bool confirmDangerousActions;
  final String platformToolsPath;
  final Transport shellTransport;

  Locale? get locale => switch (language) {
    AppLanguage.system => null,
    AppLanguage.simplifiedChinese => const Locale('zh'),
    AppLanguage.traditionalChinese => const Locale('zh', 'TW'),
    AppLanguage.english => const Locale('en'),
  };

  ThemeMode get themeMode => switch (theme) {
    AppTheme.system => ThemeMode.system,
    AppTheme.light => ThemeMode.light,
    AppTheme.dark || AppTheme.amoled => ThemeMode.dark,
  };

  AppSettings copyWith({
    AppLanguage? language,
    AppTheme? theme,
    double? terminalFontSize,
    bool? confirmDangerousActions,
    String? platformToolsPath,
    Transport? shellTransport,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
      confirmDangerousActions: confirmDangerousActions ?? this.confirmDangerousActions,
      platformToolsPath: platformToolsPath ?? this.platformToolsPath,
      shellTransport: shellTransport ?? this.shellTransport,
    );
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsController, AppSettings>(
  (ref) => AppSettingsController(),
);

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController() : super(const AppSettings()) {
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    state = AppSettings(
      language: AppLanguage.values[preferences.getInt('language') ?? 0],
      theme: AppTheme.values[preferences.getInt('theme') ?? 0],
      terminalFontSize: preferences.getDouble('terminalFontSize') ?? 13,
      confirmDangerousActions: preferences.getBool('confirmDangerousActions') ?? true,
      platformToolsPath: preferences.getString('platformToolsPath') ?? '',
      shellTransport: Transport.values[
        preferences.getInt('shellTransport') ?? Transport.local.index
      ],
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('language', language.index);
  }

  Future<void> setTheme(AppTheme theme) async {
    state = state.copyWith(theme: theme);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('theme', theme.index);
  }

  Future<void> setTerminalFontSize(double size) async {
    state = state.copyWith(terminalFontSize: size);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('terminalFontSize', size);
  }

  Future<void> setDangerousConfirmation(bool value) async {
    state = state.copyWith(confirmDangerousActions: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('confirmDangerousActions', value);
  }

  Future<void> setPlatformToolsPath(String path) async {
    state = state.copyWith(platformToolsPath: path);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('platformToolsPath', path);
  }

  Future<void> setShellTransport(Transport transport) async {
    state = state.copyWith(shellTransport: transport);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('shellTransport', transport.index);
  }
}

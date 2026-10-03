// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ADB Tool';

  @override
  String get devices => 'Devices';

  @override
  String get terminal => 'Terminal';

  @override
  String get files => 'Files';

  @override
  String get settings => 'Settings';

  @override
  String get refresh => 'Refresh device list';

  @override
  String get noDevices => 'No devices found';

  @override
  String get demoMode => 'Demo mode · hardware backends are not connected';

  @override
  String get connect => 'Connect';

  @override
  String get pairWireless => 'Pair over Wi-Fi';

  @override
  String get pairTitle => 'Pair wireless device';

  @override
  String get host => 'IP address or host';

  @override
  String get pairingPort => 'Pairing port';

  @override
  String get pairingCode => '6-digit pairing code';

  @override
  String get cancel => 'Cancel';

  @override
  String get pair => 'Pair';

  @override
  String get pairSuccess => 'Pairing completed';

  @override
  String get pairFailed => 'Pairing failed';

  @override
  String get invalidPairing => 'Enter a host, port, and 6-digit code';

  @override
  String get transportLocal => 'Local shell';

  @override
  String get transportShizuku => 'Shizuku';

  @override
  String get transportRoot => 'Root';

  @override
  String get transportWireless => 'Wireless ADB';

  @override
  String get transportOtg => 'USB OTG';

  @override
  String get sessionReady => 'Session ready';

  @override
  String get sessionClosed => 'Session closed';

  @override
  String get newSession => 'New session';

  @override
  String get closeSession => 'Close session';

  @override
  String get commandHint => 'Enter a shell command';

  @override
  String get sendCommand => 'Run command';

  @override
  String get terminalWelcome => 'Connected. Enter a command below.';

  @override
  String get clearOutput => 'Clear output';

  @override
  String get filesRoot => 'Device storage';

  @override
  String get pushDemoFile => 'Push demo file';

  @override
  String get pullDemoFile => 'Pull selected file';

  @override
  String get uploadComplete => 'Demo upload completed';

  @override
  String get downloadComplete => 'Demo download completed';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get renameTo => 'New name';

  @override
  String confirmDelete(String name) {
    return 'Delete $name?';
  }

  @override
  String get emptyFolder => 'This folder is empty';

  @override
  String get theme => 'Appearance';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAmoled => 'AMOLED black';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow device language';

  @override
  String get languageSimplified => '简体中文';

  @override
  String get languageTraditional => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get terminalFont => 'Terminal font size';

  @override
  String get dangerousActions => 'Confirm dangerous commands';

  @override
  String get dangerousActionsDescription =>
      'Ask before running reboot, flash, or rm commands';

  @override
  String get platformTools => 'Platform-tools path';

  @override
  String get editPath => 'Edit path';

  @override
  String get path => 'Path';

  @override
  String get save => 'Save';

  @override
  String get defaultTools => 'Bundled tools (not installed yet)';

  @override
  String get about => 'About';

  @override
  String get demoNotice =>
      'The current gateway is a simulator. Device, file-sync, fastboot, and sideload operations require native and desktop backends.';

  @override
  String get runAnyway => 'Run anyway';

  @override
  String get commandNeedsConfirmation => 'Confirm dangerous command';

  @override
  String commandOutput(String command) {
    return 'Command: $command';
  }
}

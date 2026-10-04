import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ADB Tool'**
  String get appTitle;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh device list'**
  String get refresh;

  /// No description provided for @noDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevices;

  /// No description provided for @demoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode · hardware backends are not connected'**
  String get demoMode;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @pairWireless.
  ///
  /// In en, this message translates to:
  /// **'Pair over Wi-Fi'**
  String get pairWireless;

  /// No description provided for @pairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair wireless device'**
  String get pairTitle;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'IP address or host'**
  String get host;

  /// No description provided for @pairInstructions.
  ///
  /// In en, this message translates to:
  /// **'Use the target device\'s Wireless debugging pairing screen. Keep both devices on the same Wi-Fi network.'**
  String get pairInstructions;

  /// No description provided for @pairingPort.
  ///
  /// In en, this message translates to:
  /// **'Pairing port'**
  String get pairingPort;

  /// No description provided for @pairingCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit pairing code'**
  String get pairingCode;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @pair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get pair;

  /// No description provided for @pairSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pairing completed'**
  String get pairSuccess;

  /// No description provided for @pairPendingDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Paired. Keep Wireless debugging enabled, then refresh the device list.'**
  String get pairPendingDiscovery;

  /// No description provided for @pairFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed'**
  String get pairFailed;

  /// No description provided for @invalidPairing.
  ///
  /// In en, this message translates to:
  /// **'Enter a host, port, and 6-digit code'**
  String get invalidPairing;

  /// No description provided for @transportLocal.
  ///
  /// In en, this message translates to:
  /// **'Local shell'**
  String get transportLocal;

  /// No description provided for @transportShizuku.
  ///
  /// In en, this message translates to:
  /// **'Shizuku'**
  String get transportShizuku;

  /// No description provided for @transportRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get transportRoot;

  /// No description provided for @transportWireless.
  ///
  /// In en, this message translates to:
  /// **'Wireless ADB'**
  String get transportWireless;

  /// No description provided for @transportOtg.
  ///
  /// In en, this message translates to:
  /// **'USB OTG'**
  String get transportOtg;

  /// No description provided for @transportUsb.
  ///
  /// In en, this message translates to:
  /// **'USB ADB'**
  String get transportUsb;

  /// No description provided for @sessionReady.
  ///
  /// In en, this message translates to:
  /// **'Session ready'**
  String get sessionReady;

  /// No description provided for @sessionClosed.
  ///
  /// In en, this message translates to:
  /// **'Session closed'**
  String get sessionClosed;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @closeSession.
  ///
  /// In en, this message translates to:
  /// **'Close session'**
  String get closeSession;

  /// No description provided for @commandHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a shell command'**
  String get commandHint;

  /// No description provided for @sendCommand.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get sendCommand;

  /// No description provided for @terminalWelcome.
  ///
  /// In en, this message translates to:
  /// **'Connected. Enter a command below.'**
  String get terminalWelcome;

  /// No description provided for @clearOutput.
  ///
  /// In en, this message translates to:
  /// **'Clear output'**
  String get clearOutput;

  /// No description provided for @filesRoot.
  ///
  /// In en, this message translates to:
  /// **'Device storage'**
  String get filesRoot;

  /// No description provided for @pushDemoFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get pushDemoFile;

  /// No description provided for @pullDemoFile.
  ///
  /// In en, this message translates to:
  /// **'Download file'**
  String get pullDemoFile;

  /// No description provided for @uploadComplete.
  ///
  /// In en, this message translates to:
  /// **'File uploaded'**
  String get uploadComplete;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'File downloaded'**
  String get downloadComplete;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameTo.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get renameTo;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String confirmDelete(String name);

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyFolder;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get theme;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED black'**
  String get themeAmoled;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow device language'**
  String get languageSystem;

  /// No description provided for @languageSimplified.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageSimplified;

  /// No description provided for @languageTraditional.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageTraditional;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @terminalFont.
  ///
  /// In en, this message translates to:
  /// **'Terminal font size'**
  String get terminalFont;

  /// No description provided for @dangerousActions.
  ///
  /// In en, this message translates to:
  /// **'Confirm dangerous commands'**
  String get dangerousActions;

  /// No description provided for @dangerousActionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask before running reboot, flash, or rm commands'**
  String get dangerousActionsDescription;

  /// No description provided for @platformTools.
  ///
  /// In en, this message translates to:
  /// **'Platform-tools path'**
  String get platformTools;

  /// No description provided for @editPath.
  ///
  /// In en, this message translates to:
  /// **'Edit path'**
  String get editPath;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @defaultTools.
  ///
  /// In en, this message translates to:
  /// **'Use bundled platform-tools or adb from PATH'**
  String get defaultTools;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @demoNotice.
  ///
  /// In en, this message translates to:
  /// **'Desktop Windows, macOS, and Linux use the local ADB server and bundled platform-tools. Fastboot flashing, reboot, and ADB sideload are available on desktop builds; Android provides native device, shell, app, and file operations. scrcpy mirroring is not implemented.'**
  String get demoNotice;

  /// No description provided for @runAnyway.
  ///
  /// In en, this message translates to:
  /// **'Run anyway'**
  String get runAnyway;

  /// No description provided for @commandNeedsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm dangerous command'**
  String get commandNeedsConfirmation;

  /// No description provided for @commandOutput.
  ///
  /// In en, this message translates to:
  /// **'Command: {command}'**
  String commandOutput(String command);

  /// No description provided for @shellExecution.
  ///
  /// In en, this message translates to:
  /// **'Shell execution'**
  String get shellExecution;

  /// No description provided for @shizukuPermission.
  ///
  /// In en, this message translates to:
  /// **'Shizuku permission'**
  String get shizukuPermission;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Permission granted'**
  String get permissionGranted;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionRequired;

  /// No description provided for @shizukuUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shizuku is not running'**
  String get shizukuUnavailable;

  /// No description provided for @checkingPermission.
  ///
  /// In en, this message translates to:
  /// **'Checking permission…'**
  String get checkingPermission;

  /// No description provided for @requestPermission.
  ///
  /// In en, this message translates to:
  /// **'Request permission'**
  String get requestPermission;

  /// No description provided for @rootPermission.
  ///
  /// In en, this message translates to:
  /// **'Root access'**
  String get rootPermission;

  /// No description provided for @rootUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Root access is unavailable'**
  String get rootUnavailable;

  /// No description provided for @localShellDescription.
  ///
  /// In en, this message translates to:
  /// **'Run commands as the app user'**
  String get localShellDescription;

  /// No description provided for @deviceWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Device workbench'**
  String get deviceWorkbench;

  /// No description provided for @deviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices available'**
  String deviceCount(int count);

  /// No description provided for @deviceConnectHelp.
  ///
  /// In en, this message translates to:
  /// **'Connect a device with USB debugging or pair it over Wi-Fi.'**
  String get deviceConnectHelp;

  /// No description provided for @applications.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get applications;

  /// No description provided for @installApk.
  ///
  /// In en, this message translates to:
  /// **'Install APK'**
  String get installApk;

  /// No description provided for @searchApplications.
  ///
  /// In en, this message translates to:
  /// **'Search app name or package'**
  String get searchApplications;

  /// No description provided for @showSystemApps.
  ///
  /// In en, this message translates to:
  /// **'Show system apps'**
  String get showSystemApps;

  /// No description provided for @systemApp.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemApp;

  /// No description provided for @noApplications.
  ///
  /// In en, this message translates to:
  /// **'No applications match this filter'**
  String get noApplications;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @launchApplication.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launchApplication;

  /// No description provided for @forceStopApplication.
  ///
  /// In en, this message translates to:
  /// **'Force stop'**
  String get forceStopApplication;

  /// No description provided for @clearApplicationData.
  ///
  /// In en, this message translates to:
  /// **'Clear data'**
  String get clearApplicationData;

  /// No description provided for @disableApplication.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disableApplication;

  /// No description provided for @enableApplication.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableApplication;

  /// No description provided for @applicationSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get applicationSettings;

  /// No description provided for @uninstallApplication.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstallApplication;

  /// No description provided for @confirmClearAppData.
  ///
  /// In en, this message translates to:
  /// **'Clear all data for {packageName}?'**
  String confirmClearAppData(String packageName);

  /// No description provided for @confirmUninstallApp.
  ///
  /// In en, this message translates to:
  /// **'Uninstall {packageName} for this user?'**
  String confirmUninstallApp(String packageName);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @installSuccess.
  ///
  /// In en, this message translates to:
  /// **'APK installed'**
  String get installSuccess;

  /// No description provided for @launchSuccess.
  ///
  /// In en, this message translates to:
  /// **'Application launched'**
  String get launchSuccess;

  /// No description provided for @operationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation completed'**
  String get operationSuccess;

  /// No description provided for @clearAppDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Application data cleared'**
  String get clearAppDataSuccess;

  /// No description provided for @mirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get mirror;

  /// No description provided for @mirrorNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'scrcpy mirroring is not implemented yet.'**
  String get mirrorNotAvailable;

  /// No description provided for @noFileDevice.
  ///
  /// In en, this message translates to:
  /// **'No supported ADB device is available for file operations.'**
  String get noFileDevice;

  /// No description provided for @fileDeviceHelp.
  ///
  /// In en, this message translates to:
  /// **'Browse local files or connect a device over wireless ADB or USB OTG.'**
  String get fileDeviceHelp;

  /// No description provided for @targetDevice.
  ///
  /// In en, this message translates to:
  /// **'Target device'**
  String get targetDevice;

  /// No description provided for @parentFolder.
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get parentFolder;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get uploadFile;

  /// No description provided for @downloadFile.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadFile;

  /// No description provided for @remoteFileName.
  ///
  /// In en, this message translates to:
  /// **'Remote file name'**
  String get remoteFileName;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @invalidFileName.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid file name without path separators.'**
  String get invalidFileName;

  /// No description provided for @scanLocalNetwork.
  ///
  /// In en, this message translates to:
  /// **'Scan local network'**
  String get scanLocalNetwork;

  /// No description provided for @wirelessScanResult.
  ///
  /// In en, this message translates to:
  /// **'Found {count} wireless ADB device(s)'**
  String wirelessScanResult(int count);

  /// No description provided for @noWirelessDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No reachable wireless ADB devices found. Ensure the device is on the same network and Wireless debugging or TCP/IP port 5555 is enabled.'**
  String get noWirelessDevicesFound;

  /// No description provided for @fileAccessPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow ADB Helper to manage all files to browse internal storage, then retry.'**
  String get fileAccessPermissionRequired;

  /// No description provided for @connectByIp.
  ///
  /// In en, this message translates to:
  /// **'Connect by IP and port'**
  String get connectByIp;

  /// No description provided for @ipAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get ipAddress;

  /// No description provided for @adbPort.
  ///
  /// In en, this message translates to:
  /// **'ADB port'**
  String get adbPort;

  /// No description provided for @invalidIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IPv4 or IPv6 address'**
  String get invalidIpAddress;

  /// No description provided for @invalidAdbPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1 to 65535'**
  String get invalidAdbPort;

  /// No description provided for @directConnectHelp.
  ///
  /// In en, this message translates to:
  /// **'Android secure wireless debugging must be paired first. Desktop ADB-over-TCP must already be enabled on the target.'**
  String get directConnectHelp;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to {label}'**
  String deviceConnected(String label);

  /// No description provided for @deviceActions.
  ///
  /// In en, this message translates to:
  /// **'Device actions'**
  String get deviceActions;

  /// No description provided for @storageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get storageLocation;

  /// No description provided for @systemRoot.
  ///
  /// In en, this message translates to:
  /// **'System root directory'**
  String get systemRoot;

  /// No description provided for @internalStorage.
  ///
  /// In en, this message translates to:
  /// **'Internal storage'**
  String get internalStorage;

  /// No description provided for @androidOnlyPermissions.
  ///
  /// In en, this message translates to:
  /// **'Root and Shizuku execution are only available on Android.'**
  String get androidOnlyPermissions;

  /// No description provided for @shizukuPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Shizuku permission was not granted. Check that Shizuku is running and approve this app.'**
  String get shizukuPermissionNotGranted;

  /// No description provided for @deviceInformation.
  ///
  /// In en, this message translates to:
  /// **'Device information'**
  String get deviceInformation;

  /// No description provided for @noDeviceInformation.
  ///
  /// In en, this message translates to:
  /// **'No device information is available.'**
  String get noDeviceInformation;

  /// No description provided for @installAab.
  ///
  /// In en, this message translates to:
  /// **'Install AAB'**
  String get installAab;

  /// No description provided for @installFromThisDevice.
  ///
  /// In en, this message translates to:
  /// **'From this device'**
  String get installFromThisDevice;

  /// No description provided for @noHostApplications.
  ///
  /// In en, this message translates to:
  /// **'No installed applications were found on this device.'**
  String get noHostApplications;

  /// No description provided for @aboutToolName.
  ///
  /// In en, this message translates to:
  /// **'ADB Helper'**
  String get aboutToolName;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A practical Android device workbench'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to Android devices and manage shell sessions, files, and applications from one place.'**
  String get aboutDescription;

  /// No description provided for @aboutCapabilities.
  ///
  /// In en, this message translates to:
  /// **'What you can do'**
  String get aboutCapabilities;

  /// No description provided for @aboutDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Device connections'**
  String get aboutDevicesTitle;

  /// No description provided for @aboutDevicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover ADB devices, scan the local network, or connect by IP and port.'**
  String get aboutDevicesDescription;

  /// No description provided for @aboutTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get aboutTerminalTitle;

  /// No description provided for @aboutTerminalDescription.
  ///
  /// In en, this message translates to:
  /// **'Run commands through local shell, Shizuku, Root, wireless ADB, or USB OTG.'**
  String get aboutTerminalDescription;

  /// No description provided for @aboutFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'File manager'**
  String get aboutFilesTitle;

  /// No description provided for @aboutFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse the system root or internal storage, and transfer files to and from a device.'**
  String get aboutFilesDescription;

  /// No description provided for @aboutAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Application manager'**
  String get aboutAppsTitle;

  /// No description provided for @aboutAppsDescription.
  ///
  /// In en, this message translates to:
  /// **'Install, launch, stop, enable, disable, clear, and uninstall applications.'**
  String get aboutAppsDescription;

  /// No description provided for @aboutProjectDescription.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter for Android device maintenance and development workflows.'**
  String get aboutProjectDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 · scrcpy mirroring is not implemented yet'**
  String get aboutVersion;

  /// No description provided for @fastbootSideload.
  ///
  /// In en, this message translates to:
  /// **'Fastboot / Sideload'**
  String get fastbootSideload;

  /// No description provided for @fastboot.
  ///
  /// In en, this message translates to:
  /// **'Fastboot'**
  String get fastboot;

  /// No description provided for @sideload.
  ///
  /// In en, this message translates to:
  /// **'Sideload'**
  String get sideload;

  /// No description provided for @fastbootDevices.
  ///
  /// In en, this message translates to:
  /// **'Fastboot devices'**
  String get fastbootDevices;

  /// No description provided for @noFastbootDevices.
  ///
  /// In en, this message translates to:
  /// **'No fastboot devices found'**
  String get noFastbootDevices;

  /// No description provided for @selectImage.
  ///
  /// In en, this message translates to:
  /// **'Select image'**
  String get selectImage;

  /// No description provided for @selectZip.
  ///
  /// In en, this message translates to:
  /// **'Select ZIP package'**
  String get selectZip;

  /// No description provided for @partition.
  ///
  /// In en, this message translates to:
  /// **'Partition'**
  String get partition;

  /// No description provided for @flashImage.
  ///
  /// In en, this message translates to:
  /// **'Flash image'**
  String get flashImage;

  /// No description provided for @rebootMode.
  ///
  /// In en, this message translates to:
  /// **'Reboot mode'**
  String get rebootMode;

  /// No description provided for @rebootSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get rebootSystem;

  /// No description provided for @rebootBootloader.
  ///
  /// In en, this message translates to:
  /// **'Bootloader'**
  String get rebootBootloader;

  /// No description provided for @rebootRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get rebootRecovery;

  /// No description provided for @startSideload.
  ///
  /// In en, this message translates to:
  /// **'Start sideload'**
  String get startSideload;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

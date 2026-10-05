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
  String get pairInstructions =>
      'Use the target device\'s Wireless debugging pairing screen. Keep both devices on the same Wi-Fi network.';

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
  String get pairPendingDiscovery =>
      'Paired. Keep Wireless debugging enabled, then refresh the device list.';

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
  String get transportUsb => 'USB ADB';

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
  String get pushDemoFile => 'Upload file';

  @override
  String get pullDemoFile => 'Download file';

  @override
  String get uploadComplete => 'File uploaded';

  @override
  String get downloadComplete => 'File downloaded';

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
  String get defaultTools => 'Use bundled platform-tools or adb from PATH';

  @override
  String get about => 'About';

  @override
  String get demoNotice =>
      'Desktop Windows, macOS, and Linux use the local ADB server and bundled platform-tools. Fastboot flashing, reboot, and ADB sideload are available on desktop builds; Android provides native device, shell, app, and file operations. scrcpy mirroring is not implemented.';

  @override
  String get runAnyway => 'Run anyway';

  @override
  String get commandNeedsConfirmation => 'Confirm dangerous command';

  @override
  String commandOutput(String command) {
    return 'Command: $command';
  }

  @override
  String get shellExecution => 'Shell execution';

  @override
  String get shizukuPermission => 'Shizuku permission';

  @override
  String get permissionGranted => 'Permission granted';

  @override
  String get permissionRequired => 'Permission required';

  @override
  String get shizukuUnavailable => 'Shizuku is not running';

  @override
  String get checkingPermission => 'Checking permission…';

  @override
  String get requestPermission => 'Request permission';

  @override
  String get rootPermission => 'Root access';

  @override
  String get rootUnavailable => 'Root access is unavailable';

  @override
  String get localShellDescription => 'Run commands as the app user';

  @override
  String get deviceWorkbench => 'Device workbench';

  @override
  String deviceCount(int count) {
    return '$count devices available';
  }

  @override
  String get deviceConnectHelp =>
      'Connect a device with USB debugging or pair it over Wi-Fi.';

  @override
  String get applications => 'Applications';

  @override
  String get installApk => 'Install APK';

  @override
  String get searchApplications => 'Search app name or package';

  @override
  String get showSystemApps => 'Show system apps';

  @override
  String get systemApp => 'System';

  @override
  String get noApplications => 'No applications match this filter';

  @override
  String get retry => 'Retry';

  @override
  String get launchApplication => 'Launch';

  @override
  String get forceStopApplication => 'Force stop';

  @override
  String get clearApplicationData => 'Clear data';

  @override
  String get disableApplication => 'Disable';

  @override
  String get enableApplication => 'Enable';

  @override
  String get applicationSettings => 'App settings';

  @override
  String get uninstallApplication => 'Uninstall';

  @override
  String confirmClearAppData(String packageName) {
    return 'Clear all data for $packageName?';
  }

  @override
  String confirmUninstallApp(String packageName) {
    return 'Uninstall $packageName for this user?';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String get installSuccess => 'APK installed';

  @override
  String get launchSuccess => 'Application launched';

  @override
  String get operationSuccess => 'Operation completed';

  @override
  String get clearAppDataSuccess => 'Application data cleared';

  @override
  String get mirror => 'Mirror';

  @override
  String get mirrorNotAvailable => 'scrcpy mirroring is not implemented yet.';

  @override
  String get noFileDevice =>
      'No supported ADB device is available for file operations.';

  @override
  String get fileDeviceHelp =>
      'Browse local files or connect a device over wireless ADB or USB OTG.';

  @override
  String get targetDevice => 'Target device';

  @override
  String get parentFolder => 'Parent folder';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get downloadFile => 'Download';

  @override
  String get remoteFileName => 'Remote file name';

  @override
  String get fileName => 'File name';

  @override
  String get invalidFileName =>
      'Enter a valid file name without path separators.';

  @override
  String get scanLocalNetwork => 'Scan local network';

  @override
  String wirelessScanResult(int count) {
    return 'Found $count wireless ADB device(s)';
  }

  @override
  String get noWirelessDevicesFound =>
      'No reachable wireless ADB devices found. Ensure the device is on the same network and Wireless debugging or TCP/IP port 5555 is enabled.';

  @override
  String get fileAccessPermissionRequired =>
      'Allow ADB Helper to manage all files to browse internal storage, then retry.';

  @override
  String get connectByIp => 'Connect by IP and port';

  @override
  String get ipAddress => 'IP address';

  @override
  String get adbPort => 'ADB port';

  @override
  String get invalidIpAddress => 'Enter a valid IPv4 or IPv6 address';

  @override
  String get invalidAdbPort => 'Enter a port from 1 to 65535';

  @override
  String get directConnectHelp =>
      'Android secure wireless debugging must be paired first. Desktop ADB-over-TCP must already be enabled on the target.';

  @override
  String deviceConnected(String label) {
    return 'Connected to $label';
  }

  @override
  String get deviceActions => 'Device actions';

  @override
  String get storageLocation => 'Storage location';

  @override
  String get systemRoot => 'System root directory';

  @override
  String get internalStorage => 'Internal storage';

  @override
  String get androidOnlyPermissions =>
      'Root and Shizuku execution are only available on Android.';

  @override
  String get shizukuPermissionNotGranted =>
      'Shizuku permission was not granted. Check that Shizuku is running and approve this app.';

  @override
  String get deviceInformation => 'Device information';

  @override
  String get noDeviceInformation => 'No device information is available.';

  @override
  String get installAab => 'Install AAB';

  @override
  String get installFromThisDevice => 'From this device';

  @override
  String get noHostApplications =>
      'No installed applications were found on this device.';

  @override
  String get aboutToolName => 'ADB Helper';

  @override
  String get aboutTagline => 'A practical Android device workbench';

  @override
  String get aboutDescription =>
      'Connect to Android devices and manage shell sessions, files, and applications from one place.';

  @override
  String get aboutCapabilities => 'What you can do';

  @override
  String get aboutDevicesTitle => 'Device connections';

  @override
  String get aboutDevicesDescription =>
      'Discover ADB devices, scan the local network, or connect by IP and port.';

  @override
  String get aboutTerminalTitle => 'Terminal';

  @override
  String get aboutTerminalDescription =>
      'Run commands through local shell, Shizuku, Root, wireless ADB, or USB OTG.';

  @override
  String get aboutFilesTitle => 'File manager';

  @override
  String get aboutFilesDescription =>
      'Browse the system root or internal storage, and transfer files to and from a device.';

  @override
  String get aboutAppsTitle => 'Application manager';

  @override
  String get aboutAppsDescription =>
      'Install, launch, stop, enable, disable, clear, and uninstall applications.';

  @override
  String get aboutProjectDescription =>
      'Built with Flutter for Android device maintenance and development workflows.';

  @override
  String get aboutVersion =>
      'Version 1.0.0 · scrcpy mirroring is not implemented yet';

  @override
  String get fastbootSideload => 'Fastboot / Sideload';

  @override
  String get fastboot => 'Fastboot';

  @override
  String get sideload => 'Sideload';

  @override
  String get fastbootDevices => 'Fastboot devices';

  @override
  String get noFastbootDevices => 'No fastboot devices found';

  @override
  String get selectImage => 'Select image';

  @override
  String get selectZip => 'Select ZIP package';

  @override
  String get partition => 'Partition';

  @override
  String get flashImage => 'Flash image';

  @override
  String get rebootMode => 'Reboot mode';

  @override
  String get rebootSystem => 'System';

  @override
  String get rebootBootloader => 'Bootloader';

  @override
  String get rebootRecovery => 'Recovery';

  @override
  String get startSideload => 'Start sideload';

  @override
  String get tools => 'Tools';

  @override
  String get wirelessDebug => 'Wireless ADB debugging';

  @override
  String get wirelessEnable => 'Enable wireless debugging';

  @override
  String get wirelessDisable => 'Disable wireless debugging';

  @override
  String get wirelessEnabled => 'Wireless debugging is enabled';

  @override
  String get wirelessDisabled => 'Wireless debugging is disabled';

  @override
  String get screenTools => 'Screen tools';

  @override
  String get screenshot => 'Screenshot';

  @override
  String get screenOff => 'Screen off without locking';

  @override
  String get screenOffHelp =>
      'Turn the screen off. Whether the device locks depends on the device security settings.';

  @override
  String get advancedReboot => 'Advanced reboot';

  @override
  String get displayTools => 'Display tools';

  @override
  String get dpi => 'DPI';

  @override
  String get setDpi => 'Set DPI';

  @override
  String get width => 'Width';

  @override
  String get height => 'Height';

  @override
  String get setResolution => 'Set resolution';

  @override
  String get invalidNumber => 'Enter a valid number.';

  @override
  String get installXapk => 'Install XAPK';

  @override
  String get installApks => 'Install APKS';

  @override
  String get mirrorStarting => 'Starting scrcpy mirror…';

  @override
  String get mirrorReady => 'Scrcpy mirror is ready';

  @override
  String get mirrorFailed => 'Unable to start the mirror';

  @override
  String get startMirror => 'Start mirror';

  @override
  String get stopMirror => 'Stop mirror';
}

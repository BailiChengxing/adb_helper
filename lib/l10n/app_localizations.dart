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
  /// **'Push demo file'**
  String get pushDemoFile;

  /// No description provided for @pullDemoFile.
  ///
  /// In en, this message translates to:
  /// **'Pull selected file'**
  String get pullDemoFile;

  /// No description provided for @uploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Demo upload completed'**
  String get uploadComplete;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Demo download completed'**
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
  /// **'Bundled tools (not installed yet)'**
  String get defaultTools;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @demoNotice.
  ///
  /// In en, this message translates to:
  /// **'The current gateway is a simulator. Device, file-sync, fastboot, and sideload operations require native and desktop backends.'**
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

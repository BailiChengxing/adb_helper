// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ADB 工具';

  @override
  String get devices => '设备';

  @override
  String get terminal => '终端';

  @override
  String get files => '文件';

  @override
  String get settings => '设置';

  @override
  String get refresh => '刷新设备列表';

  @override
  String get noDevices => '未发现设备';

  @override
  String get demoMode => '演示模式 · 尚未连接真实设备后端';

  @override
  String get connect => '连接';

  @override
  String get pairWireless => '无线配对';

  @override
  String get pairTitle => '配对无线设备';

  @override
  String get host => 'IP 地址或主机名';

  @override
  String get pairInstructions => '请填写目标设备「无线调试」配对页面显示的信息，并确保两台设备连接同一 Wi-Fi。';

  @override
  String get pairingPort => '配对端口';

  @override
  String get pairingCode => '6 位配对码';

  @override
  String get cancel => '取消';

  @override
  String get pair => '配对';

  @override
  String get pairSuccess => '配对完成';

  @override
  String get pairPendingDiscovery => '配对完成。请保持无线调试开启，然后刷新设备列表。';

  @override
  String get pairFailed => '配对失败';

  @override
  String get invalidPairing => '请输入主机、端口和 6 位配对码';

  @override
  String get transportLocal => '本地 Shell';

  @override
  String get transportShizuku => 'Shizuku';

  @override
  String get transportRoot => 'Root';

  @override
  String get transportWireless => '无线 ADB';

  @override
  String get transportOtg => 'USB OTG';

  @override
  String get transportUsb => 'USB ADB';

  @override
  String get sessionReady => '会话已就绪';

  @override
  String get sessionClosed => '会话已关闭';

  @override
  String get newSession => '新建会话';

  @override
  String get closeSession => '关闭会话';

  @override
  String get commandHint => '输入 Shell 命令';

  @override
  String get sendCommand => '执行命令';

  @override
  String get terminalWelcome => '已连接，请在下方输入命令。';

  @override
  String get clearOutput => '清除输出';

  @override
  String get filesRoot => '设备存储';

  @override
  String get pushDemoFile => '上传文件';

  @override
  String get pullDemoFile => '下载文件';

  @override
  String get uploadComplete => '文件已上传';

  @override
  String get downloadComplete => '文件已下载';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get renameTo => '新名称';

  @override
  String confirmDelete(String name) {
    return '确定删除 $name 吗？';
  }

  @override
  String get emptyFolder => '此文件夹为空';

  @override
  String get theme => '外观';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeAmoled => 'AMOLED 纯黑';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随设备语言';

  @override
  String get languageSimplified => '简体中文';

  @override
  String get languageTraditional => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get terminalFont => '终端字体大小';

  @override
  String get dangerousActions => '危险命令确认';

  @override
  String get dangerousActionsDescription => '执行 reboot、flash 或 rm 命令前进行确认';

  @override
  String get platformTools => 'platform-tools 路径';

  @override
  String get editPath => '编辑路径';

  @override
  String get path => '路径';

  @override
  String get save => '保存';

  @override
  String get defaultTools => '使用随应用提供的 platform-tools 或 PATH 中的 adb';

  @override
  String get about => '关于';

  @override
  String get demoNotice =>
      'Windows、macOS 和 Linux 桌面端使用本机 ADB server 和随包 platform-tools。桌面版支持 Fastboot 刷写、重启和 ADB sideload；Android 已接入原生设备、Shell、应用和文件操作。scrcpy 镜像尚未开发。';

  @override
  String get runAnyway => '仍然执行';

  @override
  String get commandNeedsConfirmation => '确认危险命令';

  @override
  String commandOutput(String command) {
    return '命令：$command';
  }

  @override
  String get shellExecution => 'Shell 执行身份';

  @override
  String get shizukuPermission => 'Shizuku 权限';

  @override
  String get permissionGranted => '已获得权限';

  @override
  String get permissionRequired => '需要授权';

  @override
  String get shizukuUnavailable => 'Shizuku 服务未运行';

  @override
  String get checkingPermission => '正在检查权限…';

  @override
  String get requestPermission => '请求权限';

  @override
  String get rootPermission => 'Root 权限';

  @override
  String get rootUnavailable => '当前设备未提供 Root 权限';

  @override
  String get localShellDescription => '以应用自身身份运行命令';

  @override
  String get deviceWorkbench => '设备工作台';

  @override
  String deviceCount(int count) {
    return '可用设备：$count 台';
  }

  @override
  String get deviceConnectHelp => '请通过 USB 调试连接设备，或使用无线调试配对。';

  @override
  String get applications => '应用';

  @override
  String get installApk => '安装 APK';

  @override
  String get searchApplications => '搜索应用名称或包名';

  @override
  String get showSystemApps => '显示系统应用';

  @override
  String get systemApp => '系统应用';

  @override
  String get noApplications => '没有符合条件的应用';

  @override
  String get retry => '重试';

  @override
  String get launchApplication => '启动';

  @override
  String get forceStopApplication => '强行停止';

  @override
  String get clearApplicationData => '清除数据';

  @override
  String get disableApplication => '停用';

  @override
  String get enableApplication => '启用';

  @override
  String get applicationSettings => '应用设置';

  @override
  String get uninstallApplication => '卸载';

  @override
  String confirmClearAppData(String packageName) {
    return '确定清除 $packageName 的所有应用数据吗？';
  }

  @override
  String confirmUninstallApp(String packageName) {
    return '确定为当前用户卸载 $packageName 吗？';
  }

  @override
  String get confirm => '确认';

  @override
  String get installSuccess => 'APK 安装成功';

  @override
  String get launchSuccess => '应用已启动';

  @override
  String get operationSuccess => '操作已完成';

  @override
  String get clearAppDataSuccess => '应用数据已清除';

  @override
  String get mirror => '镜像';

  @override
  String get mirrorNotAvailable => 'scrcpy 镜像功能暂未开发。';

  @override
  String get noFileDevice => '没有可用于文件操作的 ADB 设备。';

  @override
  String get fileDeviceHelp => '可浏览本机文件，或通过无线 ADB、USB OTG 浏览已连接设备。';

  @override
  String get targetDevice => '目标设备';

  @override
  String get parentFolder => '上级目录';

  @override
  String get uploadFile => '上传文件';

  @override
  String get downloadFile => '下载';

  @override
  String get remoteFileName => '设备端文件名';

  @override
  String get fileName => '文件名';

  @override
  String get invalidFileName => '请输入有效文件名，不能包含路径分隔符。';

  @override
  String get scanLocalNetwork => '扫描本地网络';

  @override
  String wirelessScanResult(int count) {
    return '扫描发现 $count 个无线 ADB 设备';
  }

  @override
  String get noWirelessDevicesFound =>
      '未发现可连接的无线 ADB 设备。请确认设备与本机处于同一网络，并已启用无线调试或 TCP/IP 端口 5555。';

  @override
  String get fileAccessPermissionRequired =>
      '需要允许 ADB Helper 管理所有文件，才能浏览内部存储。授权后请重试。';

  @override
  String get connectByIp => '通过 IP 和端口直连';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get adbPort => 'ADB 端口';

  @override
  String get invalidIpAddress => '请输入有效的 IPv4 或 IPv6 地址';

  @override
  String get invalidAdbPort => '请输入 1 到 65535 之间的端口';

  @override
  String get directConnectHelp =>
      'Android 安全无线调试需先完成配对；桌面端连接则要求目标设备已启用 ADB 网络调试。';

  @override
  String deviceConnected(String label) {
    return '已连接到 $label';
  }

  @override
  String get deviceActions => '设备操作';

  @override
  String get storageLocation => '存储位置';

  @override
  String get systemRoot => '系统根目录';

  @override
  String get internalStorage => '内部存储';

  @override
  String get androidOnlyPermissions => 'Root 和 Shizuku 执行方式仅在 Android 上可用。';

  @override
  String get shizukuPermissionNotGranted =>
      '未获得 Shizuku 权限。请确认 Shizuku 正在运行并批准本应用的请求。';

  @override
  String get deviceInformation => '设备信息';

  @override
  String get noDeviceInformation => '没有可用的设备信息。';

  @override
  String get installAab => '安装 AAB';

  @override
  String get installFromThisDevice => '从本机安装';

  @override
  String get noHostApplications => '本机没有可用的已安装应用。';

  @override
  String get aboutToolName => 'ADB Helper';

  @override
  String get aboutTagline => '实用的 Android 设备工作台';

  @override
  String get aboutDescription => '在一个应用中连接 Android 设备，并管理 Shell 会话、文件和应用。';

  @override
  String get aboutCapabilities => '功能介绍';

  @override
  String get aboutDevicesTitle => '设备连接';

  @override
  String get aboutDevicesDescription => '发现 ADB 设备、扫描本地网络，或通过 IP 地址和端口连接。';

  @override
  String get aboutTerminalTitle => '终端';

  @override
  String get aboutTerminalDescription =>
      '通过本地 Shell、Shizuku、Root、无线 ADB 或 USB OTG 执行命令。';

  @override
  String get aboutFilesTitle => '文件管理';

  @override
  String get aboutFilesDescription => '浏览系统根目录或内部存储，并在设备与本机间传输文件。';

  @override
  String get aboutAppsTitle => '应用管理';

  @override
  String get aboutAppsDescription => '安装、启动、停止、启用、停用、清除数据和卸载应用。';

  @override
  String get aboutProjectDescription => '使用 Flutter 构建，面向 Android 设备维护和开发工作流。';

  @override
  String get aboutVersion => '版本 1.0.0 · scrcpy 镜像功能暂未开发';

  @override
  String get fastbootSideload => 'Fastboot / Sideload';

  @override
  String get fastboot => 'Fastboot';

  @override
  String get sideload => 'Sideload';

  @override
  String get fastbootDevices => 'Fastboot 设备';

  @override
  String get noFastbootDevices => '未发现 Fastboot 设备';

  @override
  String get selectImage => '选择镜像文件';

  @override
  String get selectZip => '选择 ZIP 包';

  @override
  String get partition => '分区';

  @override
  String get flashImage => '刷入镜像';

  @override
  String get rebootMode => '重启模式';

  @override
  String get rebootSystem => '系统';

  @override
  String get rebootBootloader => 'Bootloader';

  @override
  String get rebootRecovery => 'Recovery';

  @override
  String get startSideload => '开始 Sideload';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'ADB 工具';

  @override
  String get devices => '裝置';

  @override
  String get terminal => '終端機';

  @override
  String get files => '檔案';

  @override
  String get settings => '設定';

  @override
  String get refresh => '重新整理裝置清單';

  @override
  String get noDevices => '找不到裝置';

  @override
  String get demoMode => '展示模式 · 尚未連接實際裝置後端';

  @override
  String get connect => '連線';

  @override
  String get pairWireless => '無線配對';

  @override
  String get pairTitle => '配對無線裝置';

  @override
  String get host => 'IP 位址或主機名稱';

  @override
  String get pairInstructions => '請填寫目標裝置「無線偵錯」配對頁面顯示的資訊，並確認兩台裝置連線至相同 Wi-Fi。';

  @override
  String get pairingPort => '配對連接埠';

  @override
  String get pairingCode => '6 位數配對碼';

  @override
  String get cancel => '取消';

  @override
  String get pair => '配對';

  @override
  String get pairSuccess => '配對完成';

  @override
  String get pairPendingDiscovery => '配對完成。請保持無線偵錯開啟，然後重新整理裝置清單。';

  @override
  String get pairFailed => '配對失敗';

  @override
  String get invalidPairing => '請輸入主機、連接埠和 6 位數配對碼';

  @override
  String get transportLocal => '本機 Shell';

  @override
  String get transportShizuku => 'Shizuku';

  @override
  String get transportRoot => 'Root';

  @override
  String get transportWireless => '無線 ADB';

  @override
  String get transportOtg => 'USB OTG';

  @override
  String get transportUsb => 'USB ADB';

  @override
  String get sessionReady => '工作階段就緒';

  @override
  String get sessionClosed => '工作階段已關閉';

  @override
  String get newSession => '新增工作階段';

  @override
  String get closeSession => '關閉工作階段';

  @override
  String get commandHint => '輸入 Shell 命令';

  @override
  String get sendCommand => '執行命令';

  @override
  String get terminalWelcome => '已連線，請在下方輸入命令。';

  @override
  String get clearOutput => '清除輸出';

  @override
  String get filesRoot => '裝置儲存空間';

  @override
  String get pushDemoFile => '上傳檔案';

  @override
  String get pullDemoFile => '下載檔案';

  @override
  String get uploadComplete => '檔案已上傳';

  @override
  String get downloadComplete => '檔案已下載';

  @override
  String get newFolder => '新增資料夾';

  @override
  String get folderName => '資料夾名稱';

  @override
  String get delete => '刪除';

  @override
  String get rename => '重新命名';

  @override
  String get renameTo => '新名稱';

  @override
  String confirmDelete(String name) {
    return '確定要刪除 $name 嗎？';
  }

  @override
  String get emptyFolder => '此資料夾是空的';

  @override
  String get theme => '外觀';

  @override
  String get appearance => '外觀';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get themeAmoled => 'AMOLED 純黑';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨裝置語言';

  @override
  String get languageSimplified => '简体中文';

  @override
  String get languageTraditional => '繁體中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get terminalFont => '終端機字型大小';

  @override
  String get dangerousActions => '危險命令確認';

  @override
  String get dangerousActionsDescription => '執行 reboot、flash 或 rm 命令前先確認';

  @override
  String get platformTools => 'platform-tools 路徑';

  @override
  String get editPath => '編輯路徑';

  @override
  String get path => '路徑';

  @override
  String get save => '儲存';

  @override
  String get defaultTools => '使用隨應用程式提供的 platform-tools 或 PATH 中的 adb';

  @override
  String get about => '關於';

  @override
  String get demoNotice =>
      'Windows、macOS 和 Linux 桌面版使用本機 ADB server 和隨附 platform-tools。桌面版支援 Fastboot 燒錄、重啟和 ADB sideload；Android 已接入原生裝置、Shell、應用程式和檔案操作。scrcpy 鏡像尚未開發。';

  @override
  String get runAnyway => '仍要執行';

  @override
  String get commandNeedsConfirmation => '確認危險命令';

  @override
  String commandOutput(String command) {
    return '命令：$command';
  }

  @override
  String get shellExecution => 'Shell 執行身分';

  @override
  String get shizukuPermission => 'Shizuku 權限';

  @override
  String get permissionGranted => '已取得權限';

  @override
  String get permissionRequired => '需要授權';

  @override
  String get shizukuUnavailable => 'Shizuku 服務尚未執行';

  @override
  String get checkingPermission => '正在檢查權限…';

  @override
  String get requestPermission => '要求權限';

  @override
  String get rootPermission => 'Root 權限';

  @override
  String get rootUnavailable => '目前裝置未提供 Root 權限';

  @override
  String get localShellDescription => '以應用程式本身身分執行命令';

  @override
  String get deviceWorkbench => '裝置工作台';

  @override
  String deviceCount(int count) {
    return '可用裝置：$count 台';
  }

  @override
  String get deviceConnectHelp => '請透過 USB 偵錯連接裝置，或使用無線偵錯配對。';

  @override
  String get applications => '應用程式';

  @override
  String get installApk => '安裝 APK';

  @override
  String get searchApplications => '搜尋應用程式名稱或套件名稱';

  @override
  String get showSystemApps => '顯示系統應用程式';

  @override
  String get systemApp => '系統應用程式';

  @override
  String get noApplications => '沒有符合條件的應用程式';

  @override
  String get retry => '重試';

  @override
  String get launchApplication => '啟動';

  @override
  String get forceStopApplication => '強制停止';

  @override
  String get clearApplicationData => '清除資料';

  @override
  String get disableApplication => '停用';

  @override
  String get enableApplication => '啟用';

  @override
  String get applicationSettings => '應用程式設定';

  @override
  String get uninstallApplication => '解除安裝';

  @override
  String confirmClearAppData(String packageName) {
    return '確定要清除 $packageName 的所有應用程式資料嗎？';
  }

  @override
  String confirmUninstallApp(String packageName) {
    return '確定要為目前使用者解除安裝 $packageName 嗎？';
  }

  @override
  String get confirm => '確認';

  @override
  String get installSuccess => 'APK 安裝成功';

  @override
  String get launchSuccess => '應用程式已啟動';

  @override
  String get operationSuccess => '操作已完成';

  @override
  String get clearAppDataSuccess => '應用程式資料已清除';

  @override
  String get mirror => '鏡像';

  @override
  String get mirrorNotAvailable => 'scrcpy 鏡像功能尚未開發。';

  @override
  String get noFileDevice => '沒有可用於檔案操作的 ADB 裝置。';

  @override
  String get fileDeviceHelp => '可瀏覽本機檔案，或透過無線 ADB、USB OTG 瀏覽已連線裝置。';

  @override
  String get targetDevice => '目標裝置';

  @override
  String get parentFolder => '上一層資料夾';

  @override
  String get uploadFile => '上傳檔案';

  @override
  String get downloadFile => '下載';

  @override
  String get remoteFileName => '裝置端檔案名稱';

  @override
  String get fileName => '檔案名稱';

  @override
  String get invalidFileName => '請輸入有效檔案名稱，且不可包含路徑分隔符號。';

  @override
  String get scanLocalNetwork => '掃描本機網路';

  @override
  String wirelessScanResult(int count) {
    return '掃描找到 $count 個無線 ADB 裝置';
  }

  @override
  String get noWirelessDevicesFound =>
      '找不到可連線的無線 ADB 裝置。請確認裝置與本機位於同一網路，並已啟用無線偵錯或 TCP/IP 連接埠 5555。';

  @override
  String get fileAccessPermissionRequired =>
      '需要允許 ADB Helper 管理所有檔案，才能瀏覽內部儲存空間。授權後請重試。';

  @override
  String get connectByIp => '透過 IP 和連接埠直連';

  @override
  String get ipAddress => 'IP 位址';

  @override
  String get adbPort => 'ADB 連接埠';

  @override
  String get invalidIpAddress => '請輸入有效的 IPv4 或 IPv6 位址';

  @override
  String get invalidAdbPort => '請輸入 1 到 65535 之間的連接埠';

  @override
  String get directConnectHelp =>
      'Android 安全無線偵錯需先完成配對；桌面版連線則要求目標裝置已啟用 ADB 網路偵錯。';

  @override
  String deviceConnected(String label) {
    return '已連線至 $label';
  }

  @override
  String get deviceActions => '裝置操作';

  @override
  String get storageLocation => '儲存位置';

  @override
  String get systemRoot => '系統根目錄';

  @override
  String get internalStorage => '內部儲存空間';

  @override
  String get androidOnlyPermissions => 'Root 和 Shizuku 執行方式僅適用於 Android。';

  @override
  String get shizukuPermissionNotGranted =>
      '未取得 Shizuku 權限。請確認 Shizuku 正在執行並核准本應用程式的請求。';

  @override
  String get deviceInformation => '裝置資訊';

  @override
  String get noDeviceInformation => '沒有可用的裝置資訊。';

  @override
  String get installAab => '安裝 AAB';

  @override
  String get installFromThisDevice => '從本機安裝';

  @override
  String get noHostApplications => '本機沒有可用的已安裝應用程式。';

  @override
  String get aboutToolName => 'ADB Helper';

  @override
  String get aboutTagline => '實用的 Android 裝置工作台';

  @override
  String get aboutDescription =>
      '在同一個應用程式中連接 Android 裝置，並管理 Shell 工作階段、檔案和應用程式。';

  @override
  String get aboutCapabilities => '功能介紹';

  @override
  String get aboutDevicesTitle => '裝置連線';

  @override
  String get aboutDevicesDescription => '探索 ADB 裝置、掃描本機網路，或透過 IP 位址和連接埠連線。';

  @override
  String get aboutTerminalTitle => '終端機';

  @override
  String get aboutTerminalDescription =>
      '透過本機 Shell、Shizuku、Root、無線 ADB 或 USB OTG 執行命令。';

  @override
  String get aboutFilesTitle => '檔案管理';

  @override
  String get aboutFilesDescription => '瀏覽系統根目錄或內部儲存空間，並在裝置與本機間傳輸檔案。';

  @override
  String get aboutAppsTitle => '應用程式管理';

  @override
  String get aboutAppsDescription => '安裝、啟動、停止、啟用、停用、清除資料和解除安裝應用程式。';

  @override
  String get aboutProjectDescription =>
      '使用 Flutter 建置，適用於 Android 裝置維護和開發工作流程。';

  @override
  String get aboutVersion => '版本 1.0.0 · scrcpy 鏡像功能尚未開發';

  @override
  String get fastbootSideload => 'Fastboot / Sideload';

  @override
  String get fastboot => 'Fastboot';

  @override
  String get sideload => 'Sideload';

  @override
  String get fastbootDevices => 'Fastboot 裝置';

  @override
  String get noFastbootDevices => '未發現 Fastboot 裝置';

  @override
  String get selectImage => '選擇映像檔';

  @override
  String get selectZip => '選擇 ZIP 套件';

  @override
  String get partition => '分割區';

  @override
  String get flashImage => '燒錄映像';

  @override
  String get rebootMode => '重啟模式';

  @override
  String get rebootSystem => '系統';

  @override
  String get rebootBootloader => 'Bootloader';

  @override
  String get rebootRecovery => 'Recovery';

  @override
  String get startSideload => '開始 Sideload';
}

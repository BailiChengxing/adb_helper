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
  String get pushDemoFile => '推送演示文件';

  @override
  String get pullDemoFile => '拉取选中文件';

  @override
  String get uploadComplete => '演示上传完成';

  @override
  String get downloadComplete => '演示下载完成';

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
  String get defaultTools => '随包工具（尚未集成）';

  @override
  String get about => '关于';

  @override
  String get demoNotice =>
      '当前网关为模拟器。设备、文件同步、fastboot 和 sideload 操作需要后续接入原生及桌面后端。';

  @override
  String get runAnyway => '仍然执行';

  @override
  String get commandNeedsConfirmation => '确认危险命令';

  @override
  String commandOutput(String command) {
    return '命令：$command';
  }
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
  String get pushDemoFile => '推送展示檔案';

  @override
  String get pullDemoFile => '下載選取的檔案';

  @override
  String get uploadComplete => '展示上傳完成';

  @override
  String get downloadComplete => '展示下載完成';

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
  String get defaultTools => '隨附工具（尚未整合）';

  @override
  String get about => '關於';

  @override
  String get demoNotice =>
      '目前使用模擬閘道。裝置、檔案同步、fastboot 和 sideload 操作仍需接上原生與桌面後端。';

  @override
  String get runAnyway => '仍要執行';

  @override
  String get commandNeedsConfirmation => '確認危險命令';

  @override
  String commandOutput(String command) {
    return '命令：$command';
  }
}

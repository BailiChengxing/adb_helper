# ADB Helper

跨平台 ADB 调试工具的 Flutter 客户端。包含统一网关契约、响应式多页面 UI，以及简体中文、繁体中文和英文。Android 已接入本地 shell、Shizuku/root、无线 ADB 和 USB OTG；Windows/macOS/Linux 使用桌面 ADB server 网关。

## 当前能力

- 设备工作台：设备发现/刷新、局域网 mDNS 与传统 ADB TCP/IP 5555 端口扫描、无线配对，首页顶部可输入 IP+端口直连；每台设备的子菜单提供终端、文件、应用、设备信息和 scrcpy 镜像入口。
- Android 无线配对码流程及 mDNS 连接端点发现；USB OTG ADB Host 设备发现、系统 USB 调试授权及 shell 会话。
- 设置页可选择本地、Shizuku 或 Root 身份运行终端命令，并查看/请求 Shizuku 权限、检查 Root 能力。
- Android local/Shizuku/root 命令会话和 wireless/OTG ADB shell 的 stdout/stderr 流式输出。
- ADB 设备上的应用列表、APK 安装、卸载、启动、强行停止、清除数据、启用/停用及打开应用设置。Android 客户端可读取本机应用名称、图标和版本，并将 APK（含分包 APK）安装到已连接设备。
- 应用安装菜单提供 APK、AAB 和本机应用三个来源。桌面 AAB 安装需要 Java 与 `bundletool.jar`，放在所选 platform-tools 目录旁；Android 客户端目前须先将 AAB 转换成 APK。
- 多会话终端、流式 stdout/stderr/exit 事件接口、命令输入、输出清理及危险命令确认。
- Android 本机、无线 ADB 和 OTG 文件管理：目录浏览、建目录、重命名、删除、系统文件选择器上传/下载及 ADB sync 文件传输。本机浏览内部存储需要授予 Android「管理所有文件」访问权限。
- 文件浏览可在系统根目录和内部存储之间切换；导航栏仅保留「设备」「设置」「关于」。
- 关于页面介绍工具目标和设备、终端、文件、应用管理能力。
- 桌面 ADB backend 启动/复用本地 ADB server，支持设备发现、无线配对/连接、ADB shell 流式会话、单次命令、设备信息和应用操作。
- 设置项：系统/浅色/深色/AMOLED 主题、界面语言、终端字号、危险操作确认和 platform-tools 路径；使用 SharedPreferences 保存。
- 小屏底部导航、中屏 NavigationRail、大屏展开式 NavigationRail；导航项为设备、设置、关于，设备内功能页面由每台设备的操作菜单打开。

## 运行

```powershell
flutter pub get
flutter gen-l10n
flutter run
```

运行检查：

```powershell
flutter analyze
flutter test
```

## 语言

应用默认跟随系统语言，可在「设置 → 语言」选择：

- 跟随设备语言
- 简体中文
- 繁體中文
- English

翻译资源位于 `lib/l10n/app_*.arb`，由 `l10n.yaml` 配置生成。

## 架构

- `lib/core/model`：设备、会话、文件及网关契约模型。
- `lib/core/gateway`：Android、桌面 ADB 与演示用 fake adapters。
- `lib/core/settings`：Riverpod 设置状态及本地持久化。
- `lib/features`：设备、终端、文件、设置页面。
- `lib/main.dart`：Material 3 主题、本地化委托及 go_router indexed shell。

页面通过 `DeviceGateway`、`ShellSession` 和 `FileSync` 接缝运行。桌面 ADB 适配器通过本机 `adb` 命令与 server 交互。

## 后端状态与限制

Android 设备、终端、应用和文件页面使用原生 MethodChannel/EventChannel 后端；应用列表支持本机 PackageManager 及无线 ADB/USB OTG，文件管理支持本机文件系统及无线 ADB/USB OTG。本机访问内部存储时需授予「管理所有文件」权限；Android 侧 AAB 不能直接通过 Package Manager 安装，需先转换成 APK。Android 局域网扫描发现无线调试 mDNS 服务，并扫描同网段可达的传统 ADB TCP/IP 5555 端口；桌面端通过本机 ADB server 的 `adb mdns services` 查询无线调试服务。Android 11+ 无线调试设备通常使用动态端口，需配对并通过 mDNS 发现；目前桌面端未做传统 5555 子网端口扫描。Windows/macOS/Linux 会优先查找应用旁的 `platform-tools` 目录或设置中填写的 platform-tools 路径，再回退到系统 PATH 中的 `adb`。项目未将 Google platform-tools 二进制提交到源码；发行包需在对应平台随包提供该目录。Windows USB 连接需安装对应设备驱动。fastboot、sideload 和 scrcpy 镜像尚未实现（设备子菜单保留镜像入口）。首次连接无线调试设备仍需提供配对屏幕上的 IP、配对端口和 6 位配对码。

Android 协议测试及全量构建：

```powershell
.\android\gradlew.bat -p android :app:testDebugUnitTest :app:assembleDebug
```

## 平台

Flutter 工程保留 Android、Windows、macOS、Linux 工程目录。真机设备功能尚未接入；iOS 项目不是本工具目标平台。

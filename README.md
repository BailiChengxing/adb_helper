# ADB Helper

跨平台 ADB 调试工具的 Flutter 客户端。当前仓库实现 Flutter 端的 M0 演示切片：统一网关契约、可替换的模拟适配器、响应式多页面 UI，以及简体中文、繁体中文和英文。

## 当前能力

- 设备发现列表、刷新、无线配对表单、连接后打开终端会话。
- 多会话终端、流式 stdout/stderr/exit 事件接口、命令输入、输出清理及危险命令确认。
- ADB 文件同步接口的内存模拟器：目录浏览、建目录、重命名、删除、演示 push/pull。
- 设置项：系统/浅色/深色/AMOLED 主题、界面语言、终端字号、危险操作确认和 platform-tools 路径；使用 SharedPreferences 保存。
- 小屏底部导航、中屏 NavigationRail、大屏展开式 NavigationRail；Tab 状态由 `StatefulShellRoute.indexedStack` 保持。

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
- `lib/core/gateway`：`DeviceGateway` 接口与演示用 fake adapters。
- `lib/core/settings`：Riverpod 设置状态及本地持久化。
- `lib/features`：设备、终端、文件、设置页面。
- `lib/main.dart`：Material 3 主题、本地化委托及 go_router indexed shell。

页面通过 `DeviceGateway`、`ShellSession` 和 `FileSync` 接缝运行。后续原生 Android 和桌面 ADB 适配器可以替换 fake，而无需重写 UI。

## 后端状态与限制

目前设备列表、配对、命令结果和文件操作均由模拟适配器提供，不会连接或修改真实设备。仓库尚未实现规格中的 Pigeon/EventChannel bridge、Android Kotlin Shizuku/root/wireless/OTG transport、ADB sync 协议、桌面 adb server 客户端、platform-tools 打包、fastboot 或 sideload。设置页及设备页会明确提示演示状态；不要把模拟执行用于真实刷机或设备维护。

下一步建议按垂直切片接入：

1. Pigeon HostApi + EventChannel 契约和 Android local shell。
2. Shizuku/root 用户服务及持续会话清理。
3. 桌面 adb server 和随包 platform-tools。
4. 真实 ADB sync、无线配对、OTG、fastboot 与 sideload。

## 平台

Flutter 工程保留 Android、Windows、macOS、Linux 工程目录。真机设备功能尚未接入；macOS/iOS 项目不是本工具目标平台。

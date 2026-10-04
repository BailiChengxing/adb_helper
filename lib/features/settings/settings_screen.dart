import 'dart:io';

import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/core/settings/app_settings.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final executionCapabilitiesProvider =
    FutureProvider.family<Map<String, bool>, bool>((ref, checkRoot) {
      return ref
          .watch(deviceGatewayProvider)
          .executionCapabilities(checkRoot: checkRoot);
    });

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(
        executionCapabilitiesProvider(
          ref.read(appSettingsProvider).shellTransport == Transport.root,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final gateway = ref.read(deviceGatewayProvider);
    final privilegedAvailable = Platform.isAndroid;
    final checkRoot = settings.shellTransport == Transport.root;
    final capabilities = ref.watch(executionCapabilitiesProvider(checkRoot));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _sectionTitle(context, l10n.appearance),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.theme),
            subtitle: Text(_themeLabel(settings.theme, l10n)),
            trailing: IconButton(
              tooltip: l10n.theme,
              onPressed: () =>
                  _selectTheme(context, settings.theme, controller),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: DropdownButton<AppLanguage>(
              value: settings.language,
              onChanged: (value) {
                if (value != null) controller.setLanguage(value);
              },
              items: [
                DropdownMenuItem(
                  value: AppLanguage.system,
                  child: Text(l10n.languageSystem),
                ),
                DropdownMenuItem(
                  value: AppLanguage.simplifiedChinese,
                  child: Text(l10n.languageSimplified),
                ),
                DropdownMenuItem(
                  value: AppLanguage.traditionalChinese,
                  child: Text(l10n.languageTraditional),
                ),
                DropdownMenuItem(
                  value: AppLanguage.english,
                  child: Text(l10n.languageEnglish),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(l10n.terminalFont),
            subtitle: Slider(
              min: 10,
              max: 24,
              divisions: 14,
              label: settings.terminalFontSize.round().toString(),
              value: settings.terminalFontSize,
              onChanged: controller.setTerminalFontSize,
            ),
          ),
          const Divider(height: 1),
          _sectionTitle(context, l10n.shellExecution),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: Text(l10n.shellExecution),
            subtitle: Text(_executionStatus(settings.shellTransport, l10n)),
            trailing: DropdownButton<Transport>(
              value: privilegedAvailable
                  ? settings.shellTransport
                  : Transport.local,
              onChanged: (transport) async {
                if (transport == null) return;
                await controller.setShellTransport(transport);
                if (transport != Transport.shizuku) return;
                try {
                  final granted = await gateway.requestShizukuPermission();
                  ref.invalidate(executionCapabilitiesProvider(checkRoot));
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.shizukuPermissionNotGranted),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              items: [
                DropdownMenuItem(
                  value: Transport.local,
                  child: Text(l10n.transportLocal),
                ),
                DropdownMenuItem(
                  value: Transport.shizuku,
                  enabled: privilegedAvailable,
                  child: Text(l10n.transportShizuku),
                ),
                DropdownMenuItem(
                  value: Transport.root,
                  enabled: privilegedAvailable,
                  child: Text(l10n.transportRoot),
                ),
              ],
            ),
          ),
          if (!privilegedAvailable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.androidOnlyPermissions,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (settings.shellTransport == Transport.shizuku)
            ListTile(
              leading: const Icon(Icons.security),
              title: Text(l10n.shizukuPermission),
              subtitle: Text(
                capabilities.when(
                  data: (value) => value['shizukuPermission'] == true
                      ? l10n.permissionGranted
                      : value['shizukuAvailable'] == true
                      ? l10n.permissionRequired
                      : l10n.shizukuUnavailable,
                  loading: () => l10n.checkingPermission,
                  error: (error, stack) => '$error',
                ),
              ),
              trailing: IconButton(
                tooltip: l10n.requestPermission,
                onPressed: () async {
                  try {
                    final granted = await gateway.requestShizukuPermission();
                    ref.invalidate(executionCapabilitiesProvider(checkRoot));
                    if (!granted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.shizukuPermissionNotGranted),
                        ),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$error')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
              ),
            ),
          if (settings.shellTransport == Transport.root)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(l10n.rootPermission),
              subtitle: Text(
                capabilities.when(
                  data: (value) => value['rootAvailable'] == true
                      ? l10n.permissionGranted
                      : l10n.rootUnavailable,
                  loading: () => l10n.checkingPermission,
                  error: (error, stack) => '$error',
                ),
              ),
            ),
          const Divider(height: 1),
          _sectionTitle(context, l10n.terminal),
          SwitchListTile(
            secondary: const Icon(Icons.warning_amber_outlined),
            title: Text(l10n.dangerousActions),
            subtitle: Text(l10n.dangerousActionsDescription),
            value: settings.confirmDangerousActions,
            onChanged: controller.setDangerousConfirmation,
          ),
          const Divider(height: 1),
          _sectionTitle(context, l10n.platformTools),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(l10n.platformTools),
            subtitle: Text(
              settings.platformToolsPath.isEmpty
                  ? l10n.defaultTools
                  : settings.platformToolsPath,
            ),
            trailing: IconButton(
              tooltip: l10n.editPath,
              onPressed: () => _editPlatformToolsPath(
                context,
                ref,
                settings.platformToolsPath,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          const Divider(height: 1),
          _sectionTitle(context, l10n.about),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(l10n.demoNotice),
          ),
        ],
      ),
    );
  }

  String _executionStatus(Transport transport, AppLocalizations l10n) {
    if (transport == Transport.local) return l10n.localShellDescription;
    return switch (transport) {
      Transport.shizuku => l10n.shizukuPermission,
      Transport.root => l10n.rootPermission,
      _ => l10n.localShellDescription,
    };
  }

  String _themeLabel(AppTheme theme, AppLocalizations l10n) => switch (theme) {
    AppTheme.system => l10n.themeSystem,
    AppTheme.light => l10n.themeLight,
    AppTheme.dark => l10n.themeDark,
    AppTheme.amoled => l10n.themeAmoled,
  };

  Future<void> _selectTheme(
    BuildContext context,
    AppTheme selectedTheme,
    AppSettingsController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final theme = await showDialog<AppTheme>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          for (final option in AppTheme.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option),
              child: Row(
                children: [
                  Expanded(child: Text(_themeLabel(option, l10n))),
                  if (option == selectedTheme)
                    const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (theme != null) await controller.setTheme(theme);
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Future<void> _editPlatformToolsPath(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
  ) async {
    final l10n = AppLocalizations.of(context);
    final pathController = TextEditingController(text: currentPath);
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.platformTools),
        content: TextField(
          controller: pathController,
          decoration: InputDecoration(labelText: l10n.path),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, pathController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    pathController.dispose();
    if (path != null) {
      await ref.read(appSettingsProvider.notifier).setPlatformToolsPath(path);
    }
  }
}

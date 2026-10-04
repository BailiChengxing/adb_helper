import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({required this.device, super.key});

  final DeviceRef device;

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  final _searchController = TextEditingController();
  late Future<List<InstalledApp>> _applications;
  bool _showSystemApps = false;
  bool _busy = false;

  SessionSpec get _spec => SessionSpec(
    transport: widget.device.transport,
    serial: widget.device.id,
  );

  @override
  void initState() {
    super.initState();
    _applications = _loadApplications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<InstalledApp>> _loadApplications() =>
      ref.read(deviceGatewayProvider).listApplications(_spec);

  void _refresh() {
    setState(() => _applications = _loadApplications());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.applications),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.device.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !_busy,
                  onSelected: (source) {
                    switch (source) {
                      case 'apk':
                        _installDocument(apkOnly: true);
                        break;
                      case 'aab':
                        _installDocument(aabOnly: true);
                        break;
                      case 'host':
                        _installHostApplication();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'apk',
                      child: Text(l10n.installApk),
                    ),
                    PopupMenuItem(
                      value: 'aab',
                      child: Text(l10n.installAab),
                    ),
                    PopupMenuItem(
                      value: 'host',
                      child: Text(l10n.installFromThisDevice),
                    ),
                  ],
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.installApk),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchApplications,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.showSystemApps),
            value: _showSystemApps,
            onChanged: (value) => setState(() => _showSystemApps = value),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<InstalledApp>>(
              future: _applications,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _FailureView(
                    message: '${snapshot.error}',
                    retry: _refresh,
                    retryLabel: l10n.retry,
                  );
                }
                final query = _searchController.text.trim().toLowerCase();
                final apps = (snapshot.data ?? const <InstalledApp>[])
                    .where((app) => _showSystemApps || !app.systemApp)
                    .where((app) => app.packageName.toLowerCase().contains(query))
                    .toList(growable: false);
                if (apps.isEmpty) {
                  return Center(child: Text(l10n.noApplications));
                }
                return ListView.separated(
                  itemCount: apps.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          app.systemApp
                              ? Icons.android
                              : Icons.apps_outlined,
                        ),
                      ),
                      title: Text(app.packageName),
                      subtitle: Text(
                        [
                          if (app.systemApp) l10n.systemApp,
                          if (app.versionName != null) app.versionName!,
                          if (app.versionCode != null)
                            'v${app.versionCode}',
                        ].join(' · '),
                      ),
                      onTap: _busy
                          ? null
                          : () {
                              _launch(app);
                            },
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (action) => _operate(action, app),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'launch',
                            child: Text(l10n.launchApplication),
                          ),
                          PopupMenuItem(
                            value: 'forceStop',
                            child: Text(l10n.forceStopApplication),
                          ),
                          PopupMenuItem(
                            value: 'clearData',
                            child: Text(l10n.clearApplicationData),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              app.enabled
                                  ? l10n.disableApplication
                                  : l10n.enableApplication,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Text(l10n.applicationSettings),
                          ),
                          PopupMenuItem(
                            value: 'uninstall',
                            child: Text(l10n.uninstallApplication),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _installDocument({
    bool apkOnly = false,
    bool aabOnly = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    await _runOperation(() async {
      final gateway = ref.read(deviceGatewayProvider);
      final uri = await gateway.pickDocument(
        apkOnly: apkOnly,
        aabOnly: aabOnly,
      );
      if (uri == null) return;
      await gateway.installApplication(_spec, uri);
      _refresh();
      _notify(l10n.installSuccess);
    });
  }

  Future<void> _installHostApplication() async {
    final l10n = AppLocalizations.of(context);
    await _runOperation(() async {
      final gateway = ref.read(deviceGatewayProvider);
      final applications = await gateway.listHostApplications();
      if (!mounted) return;
      if (applications.isEmpty) {
        _notify(l10n.noHostApplications);
        return;
      }
      final selectedPackage = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.installFromThisDevice),
          content: SizedBox(
            width: 480,
            height: 420,
            child: ListView.builder(
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return ListTile(
                  leading: Icon(
                    app.systemApp ? Icons.android : Icons.apps_outlined,
                  ),
                  title: Text(app.label ?? app.packageName),
                  subtitle: Text(app.packageName),
                  onTap: () => Navigator.pop(context, app.packageName),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
      if (selectedPackage == null) return;
      await gateway.installHostApplication(_spec, selectedPackage);
      _refresh();
      _notify(l10n.installSuccess);
    });
  }

  Future<bool> _launch(InstalledApp app) {
    final successMessage = AppLocalizations.of(context).launchSuccess;
    return _runOperation(() async {
      await ref.read(deviceGatewayProvider).launchApplication(
        _spec,
        app.packageName,
      );
      _notify(successMessage);
    });
  }

  Future<void> _operate(String action, InstalledApp app) async {
    final gateway = ref.read(deviceGatewayProvider);
    final l10n = AppLocalizations.of(context);
    try {
      switch (action) {
        case 'launch':
          await _launch(app);
          return;
        case 'forceStop':
          if (!await _runOperation(() => gateway.forceStopApplication(
            _spec,
            app.packageName,
          ))) {
            return;
          }
          break;
        case 'clearData':
          if (!await _confirm(
            l10n.clearApplicationData,
            l10n.confirmClearAppData(app.packageName),
          )) {
            return;
          }
          if (!await _runOperation(() => gateway.clearApplicationData(
            _spec,
            app.packageName,
          ))) {
            return;
          }
          break;
        case 'toggle':
          if (!await _runOperation(() => gateway.setApplicationEnabled(
            _spec,
            app.packageName,
            !app.enabled,
          ))) {
            return;
          }
          _refresh();
          break;
        case 'settings':
          await _runOperation(() => gateway.openApplicationSettings(
            _spec,
            app.packageName,
          ));
          return;
        case 'uninstall':
          if (!await _confirm(
            l10n.uninstallApplication,
            l10n.confirmUninstallApp(app.packageName),
          )) {
            return;
          }
          if (!await _runOperation(() => gateway.uninstallApplication(
            _spec,
            app.packageName,
          ))) {
            return;
          }
          _refresh();
          break;
      }
    } catch (error) {
      _notify('$error');
      return;
    }
    if (mounted) {
      _notify(action == 'clearData' ? l10n.clearAppDataSuccess : l10n.operationSuccess);
    }
  }

  Future<bool> _runOperation(Future<void> Function() operation) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await operation();
      return true;
    } catch (error) {
      if (mounted) _notify('$error');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.message,
    required this.retry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback retry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 8),
          SelectableText(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

import 'dart:io';

import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/core/gateway/fake_device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen>
    with WidgetsBindingObserver {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  GoRouter? _router;
  String? _lastLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _lastLocation = router.state.uri.path;
    router.routerDelegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final location = _router!.state.uri.path;
    if (location == '/devices' && _lastLocation != '/devices') {
      ref.invalidate(availableDevicesProvider);
    }
    _lastLocation = location;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(availableDevicesProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devicesAsync = ref.watch(availableDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.devices),
        actions: [
          IconButton(
            tooltip: l10n.scanLocalNetwork,
            onPressed: () => ref.invalidate(availableDevicesProvider),
            icon: const Icon(Icons.wifi_find),
          ),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(availableDevicesProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.pairWireless,
            onPressed: () => _showPairDialog(context, ref),
            icon: const Icon(Icons.add_link),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _hostController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: l10n.ipAddress,
                        prefixIcon: const Icon(Icons.wifi),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.adbPort,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _connectDirect,
                        icon: const Icon(Icons.link),
                        label: Text(l10n.connectByIp),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.directConnectHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: devicesAsync.when(
              data: (devices) => _DeviceWorkbench(devices: devices),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _LoadFailure(
                message: '$error',
                retry: () => ref.invalidate(availableDevicesProvider),
                retryLabel: l10n.retry,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectDirect() async {
    final l10n = AppLocalizations.of(context);
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (InternetAddress.tryParse(host) == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidIpAddress)));
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidAdbPort)));
      return;
    }
    try {
      final device = await ref
          .read(deviceGatewayProvider)
          .connectWireless(host, port);
      ref.invalidate(availableDevicesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deviceConnected(device.label))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showPairDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final hostController = TextEditingController();
    final portController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final pairingResult = await showDialog<PairingResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.pairTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: hostController,
                decoration: InputDecoration(
                  labelText: l10n.host,
                  helperText: l10n.pairInstructions,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.invalidPairing
                    : null,
              ),
              TextFormField(
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.pairingPort),
                validator: (value) {
                  final port = int.tryParse(value ?? '');
                  return port == null || port < 1 || port > 65535
                      ? l10n.invalidPairing
                      : null;
                },
              ),
              TextFormField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(labelText: l10n.pairingCode),
                validator: (value) => !RegExp(r'^\d{6}$').hasMatch(value ?? '')
                    ? l10n.invalidPairing
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final result = await ref
                  .read(deviceGatewayProvider)
                  .pair(
                    PairSpec(
                      host: hostController.text.trim(),
                      port: int.parse(portController.text),
                      code: codeController.text.trim(),
                    ),
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext, result);
            },
            child: Text(l10n.pair),
          ),
        ],
      ),
    );
    hostController.dispose();
    portController.dispose();
    codeController.dispose();
    if (!context.mounted || pairingResult == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pairingResult.ok
              ? pairingResult.serial == null
                    ? l10n.pairPendingDiscovery
                    : l10n.pairSuccess
              : pairingResult.message ?? l10n.pairFailed,
        ),
      ),
    );
    if (pairingResult.ok) ref.invalidate(availableDevicesProvider);
  }
}

class _DeviceWorkbench extends ConsumerWidget {
  const _DeviceWorkbench({required this.devices});

  final List<DeviceRef> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fakeMode = ref.watch(deviceGatewayProvider) is FakeDeviceGateway;
    return CustomScrollView(
      slivers: [
        if (fakeMode)
          SliverToBoxAdapter(
            child: MaterialBanner(
              content: Text(l10n.demoMode),
              leading: const Icon(Icons.info_outline),
              actions: const [SizedBox.shrink()],
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.deviceWorkbench,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.deviceCount(devices.length)),
                    ],
                  ),
                ),
                Icon(
                  Icons.devices,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (devices.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.noDevices),
                    const SizedBox(height: 8),
                    Text(l10n.deviceConnectHelp, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 960
                    ? 3
                    : width >= 620
                    ? 2
                    : 1;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _DeviceCard(device: devices[index]),
                    childCount: devices.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.device});

  final DeviceRef device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(_transportIcon(device.transport)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.label,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _transportName(device.transport, l10n),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.deviceActions,
                  onSelected: (action) => _selectAction(context, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'terminal',
                      child: _menuEntry(Icons.terminal, l10n.terminal),
                    ),
                    PopupMenuItem(
                      value: 'files',
                      child: _menuEntry(Icons.folder_outlined, l10n.files),
                    ),
                    PopupMenuItem(
                      value: 'apps',
                      child: _menuEntry(Icons.apps_outlined, l10n.applications),
                    ),
                    PopupMenuItem(
                      value: 'info',
                      child: _menuEntry(
                        Icons.info_outline,
                        l10n.deviceInformation,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mirror',
                      child: _menuEntry(Icons.cast, l10n.mirror),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              device.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _selectAction(context, 'terminal'),
                icon: const Icon(Icons.terminal),
                label: Text(l10n.connect),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAction(BuildContext context, String action) {
    if (action == 'mirror') {
      _showMirrorNotice(context);
      return;
    }
    final uri = Uri(
      path: '/devices/$action',
      queryParameters: {
        'transport': device.transport.name,
        'serial': device.id,
        'label': device.label,
      },
    );
    context.push(uri.toString(), extra: device);
  }

  Widget _menuEntry(IconData icon, String label) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: 12),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  );

  Future<void> _showMirrorNotice(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cast),
        title: Text(l10n.mirror),
        content: Text(l10n.mirrorNotAvailable),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  IconData _transportIcon(Transport transport) => switch (transport) {
    Transport.local => Icons.phone_android,
    Transport.shizuku => Icons.security,
    Transport.root => Icons.admin_panel_settings,
    Transport.wireless => Icons.wifi,
    Transport.otg => Icons.usb,
    Transport.usb => Icons.usb,
  };

  String _transportName(Transport transport, AppLocalizations l10n) =>
      switch (transport) {
        Transport.local => l10n.transportLocal,
        Transport.shizuku => l10n.transportShizuku,
        Transport.root => l10n.transportRoot,
        Transport.wireless => l10n.transportWireless,
        Transport.otg => l10n.transportOtg,
        Transport.usb => l10n.transportUsb,
      };
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({
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
          SelectableText(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

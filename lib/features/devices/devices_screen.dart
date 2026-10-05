import 'dart:io';

import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/core/gateway/fake_device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Outcome of the explicit connect step for one device.
///
/// Discovery only proves a port is open, so remote devices start out unverified and their feature
/// menus stay closed until a real ADB handshake has succeeded.
enum _ConnectionPhase { idle, checking, connected, failed }

class _DeviceConnection {
  const _DeviceConnection({
    this.phase = _ConnectionPhase.idle,
    this.message,
    this.diagnostic,
  });

  final _ConnectionPhase phase;
  final String? message;
  final String? diagnostic;
}

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
  bool _scanning = false;
  bool _hasScannedNetwork = false;
  List<DeviceRef> _scannedDevices = const [];
  final Map<String, _DeviceConnection> _connections = {};

  Future<void> _verifyConnection(DeviceRef device) async {
    setState(() {
      _connections[device.id] = const _DeviceConnection(
        phase: _ConnectionPhase.checking,
      );
    });
    try {
      final result = await ref
          .read(deviceGatewayProvider)
          .verifyConnection(
            SessionSpec(transport: device.transport, serial: device.id),
          );
      if (!mounted) return;
      setState(() {
        _connections[device.id] = _DeviceConnection(
          phase: result.ok
              ? _ConnectionPhase.connected
              : _ConnectionPhase.failed,
          message: result.message,
          diagnostic: result.diagnostic,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connections[device.id] = _DeviceConnection(
          phase: _ConnectionPhase.failed,
          message: '$error',
        );
      });
    }
  }

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
            tooltip: l10n.fastbootSideload,
            onPressed: () => context.push('/devices/fastboot'),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: l10n.scanLocalNetwork,
            onPressed: _scanning ? null : _scanLocalNetwork,
            icon: _scanning
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
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
              data: (devices) => _DeviceWorkbench(
                devices: _mergeDevices(devices, _scannedDevices),
                connections: _connections,
                onConnect: _verifyConnection,
              ),
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

  Future<void> _scanLocalNetwork() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _scanning = true);
    try {
      final results = await ref.read(deviceGatewayProvider).scanLocalNetwork();
      if (!mounted) return;
      setState(() {
        _scannedDevices = results;
        _hasScannedNetwork = true;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              results.isEmpty
                  ? l10n.noWirelessDevicesFound
                  : l10n.wirelessScanResult(results.length),
            ),
          ),
        );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<DeviceRef> _mergeDevices(
    List<DeviceRef> discovered,
    List<DeviceRef> scanned,
  ) {
    final devices = <String, DeviceRef>{};
    final currentDevices = _hasScannedNetwork
        ? discovered.where((device) => device.transport != Transport.wireless)
        : discovered;
    for (final device in [...currentDevices, ...scanned]) {
      devices[device.id] = device;
    }
    return devices.values.toList(growable: false);
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
  const _DeviceWorkbench({
    required this.devices,
    required this.connections,
    required this.onConnect,
  });

  final List<DeviceRef> devices;
  final Map<String, _DeviceConnection> connections;
  final Future<void> Function(DeviceRef device) onConnect;

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
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DeviceCard(
                    device: devices[index],
                    connection:
                        connections[devices[index].id] ?? const _DeviceConnection(),
                    onConnect: onConnect,
                  ),
                ),
                childCount: devices.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({
    required this.device,
    required this.connection,
    required this.onConnect,
  });

  final DeviceRef device;
  final _DeviceConnection connection;
  final Future<void> Function(DeviceRef device) onConnect;

  /// Only network and USB transports need an explicit handshake; local transports do not.
  bool get _requiresConnection => switch (device.transport) {
    Transport.wireless || Transport.otg || Transport.usb => true,
    Transport.local || Transport.shizuku || Transport.root => false,
  };

  bool get _isReachable =>
      !_requiresConnection || connection.phase == _ConnectionPhase.connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _isReachable
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          child: Icon(_transportIcon(device.transport)),
        ),
        title: Text(
          device.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_transportName(device.transport, l10n)),
            Text(
              device.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_requiresConnection) _statusLine(context, l10n),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_requiresConnection) _connectControl(context, l10n),
            PopupMenuButton<String>(
              tooltip: l10n.deviceActions,
              onSelected: (action) => _selectAction(context, action, l10n),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'info',
                  child: _menuEntry(
                    Icons.info_outline,
                    l10n.deviceInformation,
                  ),
                ),
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
                  value: 'tools',
                  child: _menuEntry(Icons.build_outlined, l10n.tools),
                ),
                PopupMenuItem(
                  value: 'mirror',
                  child: _menuEntry(Icons.cast, l10n.mirror),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusLine(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return switch (connection.phase) {
      _ConnectionPhase.idle => const SizedBox.shrink(),
      _ConnectionPhase.checking => Text(l10n.checkingConnection),
      _ConnectionPhase.connected => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(l10n.connectionEstablished),
        ],
      ),
      _ConnectionPhase.failed => InkWell(
        onTap: () => _showFailure(context, l10n),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: scheme.error),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.connectionFailed,
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    };
  }

  Widget _connectControl(BuildContext context, AppLocalizations l10n) =>
      switch (connection.phase) {
        _ConnectionPhase.checking => const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        _ConnectionPhase.connected => IconButton(
          tooltip: l10n.connect,
          onPressed: () => onConnect(device),
          icon: Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        _ConnectionPhase.idle || _ConnectionPhase.failed => TextButton.icon(
          onPressed: () => onConnect(device),
          icon: const Icon(Icons.link),
          label: Text(l10n.connect),
        ),
      };

  void _showFailure(BuildContext context, AppLocalizations l10n) {
    final details = [
      if (connection.message?.isNotEmpty ?? false) connection.message!,
      if (connection.diagnostic?.isNotEmpty ?? false) connection.diagnostic!,
    ].join('\n\n');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.connectionFailed),
        content: SelectableText(
          details.isEmpty ? l10n.connectionFailed : details,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _selectAction(
    BuildContext context,
    String action,
    AppLocalizations l10n,
  ) {
    if (!_isReachable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.connectFirst)));
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

import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/features/terminal/terminal_controller.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final devicesProvider = FutureProvider<List<DeviceRef>>((ref) {
  return ref.watch(deviceGatewayProvider).discover();
});

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.devices),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(devicesProvider),
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
          MaterialBanner(
            content: Text(l10n.demoMode),
            leading: const Icon(Icons.info_outline),
            actions: const [SizedBox.shrink()],
          ),
          Expanded(
            child: devicesAsync.when(
              data: (devices) {
                if (devices.isEmpty) return Center(child: Text(l10n.noDevices));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(_transportIcon(device.transport))),
                        title: Text(device.label),
                        subtitle: Text('${device.id} · ${_transportName(device.transport, l10n)}'),
                        trailing: FilledButton.tonal(
                          onPressed: () => _connect(context, ref, device),
                          child: Text(l10n.connect),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('$error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref, DeviceRef device) async {
    try {
      await ref.read(terminalSessionsProvider.notifier).openSession(
        SessionSpec(
          transport: device.transport,
          serial: device.transport == Transport.wireless || device.transport == Transport.otg
              ? device.id
              : null,
        ),
      );
      if (context.mounted) context.go('/terminal');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showPairDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final hostController = TextEditingController(text: '127.0.0.1');
    final portController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final pairingResult = await showDialog<PairingResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pairTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: hostController,
                decoration: InputDecoration(labelText: l10n.host),
                validator: (value) => value == null || value.trim().isEmpty ? l10n.invalidPairing : null,
              ),
              TextFormField(
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.pairingPort),
                validator: (value) => int.tryParse(value ?? '') == null ? l10n.invalidPairing : null,
              ),
              TextFormField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(labelText: l10n.pairingCode),
                validator: (value) => (value?.length ?? 0) != 6 ? l10n.invalidPairing : null,
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
              final result = await ref.read(deviceGatewayProvider).pair(
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
      SnackBar(content: Text(pairingResult.ok ? l10n.pairSuccess : l10n.pairFailed)),
    );
    if (pairingResult.ok) ref.invalidate(devicesProvider);
  }

  IconData _transportIcon(Transport transport) => switch (transport) {
    Transport.local => Icons.phone_android,
    Transport.shizuku => Icons.security,
    Transport.root => Icons.admin_panel_settings,
    Transport.wireless => Icons.wifi,
    Transport.otg => Icons.usb,
  };

  String _transportName(Transport transport, AppLocalizations l10n) => switch (transport) {
    Transport.local => l10n.transportLocal,
    Transport.shizuku => l10n.transportShizuku,
    Transport.root => l10n.transportRoot,
    Transport.wireless => l10n.transportWireless,
    Transport.otg => l10n.transportOtg,
  };
}

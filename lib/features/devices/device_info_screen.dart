import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceInfoScreen extends ConsumerStatefulWidget {
  const DeviceInfoScreen({required this.device, super.key});

  final DeviceRef device;

  @override
  ConsumerState<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends ConsumerState<DeviceInfoScreen> {
  late Future<Map<String, String>> _information;

  @override
  void initState() {
    super.initState();
    _information = _load();
  }

  Future<Map<String, String>> _load() {
    return ref.read(deviceGatewayProvider).deviceInformation(
      SessionSpec(
        transport: widget.device.transport,
        serial: widget.device.id,
      ),
    );
  }

  void _refresh() => setState(() => _information = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceInformation),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _information,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }
          final information = snapshot.data ?? const <String, String>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.devices)),
                title: Text(widget.device.label),
                subtitle: Text(widget.device.id),
              ),
              const SizedBox(height: 8),
              ...information.entries.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(entry.key),
                    subtitle: SelectableText(entry.value),
                  ),
                ),
              ),
              if (information.isEmpty)
                Center(child: Text(l10n.noDeviceInformation)),
            ],
          );
        },
      ),
    );
  }
}

import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/core/gateway/fake_device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({this.device, super.key});

  final DeviceRef? device;

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  String _path = '/';
  String? _loadedKey;
  Future<List<FileEntry>>? _entries;
  bool _busy = false;
  DeviceRef? _activeDevice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devicesAsync = ref.watch(availableDevicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.files),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.newFolder,
            onPressed: _busy ? null : _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _FileError(
          message: '$error',
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(availableDevicesProvider),
        ),
        data: (devices) => _buildFileBrowser(context, ref, devices),
      ),
    );
  }

  Widget _buildFileBrowser(
    BuildContext context,
    WidgetRef ref,
    List<DeviceRef> allDevices,
  ) {
    final l10n = AppLocalizations.of(context);
    final isFake = ref.watch(deviceGatewayProvider) is FakeDeviceGateway;
    final devices = isFake
        ? allDevices
        : allDevices
              .where(
                (device) =>
                    device.transport == Transport.wireless ||
                    device.transport == Transport.otg,
              )
              .toList(growable: false);
    final current = widget.device ?? ref.watch(selectedFileDeviceProvider);
    final selected =
        devices.where((device) => device.id == current?.id).firstOrNull ??
        devices.firstOrNull;
    _activeDevice = selected;

    if (selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 52),
              const SizedBox(height: 12),
              Text(l10n.noFileDevice, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                l10n.fileDeviceHelp,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final spec = SessionSpec(
      transport: selected.transport,
      serial:
          selected.transport == Transport.wireless ||
              selected.transport == Transport.otg
          ? selected.id
          : null,
    );
    final sync = ref.watch(fileSyncProvider(spec));
    final key = '${selected.transport.name}:${selected.id}:$_path';
    if (_loadedKey != key) {
      _loadedKey = key;
      _entries = sync.list(_path);
    }
    return Column(
      children: [
        if (widget.device == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DropdownButtonFormField<DeviceRef>(
              initialValue: selected,
              decoration: InputDecoration(
                labelText: l10n.targetDevice,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.devices_outlined),
              ),
              items: devices
                  .map(
                    (device) => DropdownMenuItem(
                      value: device,
                      child: Text(
                        '${device.label} · ${_transportName(device.transport, l10n)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _busy
                  ? null
                  : (device) {
                      if (device == null) return;
                      ref.read(selectedFileDeviceProvider.notifier).state =
                          device;
                      setState(() {
                        _path = '/';
                        _loadedKey = null;
                      });
                    },
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: Text(selected.label),
            subtitle: Text(_transportName(selected.transport, l10n)),
            dense: true,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            initialValue:
                _path == '/storage/emulated/0' ||
                    _path.startsWith('/storage/emulated/0/')
                ? '/storage/emulated/0'
                : '/',
            decoration: InputDecoration(
              labelText: l10n.storageLocation,
              prefixIcon: const Icon(Icons.storage_outlined),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: '/', child: Text(l10n.systemRoot)),
              DropdownMenuItem(
                value: '/storage/emulated/0',
                child: Text(l10n.internalStorage),
              ),
            ],
            onChanged: _busy
                ? null
                : (path) {
                    if (path == null) return;
                    setState(() {
                      _path = path;
                      _loadedKey = null;
                    });
                  },
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              if (_path != '/')
                IconButton(
                  tooltip: l10n.parentFolder,
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _path = _parent(_path);
                          _loadedKey = null;
                        }),
                  icon: const Icon(Icons.arrow_upward),
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _path == '/' ? l10n.filesRoot : _path,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (action) => _transfer(action, sync),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'upload', child: Text(l10n.uploadFile)),
                ],
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<List<FileEntry>>(
            future: _entries,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _FileError(
                  message: '${snapshot.error}',
                  retryLabel: l10n.retry,
                  onRetry: _refresh,
                );
              }
              final entries = snapshot.data ?? const <FileEntry>[];
              if (entries.isEmpty) {
                return Center(child: Text(l10n.emptyFolder));
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: Icon(
                      entry.isDirectory
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                    ),
                    title: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      entry.isDirectory
                          ? '${entry.mode} · ${entry.mtime}'
                          : '${_formatSize(entry.size)} · ${entry.mode} · ${entry.mtime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !_busy,
                      onSelected: (action) => _operate(action, entry, sync),
                      itemBuilder: (context) => [
                        if (!entry.isDirectory)
                          PopupMenuItem(
                            value: 'download',
                            child: Text(l10n.downloadFile),
                          ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l10n.rename),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                    onTap: entry.isDirectory
                        ? () => setState(() {
                            _path = entry.path;
                            _loadedKey = null;
                          })
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(l10n.newFolder, l10n.folderName);
    if (name == null) return;
    if (!_validName(name)) {
      _notify(l10n.invalidFileName);
      return;
    }
    await _runFileOperation((sync) => sync.mkdir(_join(_path, name)));
  }

  Future<void> _operate(String action, FileEntry entry, FileSync sync) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'download':
        await _download(entry, sync);
        return;
      case 'delete':
        final confirmed = await _confirm(
          l10n.delete,
          l10n.confirmDelete(entry.name),
        );
        if (!confirmed) return;
        await _runFileOperation((_) => sync.delete(entry.path));
        break;
      case 'rename':
        final name = await _askName(
          l10n.rename,
          l10n.renameTo,
          initialValue: entry.name,
        );
        if (name == null || name == entry.name) return;
        if (!_validName(name)) {
          _notify(l10n.invalidFileName);
          return;
        }
        await _runFileOperation(
          (_) => sync.rename(entry.path, _join(_path, name)),
        );
    }
  }

  Future<void> _transfer(String action, FileSync sync) async {
    if (action != 'upload') return;
    try {
      final l10n = AppLocalizations.of(context);
      final uri = await ref.read(deviceGatewayProvider).pickDocument();
      if (uri == null) return;
      final name = await _askName(l10n.remoteFileName, l10n.fileName);
      if (name == null) return;
      if (!_validName(name)) {
        _notify(l10n.invalidFileName);
        return;
      }
      await _runFileOperation(
        (gateway) =>
            gateway.push(uri, _join(_path, name), (progress, message) {}),
        sync: sync,
        successMessage: l10n.uploadComplete,
      );
    } catch (error) {
      _notify('$error');
    }
  }

  Future<void> _download(FileEntry entry, FileSync sync) async {
    try {
      final l10n = AppLocalizations.of(context);
      final uri = await ref
          .read(deviceGatewayProvider)
          .pickDocument(saveAs: entry.name);
      if (uri == null) return;
      await _runFileOperation(
        (gateway) => gateway.pull(entry.path, uri, (progress, message) {}),
        sync: sync,
        successMessage: l10n.downloadComplete,
        refresh: false,
      );
    } catch (error) {
      _notify('$error');
    }
  }

  Future<void> _runFileOperation(
    Future<void> Function(FileSync gateway) operation, {
    FileSync? sync,
    String? successMessage,
    bool refresh = true,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final gateway = sync ?? _currentSync();
      await operation(gateway);
      if (refresh) _refresh();
      if (successMessage != null) _notify(successMessage);
    } catch (error) {
      if (mounted) _notify('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  FileSync _currentSync() {
    final selected = _activeDevice;
    if (selected == null) {
      throw StateError('Select an ADB device before using file operations.');
    }
    return ref.read(
      fileSyncProvider(
        SessionSpec(
          transport: selected.transport,
          serial:
              selected.transport == Transport.wireless ||
                  selected.transport == Transport.otg
              ? selected.id
              : null,
        ),
      ),
    );
  }

  void _refresh() {
    _loadedKey = null;
    setState(() {});
  }

  Future<String?> _askName(
    String title,
    String label, {
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim();
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).confirm),
            ),
          ],
        ),
      ) ??
      false;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !name.contains('\u0000') &&
      !name.contains('\n');

  static String _join(String parent, String name) =>
      parent == '/' ? '/$name' : '$parent/$name';

  static String _parent(String path) {
    final index = path.lastIndexOf('/');
    return index <= 0 ? '/' : path.substring(0, index);
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

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

class _FileError extends StatelessWidget {
  const _FileError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

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
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

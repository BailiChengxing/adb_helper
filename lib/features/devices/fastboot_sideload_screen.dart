import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastbootSideloadScreen extends ConsumerStatefulWidget {
  const FastbootSideloadScreen({super.key});

  @override
  ConsumerState<FastbootSideloadScreen> createState() =>
      _FastbootSideloadScreenState();
}

class _FastbootSideloadScreenState
    extends ConsumerState<FastbootSideloadScreen> {
  int _section = 0;
  List<String> _fastbootDevices = const [];
  String? _selectedFastboot;
  String? _flashImage;
  String? _sideloadPackage;
  String _partition = 'boot';
  final _partitionController = TextEditingController(text: 'boot');
  String _rebootMode = 'system';
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _refreshFastboot();
  }

  @override
  void dispose() {
    _partitionController.dispose();
    super.dispose();
  }

  Future<void> _refreshFastboot() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final devices = await ref.read(fastbootGatewayProvider).devices();
      if (!mounted) return;
      setState(() {
        _fastbootDevices = devices;
        if (!_fastbootDevices.contains(_selectedFastboot)) {
          _selectedFastboot = _fastbootDevices.firstOrNull;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFlashImage() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file != null && mounted) {
      setState(() {
        _flashImage = file.path;
        _status = null;
      });
    }
  }

  Future<void> _pickSideloadPackage() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result != null && mounted) {
      setState(() {
        _sideloadPackage = result.path;
        _status = null;
      });
    }
  }

  Future<void> _flash() async {
    final image = _flashImage;
    final serial = _selectedFastboot;
    if (image == null || serial == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.flashImage,
      '$_partition\n$image',
    );
    if (!confirmed || !mounted) return;

    await _runOperation(
      () => ref
          .read(fastbootGatewayProvider)
          .flash(
            _partition,
            image,
            (progress, message) {
              if (mounted) setState(() => _status = message);
            },
            serial: serial,
          ),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _rebootFastboot() async {
    final serial = _selectedFastboot;
    if (serial == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.rebootMode,
      _rebootModeLabel(_rebootMode, l10n),
    );
    if (!confirmed || !mounted) return;

    await _runOperation(
      () => ref
          .read(fastbootGatewayProvider)
          .reboot(_rebootMode, serial: serial),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _sideload() async {
    final package = _sideloadPackage;
    if (package == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(l10n.sideload, package);
    if (!confirmed || !mounted) return;

    await _runOperation(
      () => ref
          .read(sideloadGatewayProvider)
          .sideload(
            package,
            (progress, message) {
              if (mounted) setState(() => _status = message);
            },
          ),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _runOperation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await operation();
      if (mounted) setState(() => _status = successMessage);
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppLocalizations.of(context).confirm),
            ),
          ],
        ),
      ) ??
      false;

  String _rebootModeLabel(String mode, AppLocalizations l10n) =>
      switch (mode) {
        'bootloader' => l10n.rebootBootloader,
        'recovery' => l10n.rebootRecovery,
        _ => l10n.rebootSystem,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fastbootSideload),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _busy ? null : _refreshFastboot,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.fastboot)),
                ButtonSegment(value: 1, label: Text(l10n.sideload)),
              ],
              selected: {_section},
              onSelectionChanged: (value) {
                setState(() => _section = value.first);
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: _section == 0
                  ? _buildFastboot(l10n)
                  : _buildSideload(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastboot(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.fastbootDevices,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_fastbootDevices.isEmpty)
          Text(
            l10n.noFastbootDevices,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ..._fastbootDevices.map(
            (serial) => ListTile(
              leading: Icon(
                _selectedFastboot == serial
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(serial),
              onTap: _busy
                  ? null
                  : () => setState(() => _selectedFastboot = serial),
            ),
          ),
        const Divider(height: 32),
        TextField(
          controller: _partitionController,
          decoration: InputDecoration(
            labelText: l10n.partition,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => _partition = value.trim(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickFlashImage,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(_flashImage ?? l10n.selectImage),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ||
                  _selectedFastboot == null ||
                  _flashImage == null
              ? null
              : _flash,
          icon: const Icon(Icons.flash_on),
          label: Text(l10n.flashImage),
        ),
        const Divider(height: 32),
        Text(
          l10n.rebootMode,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in const ['system', 'bootloader', 'recovery'])
              ChoiceChip(
                label: Text(_rebootModeLabel(mode, l10n)),
                selected: _rebootMode == mode,
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _rebootMode = mode),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _busy || _selectedFastboot == null
              ? null
              : _rebootFastboot,
          icon: const Icon(Icons.restart_alt),
          label: Text(l10n.rebootMode),
        ),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!),
        ],
      ],
    );
  }

  Widget _buildSideload(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.sideload,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickSideloadPackage,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(_sideloadPackage ?? l10n.selectZip),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy || _sideloadPackage == null ? null : _sideload,
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.startSideload),
        ),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!),
        ],
      ],
    );
  }
}

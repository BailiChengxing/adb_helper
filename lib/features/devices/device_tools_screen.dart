import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceToolsScreen extends ConsumerStatefulWidget {
  const DeviceToolsScreen({required this.device, super.key});

  final DeviceRef device;

  @override
  ConsumerState<DeviceToolsScreen> createState() => _DeviceToolsScreenState();
}

class _DeviceToolsScreenState extends ConsumerState<DeviceToolsScreen> {
  final _dpiController = TextEditingController(text: '420');
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  String _rebootMode = 'system';
  bool _busy = false;
  String? _status;

  SessionSpec get _spec => SessionSpec(
    transport: widget.device.transport,
    serial: widget.device.id,
  );

  @override
  void dispose() {
    _dpiController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() operation, {
    String? successMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await operation();
      if (mounted) {
        setState(() => _status = successMessage);
      }
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWireless() async {
    final l10n = AppLocalizations.of(context);
    final enable = widget.device.transport != Transport.wireless;
    final confirmed = await _confirm(
      l10n.wirelessDebug,
      enable ? l10n.wirelessEnable : l10n.wirelessDisable,
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => ref
          .read(deviceToolsGatewayProvider)
          .setWirelessDebugging(_spec, enable),
      successMessage: l10n.operationSuccess,
    );
    if (mounted) ref.invalidate(availableDevicesProvider);
  }

  Future<void> _screenshot() async {
    final l10n = AppLocalizations.of(context);
    final destination = await FilePicker.saveFile(
      fileName:
          'screenshot-${DateTime.now().millisecondsSinceEpoch}.png',
      bytes: Uint8List(0),
    );
    if (destination == null || !mounted) return;
    await _run(
      () => ref
          .read(deviceToolsGatewayProvider)
          .screenshot(_spec, destination.toString()),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _reboot() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      l10n.advancedReboot,
      _rebootModeLabel(_rebootMode, l10n),
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => ref
          .read(deviceToolsGatewayProvider)
          .advancedReboot(_spec, _rebootMode),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _setDpi() async {
    final value = int.tryParse(_dpiController.text.trim());
    if (value == null) {
      setState(() => _status = AppLocalizations.of(context).invalidNumber);
      return;
    }
    final l10n = AppLocalizations.of(context);
    await _run(
      () => ref.read(deviceToolsGatewayProvider).setDpi(_spec, value),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _setResolution() async {
    final width = int.tryParse(_widthController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (width == null || height == null) {
      setState(() => _status = AppLocalizations.of(context).invalidNumber);
      return;
    }
    final l10n = AppLocalizations.of(context);
    await _run(
      () => ref
          .read(deviceToolsGatewayProvider)
          .setResolution(_spec, width, height),
      successMessage: l10n.operationSuccess,
    );
  }

  Future<void> _screenOff() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(l10n.screenOff, l10n.screenOffHelp);
    if (!confirmed || !mounted) return;
    await _run(
      () => ref.read(deviceToolsGatewayProvider).screenOff(_spec),
      successMessage: l10n.operationSuccess,
    );
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
      appBar: AppBar(title: Text(l10n.tools)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, l10n.wirelessDebug),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.wirelessDebug),
              subtitle: Text(
                widget.device.transport == Transport.wireless
                    ? l10n.wirelessEnabled
                    : l10n.wirelessDisabled,
              ),
              value: widget.device.transport == Transport.wireless,
              onChanged: _busy ? null : (_) => _toggleWireless(),
            ),
            const Divider(height: 32),
            _sectionTitle(context, l10n.screenTools),
            FilledButton.icon(
              onPressed: _busy ? null : _screenshot,
              icon: const Icon(Icons.screenshot),
              label: Text(l10n.screenshot),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _screenOff,
              icon: const Icon(Icons.visibility_off_outlined),
              label: Text(l10n.screenOff),
            ),
            const Divider(height: 32),
            _sectionTitle(context, l10n.advancedReboot),
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
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _reboot,
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.advancedReboot),
            ),
            const Divider(height: 32),
            _sectionTitle(context, l10n.displayTools),
            TextField(
              controller: _dpiController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.dpi,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _setDpi,
              icon: const Icon(Icons.aspect_ratio),
              label: Text(l10n.setDpi),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.width,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.height,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _setResolution,
              icon: const Icon(Icons.fullscreen),
              label: Text(l10n.setResolution),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}
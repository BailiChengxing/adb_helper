import 'dart:io';

import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/core/settings/app_settings.dart';
import 'package:adb_helper/features/terminal/terminal_controller.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({this.device, super.key});

  final DeviceRef? device;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _commandController = TextEditingController();
  final _outputScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(terminalSessionsProvider).sessions.isEmpty) {
        ref.read(terminalSessionsProvider.notifier).openSession(_sessionSpec());
      } else if (mounted) {
        final terminal = ref.read(terminalSessionsProvider);
        final matching = terminal.sessions.where(
          (session) =>
              session.spec.transport == _sessionSpec().transport &&
              session.spec.serial == _sessionSpec().serial,
        );
        if (matching.isNotEmpty) {
          ref
              .read(terminalSessionsProvider.notifier)
              .selectSession(matching.last.id);
        } else {
          ref
              .read(terminalSessionsProvider.notifier)
              .openSession(_sessionSpec());
        }
      }
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final terminal = ref.watch(terminalSessionsProvider);
    final controller = ref.read(terminalSessionsProvider.notifier);
    final settings = ref.watch(appSettingsProvider);
    final activeSession = terminal.activeSession;

    ref.listen(terminalSessionsProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_outputScrollController.hasClients) {
          _outputScrollController.jumpTo(
            _outputScrollController.position.maxScrollExtent,
          );
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device?.label ?? l10n.terminal),
        actions: [
          IconButton(
            tooltip: l10n.clearOutput,
            onPressed: activeSession == null
                ? null
                : () => controller.clearOutput(activeSession.id),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: l10n.newSession,
            onPressed: () => controller.openSession(_sessionSpec()),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          if (terminal.sessions.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final session in terminal.sessions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: Icon(
                          session.status == 'ready'
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 10,
                        ),
                        label: Text(session.id),
                        selected: terminal.activeSessionId == session.id,
                        onPressed: () => controller.selectSession(session.id),
                        onDeleted: terminal.sessions.length == 1
                            ? null
                            : () => controller.closeSession(session.id),
                        deleteButtonTooltipMessage: l10n.closeSession,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: settings.theme == AppTheme.amoled
                    ? Colors.black
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: activeSession == null || activeSession.output.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        l10n.terminalWelcome,
                        style: TextStyle(
                          fontFamily: Platform.isWindows ? 'Consolas' : 'monospace',
                          fontFamilyFallback: const ['Microsoft YaHei UI', 'SimSun'],
                          fontSize: settings.terminalFontSize,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _outputScrollController,
                      child: SelectableText.rich(
                        TextSpan(
                          children: _outputSpans(activeSession.output, context),
                        ),
                        style: TextStyle(
                          fontFamily: Platform.isWindows ? 'Consolas' : 'monospace',
                          fontFamilyFallback: const ['Microsoft YaHei UI', 'SimSun'],
                          fontSize: settings.terminalFontSize,
                          height: 1.45,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _commandController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _runCommand(),
              decoration: InputDecoration(
                hintText: l10n.commandHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.chevron_right),
                suffixIcon: IconButton(
                  tooltip: l10n.sendCommand,
                  onPressed: _runCommand,
                  icon: const Icon(Icons.send),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SessionSpec _sessionSpec() => SessionSpec(
    transport:
        widget.device?.transport ??
        ref.read(appSettingsProvider).shellTransport,
    serial:
        widget.device?.transport == Transport.wireless ||
            widget.device?.transport == Transport.otg ||
            widget.device?.transport == Transport.usb
        ? widget.device?.id
        : null,
  );

  List<TextSpan> _outputSpans(String output, BuildContext context) {
    final normal = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    return output
        .splitMapJoin(
          RegExp(r'^\$ .*$', multiLine: true),
          onMatch: (match) => '\u0000${match.group(0)}\u0000',
          onNonMatch: (text) => text,
        )
        .split('\u0000')
        .where((text) => text.isNotEmpty)
        .map((text) {
          final isCommand = text.startsWith('\$ ');
          return TextSpan(
            text: text,
            style: TextStyle(color: isCommand ? accent : normal),
          );
        })
        .toList();
  }

  Future<void> _runCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;
    final settings = ref.read(appSettingsProvider);
    final isDangerous = RegExp(r'(^|\s)(rm|reboot|flash)(\s|$)')
        .hasMatch(command);
    if (settings.confirmDangerousActions && isDangerous) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.commandNeedsConfirmation),
          content: Text(command),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.runAnyway),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    _commandController.clear();
    await ref.read(terminalSessionsProvider.notifier).sendCommand(command);
  }
}

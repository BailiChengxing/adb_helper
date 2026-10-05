import 'dart:async';

import 'package:adb_helper/core/gateway/device_providers.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MirrorScreen extends ConsumerStatefulWidget {
  const MirrorScreen({required this.device, super.key});

  final DeviceRef device;

  @override
  ConsumerState<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends ConsumerState<MirrorScreen> {
  MirrorSession? _session;
  bool _starting = false;
  String? _error;

  SessionSpec get _spec => SessionSpec(
    transport: widget.device.transport,
    serial: widget.device.id,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  @override
  void dispose() {
    final session = _session;
    if (session != null) {
      unawaited(
        ref.read(mirrorGatewayProvider).stop(session.sessionId).catchError((
          Object _,
        ) {}),
      );
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _session != null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final session = await ref.read(mirrorGatewayProvider).start(_spec);
      if (!mounted) {
        await ref.read(mirrorGatewayProvider).stop(session.sessionId);
        return;
      }
      setState(() => _session = session);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await ref.read(mirrorGatewayProvider).stop(session.sessionId);
      if (mounted) setState(() => _session = null);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mirror),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _starting ? null : _start,
            icon: const Icon(Icons.refresh),
          ),
          if (session != null)
            IconButton(
              tooltip: l10n.stopMirror,
              onPressed: _starting ? null : _stop,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_starting) const LinearProgressIndicator(),
          Expanded(
            child: session == null
                ? _EmptyMirrorView(
                    starting: _starting,
                    error: _error,
                    onStart: _start,
                  )
                : Center(
                    child: AspectRatio(
                      aspectRatio: session.height > 0
                          ? session.width / session.height
                          : 9 / 16,
                      child: Texture(textureId: session.textureId),
                    ),
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyMirrorView extends StatelessWidget {
  const _EmptyMirrorView({
    required this.starting,
    required this.error,
    required this.onStart,
  });

  final bool starting;
  final String? error;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cast_connected_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              starting
                  ? l10n.mirrorStarting
                  : error == null
                  ? l10n.mirrorReady
                  : l10n.mirrorFailed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!starting && error == null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startMirror),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
import 'dart:async';

import 'package:adb_helper/core/gateway/device_gateway.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/core/settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TerminalState {
  const TerminalState({this.sessions = const [], this.activeSessionId});

  final List<SessionState> sessions;
  final String? activeSessionId;

  SessionState? get activeSession {
    for (final session in sessions) {
      if (session.id == activeSessionId) return session;
    }
    return null;
  }

  TerminalState copyWith({List<SessionState>? sessions, String? activeSessionId}) {
    return TerminalState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }
}

final terminalSessionsProvider = StateNotifierProvider<TerminalController, TerminalState>((ref) {
  return TerminalController(
    ref.watch(deviceGatewayProvider),
    () => ref.read(appSettingsProvider).shellTransport,
  );
});

class TerminalController extends StateNotifier<TerminalState> {
  TerminalController(this._gateway, this._selectedTransport)
    : super(const TerminalState());

  final DeviceGateway _gateway;
  final Transport Function() _selectedTransport;
  final Map<String, ShellSession> _shellSessions = {};
  final Map<String, StreamSubscription<ShellEvent>> _subscriptions = {};
  int _nextSessionNumber = 1;

  Future<String> openSession(SessionSpec spec) async {
    final shell = await _gateway.open(spec);
    final sessionId = 'session-${_nextSessionNumber++}';
    final session = SessionState(
      id: sessionId,
      spec: spec,
      status: 'ready',
      output: '',
    );
    _shellSessions[sessionId] = shell;
    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: sessionId,
    );
    _subscriptions[sessionId] = shell.events.listen(
      (event) => _handleEvent(sessionId, event),
      onError: (Object error) => appendOutput(sessionId, '$error\n'),
    );
    return sessionId;
  }

  void selectSession(String sessionId) {
    if (state.sessions.any((session) => session.id == sessionId)) {
      state = state.copyWith(activeSessionId: sessionId);
    }
  }

  Future<void> sendCommand(String command) async {
    final sessionId = state.activeSessionId;
    final shell = sessionId == null ? null : _shellSessions[sessionId];
    if (shell == null) return;
    await shell.write('$command\n');
  }

  Future<void> closeSession(String sessionId) async {
    await _subscriptions.remove(sessionId)?.cancel();
    await _shellSessions.remove(sessionId)?.close();
    final remaining = state.sessions.where((session) => session.id != sessionId).toList();
    state = TerminalState(
      sessions: remaining,
      activeSessionId: remaining.isEmpty ? null : remaining.last.id,
    );
    if (remaining.isEmpty) {
      unawaited(openSession(SessionSpec(transport: _selectedTransport())));
    }
  }

  void clearOutput(String sessionId) {
    state = state.copyWith(
      sessions: [
        for (final session in state.sessions)
          if (session.id == sessionId) session.copyWith(output: '') else session,
      ],
    );
  }

  void _handleEvent(String sessionId, ShellEvent event) {
    state = state.copyWith(
      sessions: [
        for (final session in state.sessions)
          if (session.id == sessionId)
            session.copyWith(
              output: '${session.output}${event.data}',
              status: event.stream == ShellStream.exit ? 'closed' : session.status,
              exitCode: event.exitCode,
            )
          else
            session,
      ],
    );
  }

  void appendOutput(String sessionId, String text) {
    state = state.copyWith(
      sessions: [
        for (final session in state.sessions)
          if (session.id == sessionId)
            session.copyWith(output: '${session.output}$text')
          else
            session,
      ],
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final shell in _shellSessions.values) {
      unawaited(shell.close());
    }
    super.dispose();
  }
}

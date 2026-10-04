import 'dart:async';

import 'package:adb_helper/core/gateway/android_file_sync.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:flutter/services.dart';

class AndroidDeviceGateway implements DeviceGateway {
  static const MethodChannel _commands = MethodChannel('adb_helper/android');
  static const EventChannel _events = EventChannel('adb_helper/android/events');

  final StreamController<ShellEvent> _eventController =
      StreamController<ShellEvent>.broadcast();
  StreamSubscription<Object?>? _eventSubscription;

  AndroidDeviceGateway() {
    _eventSubscription = _events.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: _eventController.addError,
    );
  }

  @override
  Future<List<DeviceRef>> discover() async {
    final devices = await _commands.invokeListMethod<Object?>('discover') ?? [];
    return devices
        .map((value) {
          final device = Map<Object?, Object?>.from(value! as Map);
          return DeviceRef(
            id: device['id']! as String,
            label: device['label']! as String,
            transport: Transport.values.byName(device['transport']! as String),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Map<String, String>> deviceInformation(SessionSpec spec) async {
    final result = await _commands.invokeMapMethod<String, String>(
      'deviceInformation',
      _sessionArguments(spec),
    );
    if (result == null) {
      throw PlatformException(
        code: 'DEVICE_INFO_FAILED',
        message: 'The Android backend did not return device information.',
      );
    }
    return result;
  }

  @override
  Future<PairingResult> pair(PairSpec spec) async {
    final result = await _commands.invokeMapMethod<Object?, Object?>('pair', {
      'host': spec.host,
      'port': spec.port,
      'code': spec.code,
    });
    return PairingResult(
      ok: result?['ok'] == true,
      message: result?['message'] as String?,
      serial: result?['serial'] as String?,
    );
  }

  @override
  Future<DeviceRef> connectWireless(String host, int port) async {
    final result = await _commands.invokeMapMethod<Object?, Object?>(
      'connectWireless',
      {'host': host, 'port': port},
    );
    if (result == null) {
      throw PlatformException(
        code: 'WIRELESS_CONNECT_FAILED',
        message: 'The Android backend did not return the connected device.',
      );
    }
    return DeviceRef(
      id: result['id']! as String,
      label: result['label']! as String,
      transport: Transport.wireless,
    );
  }

  @override
  Future<ShellSession> open(SessionSpec spec) async {
    final sessionId = await _commands.invokeMethod<String>(
      'openSession',
      _sessionArguments(spec),
    );
    if (sessionId == null) {
      throw PlatformException(
        code: 'INVALID_SESSION',
        message: 'The Android backend did not return a session id.',
      );
    }
    return _AndroidShellSession(sessionId, _commands, _eventController.stream);
  }

  @override
  Future<int> execOnce(SessionSpec spec, String command) async {
    final result = await _commands.invokeMethod<int>('execOnce', {
      ..._sessionArguments(spec),
      'command': command,
    });
    if (result == null) {
      throw PlatformException(
        code: 'INVALID_EXIT_CODE',
        message: 'The Android backend did not return an exit code.',
      );
    }
    return result;
  }

  @override
  Future<List<InstalledApp>> listApplications(SessionSpec spec) async {
    final values = await _commands.invokeListMethod<Object?>(
      'listApplications',
      _sessionArguments(spec),
    );
    return (values ?? const [])
        .map((value) {
          final app = Map<Object?, Object?>.from(value! as Map);
          return InstalledApp(
            packageName: app['packageName']! as String,
            label: app['label'] as String?,
            versionName: app['versionName'] as String?,
            versionCode: app['versionCode'] as int?,
            systemApp: app['systemApp'] as bool? ?? false,
            enabled: app['enabled'] as bool? ?? true,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<InstalledApp>> listHostApplications() async {
    final values = await _commands.invokeListMethod<Object?>(
      'listHostApplications',
    );
    return (values ?? const [])
        .map((value) {
          final app = Map<Object?, Object?>.from(value! as Map);
          return InstalledApp(
            packageName: app['packageName']! as String,
            versionName: app['versionName'] as String?,
            versionCode: app['versionCode'] as int?,
            systemApp: app['systemApp'] as bool? ?? false,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<String?> pickDocument({
    bool apkOnly = false,
    bool aabOnly = false,
    String? saveAs,
  }) =>
      _commands.invokeMethod<String>('pickDocument', {
        'apkOnly': apkOnly,
        'aabOnly': aabOnly,
        'saveAs': saveAs,
      });

  @override
  Future<void> installApplication(SessionSpec spec, String documentUri) =>
      _invokeOperation('installApplication', spec, {'uri': documentUri});

  @override
  Future<void> installHostApplication(
    SessionSpec spec,
    String packageName,
  ) => _invokeOperation(
    'installHostApplication',
    spec,
    {'packageName': packageName},
  );

  @override
  Future<void> uninstallApplication(SessionSpec spec, String packageName) =>
      _invokeOperation('uninstallApplication', spec, {'packageName': packageName});

  @override
  Future<void> launchApplication(SessionSpec spec, String packageName) =>
      _invokeOperation('launchApplication', spec, {'packageName': packageName});

  @override
  Future<void> forceStopApplication(SessionSpec spec, String packageName) =>
      _invokeOperation('forceStopApplication', spec, {'packageName': packageName});

  @override
  Future<void> clearApplicationData(SessionSpec spec, String packageName) =>
      _invokeOperation('clearApplicationData', spec, {'packageName': packageName});

  @override
  Future<void> setApplicationEnabled(
    SessionSpec spec,
    String packageName,
    bool enabled,
  ) => _invokeOperation('setApplicationEnabled', spec, {
    'packageName': packageName,
    'enabled': enabled,
  });

  @override
  Future<void> openApplicationSettings(SessionSpec spec, String packageName) =>
      _invokeOperation('openApplicationSettings', spec, {'packageName': packageName});

  @override
  Future<Map<String, bool>> executionCapabilities({
    bool checkRoot = false,
  }) async {
    final result = await _commands.invokeMapMethod<String, bool>(
      'executionCapabilities',
      {'checkRoot': checkRoot},
    );
    return result ?? const {};
  }

  @override
  Future<bool> requestShizukuPermission() async =>
      await _commands.invokeMethod<bool>('requestShizukuPermission') ?? false;

  AndroidFileSync fileSync(SessionSpec spec) => AndroidFileSync(_commands, spec);

  Future<void> _invokeOperation(
    String method,
    SessionSpec spec,
    Map<String, Object?> arguments,
  ) async {
    await _commands.invokeMethod<void>(method, {
      ..._sessionArguments(spec),
      ...arguments,
    });
  }

  @override
  Future<RawSocket> openRaw(SessionSpec spec, String destination) {
    throw UnsupportedError(
      'Raw ADB sockets are not available for this transport yet.',
    );
  }

  Map<String, Object?> _sessionArguments(SessionSpec spec) => {
    'transport': spec.transport.name,
    'serial': spec.serial,
    'host': spec.host,
    'port': spec.port,
    'workingDir': spec.workingDir,
  };

  void _handleNativeEvent(Object? value) {
    final event = Map<Object?, Object?>.from(value! as Map);
    final stream = ShellStream.values.byName(event['stream']! as String);
    _eventController.add(
      ShellEvent(
        sessionId: event['sessionId']! as String,
        stream: stream,
        data: event['data']! as String,
        exitCode: event['exitCode'] as int?,
      ),
    );
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _eventController.close();
  }
}

class _AndroidShellSession implements ShellSession {
  _AndroidShellSession(this.sessionId, this._commands, this._events);

  final String sessionId;

  final MethodChannel _commands;
  final Stream<ShellEvent> _events;

  @override
  Stream<ShellEvent> get events =>
      _events.where((event) => event.sessionId == sessionId);

  @override
  Future<void> write(String data) async {
    await _commands.invokeMethod<void>('writeStdin', {
      'sessionId': sessionId,
      'data': data,
    });
  }

  @override
  Future<void> close() async {
    await _commands.invokeMethod<void>('closeSession', {
      'sessionId': sessionId,
    });
  }
}

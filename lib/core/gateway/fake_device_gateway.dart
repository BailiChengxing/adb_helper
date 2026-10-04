import 'dart:async';
import 'dart:typed_data';

import 'package:adb_helper/core/model/device.dart';

class FakeShellSession implements ShellSession {
  FakeShellSession({required this.sessionId, required this.spec});

  final String sessionId;
  final SessionSpec spec;
  late final StreamController<ShellEvent> _controller =
      StreamController<ShellEvent>(
        onListen: () => _emit('Connected to ${spec.serial ?? 'local shell'}\n'),
      );

  @override
  Stream<ShellEvent> get events => _controller.stream;

  @override
  Future<void> write(String data) async {
    final command = data.trim();
    if (command.isEmpty) return;

    _emit('\$ $command\n');
    final result = switch (command) {
      'id' =>
        'uid=2000(shell) gid=2000(shell) groups=1003(graphics),3003(inet)\n',
      'pwd' => '${spec.workingDir ?? '/'}\n',
      'ls' || 'ls -la' => 'Download/\nPictures/\nAndroid/\n',
      'getprop' =>
        '[ro.build.version.release]: [15]\n[ro.product.model]: [Demo device]\n',
      'whoami' => 'shell\n',
      'date' => 'Sat Oct  3 12:00:00 UTC 2026\n',
      'clear' => '',
      _ when command.startsWith('echo ') => '${command.substring(5)}\n',
      _ when command.startsWith('logcat') =>
        '10-03 12:00:00.000 I Demo: Simulated logcat output\n',
      _ => 'sh: $command: command is unavailable in demo mode\n',
    };
    if (result.isEmpty) return;
    _controller.add(
      ShellEvent(
        sessionId: sessionId,
        stream: ShellStream.stdout,
        data: result,
      ),
    );
  }

  void _emit(String data) {
    _controller.add(
      ShellEvent(sessionId: sessionId, stream: ShellStream.stdout, data: data),
    );
  }

  @override
  Future<void> close() async {
    _controller.add(
      ShellEvent(
        sessionId: sessionId,
        stream: ShellStream.exit,
        data: 'Session closed',
        exitCode: 0,
      ),
    );
    await _controller.close();
  }
}

class FakeDeviceGateway implements DeviceGateway {
  final List<DeviceRef> _devices = [
    const DeviceRef(
      id: 'device-001',
      label: 'Pixel 9',
      transport: Transport.local,
    ),
    const DeviceRef(
      id: '10.0.0.42:5555',
      label: 'Pixel 7 Wireless',
      transport: Transport.wireless,
    ),
    const DeviceRef(
      id: 'device-otg-1',
      label: 'USB OTG Tablet',
      transport: Transport.otg,
    ),
  ];

  @override
  Future<List<DeviceRef>> discover() async {
    return List.unmodifiable(_devices);
  }

  @override
  Future<Map<String, String>> deviceInformation(SessionSpec spec) async =>
      const {
        'Model': 'Demo device',
        'Android version': '15',
        'Build ID': 'AP3A.241005.015',
        'Serial number': 'demo-serial',
        'ABI': 'arm64-v8a',
        'Screen resolution': '1080x2400',
        'Screen density': '420 dpi',
        'Storage': '128 GB',
      };

  @override
  Future<PairingResult> pair(PairSpec spec) async {
    final serial = '${spec.host}:5555';
    if (_devices.every((device) => device.id != serial)) {
      _devices.add(
        DeviceRef(
          id: serial,
          label: 'Wireless device at ${spec.host}',
          transport: Transport.wireless,
        ),
      );
    }
    return PairingResult(
      ok: true,
      message: 'Pairing succeeded for ${spec.host}:${spec.port}',
      serial: serial,
    );
  }

  @override
  Future<DeviceRef> connectWireless(String host, int port) async {
    final serial = '$host:$port';
    final device = DeviceRef(
      id: serial,
      label: 'Wireless device at $host',
      transport: Transport.wireless,
    );
    if (_devices.every((entry) => entry.id != serial)) _devices.add(device);
    return device;
  }

  @override
  Future<ShellSession> open(SessionSpec spec) async {
    final id = 'session-${DateTime.now().microsecondsSinceEpoch}';
    return FakeShellSession(sessionId: id, spec: spec);
  }

  @override
  Future<int> execOnce(SessionSpec spec, String command) async {
    if (command.contains('error')) {
      return 1;
    }
    return 0;
  }

  @override
  Future<RawSocket> openRaw(SessionSpec spec, String destination) async {
    return FakeRawSocket();
  }

  @override
  Future<List<InstalledApp>> listApplications(SessionSpec spec) async => const [
    InstalledApp(packageName: 'com.example.notes', versionName: '1.0'),
    InstalledApp(packageName: 'com.example.camera', versionName: '2.4'),
    InstalledApp(
      packageName: 'com.android.settings',
      versionName: '15',
      systemApp: true,
    ),
  ];

  @override
  Future<List<InstalledApp>> listHostApplications() async => const [
    InstalledApp(packageName: 'com.example.notes', versionName: '1.0'),
    InstalledApp(packageName: 'com.example.camera', versionName: '2.4'),
  ];

  @override
  Future<String?> pickDocument({
    bool apkOnly = false,
    bool aabOnly = false,
    String? saveAs,
  }) async =>
      'demo://$saveAs';

  @override
  Future<void> installApplication(SessionSpec spec, String documentUri) async {}

  @override
  Future<void> installHostApplication(SessionSpec spec, String packageName) async {}

  @override
  Future<void> uninstallApplication(
    SessionSpec spec,
    String packageName,
  ) async {}

  @override
  Future<void> launchApplication(SessionSpec spec, String packageName) async {}

  @override
  Future<void> forceStopApplication(
    SessionSpec spec,
    String packageName,
  ) async {}

  @override
  Future<void> clearApplicationData(
    SessionSpec spec,
    String packageName,
  ) async {}

  @override
  Future<void> setApplicationEnabled(
    SessionSpec spec,
    String packageName,
    bool enabled,
  ) async {}

  @override
  Future<void> openApplicationSettings(
    SessionSpec spec,
    String packageName,
  ) async {}

  @override
  Future<Map<String, bool>> executionCapabilities({
    bool checkRoot = false,
  }) async => const {
    'shizukuAvailable': false,
    'shizukuPermission': false,
    'rootAvailable': false,
  };

  @override
  Future<bool> requestShizukuPermission() async => false;
}

class FakeRawSocket implements RawSocket {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get bytes => _controller.stream;

  @override
  Future<void> send(Uint8List data) async {
    _controller.add(Uint8List.fromList(data));
  }

  @override
  Future<void> close() => _controller.close();
}

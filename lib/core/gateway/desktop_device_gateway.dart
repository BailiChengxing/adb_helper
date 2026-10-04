import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_helper/core/model/device.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopDeviceGateway implements DeviceGateway {
  Future<void>? _serverStart;
  final Map<String, _DesktopShellSession> _sessions = {};

  @override
  Future<List<DeviceRef>> discover() async {
    final output = await _runAdb(['devices', '-l']);
    final devices = <DeviceRef>[];
    for (final line in const LineSplitter().convert(output)) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 2 || fields[0] == 'List' || fields[1] != 'device') {
        continue;
      }
      final serial = fields.first;
      final metadata = fields
          .skip(2)
          .map((field) {
            final pair = field.split('=');
            return pair.length == 2 ? MapEntry(pair.first, pair.last) : null;
          })
          .whereType<MapEntry<String, String>>()
          .toList();
      final values = Map.fromEntries(metadata);
      final model = values['model']?.replaceAll('_', ' ');
      final transport = serial.contains(':')
          ? Transport.wireless
          : Transport.usb;
      devices.add(
        DeviceRef(
          id: serial,
          label: model == null || model.isEmpty ? serial : model,
          transport: transport,
        ),
      );
    }
    return devices;
  }

  @override
  Future<List<DeviceRef>> scanLocalNetwork() async {
    final devices = <String, DeviceRef>{
      for (final device in await discover())
        if (device.transport == Transport.wireless) device.id: device,
    };
    final result = await _runAdbResult(['mdns', 'services']);
    if (result.exitCode != 0) throw _commandFailure(result);
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 3 || fields.first != 'adb-tls-connect') continue;
      final endpoint = _parseEndpoint(fields.last);
      if (endpoint == null) continue;
      final serviceSuffix = '._adb-tls-connect._tcp.';
      final label = fields[1].endsWith(serviceSuffix)
          ? fields[1].substring(0, fields[1].length - serviceSuffix.length)
          : fields[1];
      final device = DeviceRef(
        id: _endpoint(endpoint.host, endpoint.port),
        label: label.isEmpty ? endpoint.host : label,
        transport: Transport.wireless,
      );
      devices[device.id] = device;
    }
    return devices.values.toList(growable: false);
  }

  ({String host, int port})? _parseEndpoint(String value) {
    final separator = value.lastIndexOf(':');
    if (separator <= 0) return null;
    var host = value.substring(0, separator);
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    final port = int.tryParse(value.substring(separator + 1));
    if (InternetAddress.tryParse(host) == null ||
        port == null ||
        port < 1 ||
        port > 65535) {
      return null;
    }
    return (host: host, port: port);
  }

  @override
  Future<Map<String, String>> deviceInformation(SessionSpec spec) async {
    final output = await _runShell(spec, 'getprop');
    final information = <String, String>{};
    for (final line in const LineSplitter().convert(output)) {
      if (!line.startsWith('[') || !line.endsWith(']')) continue;
      final separator = line.indexOf(']: [');
      if (separator < 0) continue;
      final property = line.substring(1, separator);
      final value = line.substring(separator + 4, line.length - 1);
      final key = switch (property) {
        'ro.product.manufacturer' => 'Manufacturer',
        'ro.product.brand' => 'Brand',
        'ro.product.model' => 'Model',
        'ro.product.device' => 'Device',
        'ro.build.version.release' => 'Android version',
        'ro.build.version.sdk' => 'API level',
        'ro.build.version.security_patch' => 'Security patch',
        'ro.build.display.id' => 'Build ID',
        'ro.build.fingerprint' => 'Build fingerprint',
        'ro.product.cpu.abi' => 'Primary ABI',
        'ro.serialno' => 'Serial number',
        _ => null,
      };
      if (key != null && value.isNotEmpty) {
        information[key] = value;
      }
    }
    for (final (label, command) in const [
      ('Screen resolution', 'wm size'),
      ('Screen density', 'wm density'),
      ('Data storage', 'df -h /data'),
      ('Memory', 'cat /proc/meminfo | head -n 3'),
    ]) {
      final value = await _runShell(spec, command);
      if (value.trim().isNotEmpty) information[label] = value.trim();
    }
    return information;
  }

  @override
  Future<PairingResult> pair(PairSpec spec) async {
    final result = await _runAdbResult([
      'pair',
      _endpoint(spec.host, spec.port),
      spec.code,
    ]);
    final message = _combinedOutput(result);
    return PairingResult(
      ok: result.exitCode == 0 && !message.toLowerCase().contains('failed'),
      message: message.trim(),
    );
  }

  @override
  Future<DeviceRef> connectWireless(String host, int port) async {
    final serial = _endpoint(host, port);
    final result = await _runAdbResult(['connect', serial]);
    final output = _combinedOutput(result).trim();
    if (result.exitCode != 0 ||
        output.toLowerCase().contains('failed') ||
        output.toLowerCase().contains('unable')) {
      throw ProcessException(
        await _adbExecutable(),
        ['connect', serial],
        output,
        result.exitCode,
      );
    }
    return DeviceRef(
      id: serial,
      label: 'Wireless device at $host',
      transport: Transport.wireless,
    );
  }

  @override
  Future<ShellSession> open(SessionSpec spec) async {
    await _ensureServer();
    final process = await Process.start(
      await _adbExecutable(),
      _targetArgs(spec, const ['shell']),
    );
    final id = 'desktop-${DateTime.now().microsecondsSinceEpoch}';
    final session = _DesktopShellSession(id, process);
    _sessions[id] = session;
    unawaited(
      session.events
          .firstWhere((event) => event.stream == ShellStream.exit)
          .then((_) => _sessions.remove(id)),
    );
    return session;
  }

  @override
  Future<int> execOnce(SessionSpec spec, String command) async {
    final result = await _runAdbResult(_targetArgs(spec, ['shell', command]));
    return result.exitCode;
  }

  @override
  Future<RawSocket> openRaw(SessionSpec spec, String destination) =>
      Future.error(
        UnsupportedError(
          'Raw ADB sockets are not available in the desktop backend yet.',
        ),
      );

  @override
  Future<List<InstalledApp>> listApplications(SessionSpec spec) async {
    final all = await _runShell(spec, 'pm list packages --show-versioncode');
    final system = (await _runShell(spec, 'pm list packages -s'))
        .split('\n')
        .map((line) => line.replaceFirst('package:', '').trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    return all
        .split('\n')
        .map((line) {
          final match = RegExp(r'^package:([^\s]+)(?:\s+versionCode:(\d+))?')
              .firstMatch(line.trim());
          if (match == null) return null;
          return InstalledApp(
            packageName: match.group(1)!,
            versionCode: int.tryParse(match.group(2) ?? ''),
            systemApp: system.contains(match.group(1)),
          );
        })
        .whereType<InstalledApp>()
        .toList(growable: false);
  }

  @override
  Future<List<InstalledApp>> listHostApplications() => Future.error(
    UnsupportedError(
      'This option is available when running on an Android device.',
    ),
  );

  @override
  Future<void> installHostApplication(SessionSpec spec, String packageName) =>
      Future.error(
        UnsupportedError(
          'Install-from-this-device is available on Android only.',
        ),
      );

  @override
  Future<String?> pickDocument({
    bool apkOnly = false,
    bool aabOnly = false,
    String? saveAs,
  }) async {
    if (saveAs != null) {
      throw UnsupportedError(
        'Desktop file downloads are not implemented in this milestone.',
      );
    }
    final extensions = apkOnly
        ? ['apk']
        : aabOnly
        ? ['aab']
        : null;
    final result = await FilePicker.pickFile(
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
    );
    return result?.path;
  }

  @override
  Future<void> installApplication(SessionSpec spec, String documentUri) async {
    final uri = Uri.tryParse(documentUri);
    final path = uri?.scheme == 'file' ? uri!.toFilePath() : documentUri;
    if (path.toLowerCase().endsWith('.aab')) {
      await _installAab(spec, path);
      return;
    }
    await _checkedAdb(_targetArgs(spec, ['install', '-r', path]));
  }

  Future<void> _installAab(SessionSpec spec, String path) async {
    final bundletool = await _bundletoolJar();
    final output = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'adb_helper_${DateTime.now().microsecondsSinceEpoch}.apks',
    );
    try {
      await _checkedProcess('java', [
        '-jar',
        bundletool,
        'build-apks',
        '--bundle=$path',
        '--output=${output.path}',
        '--connected-device',
        '--device-id=${spec.serial}',
      ]);
      await _checkedProcess('java', [
        '-jar',
        bundletool,
        'install-apks',
        '--apks=${output.path}',
        '--device-id=${spec.serial}',
      ]);
    } finally {
      if (await output.exists()) await output.delete();
    }
  }

  Future<String> _bundletoolJar() async {
    final adb = await _adbExecutable();
    final candidate = File(
      '${File(adb).parent.path}${Platform.pathSeparator}bundletool.jar',
    );
    if (await FileSystemEntity.type(candidate.path) ==
        FileSystemEntityType.file) {
      return candidate.path;
    }
    throw FileSystemException(
      'Install bundletool.jar next to platform-tools to install Android App Bundles.',
      candidate.path,
    );
  }

  @override
  Future<void> uninstallApplication(SessionSpec spec, String packageName) =>
      _checkedAdb(_targetArgs(spec, ['uninstall', packageName]));

  @override
  Future<void> launchApplication(SessionSpec spec, String packageName) =>
      _checkedShell(spec, 'monkey -p ${_quote(packageName)} 1');

  @override
  Future<void> forceStopApplication(SessionSpec spec, String packageName) =>
      _checkedShell(spec, 'am force-stop ${_quote(packageName)}');

  @override
  Future<void> clearApplicationData(SessionSpec spec, String packageName) =>
      _checkedShell(spec, 'pm clear ${_quote(packageName)}');

  @override
  Future<void> setApplicationEnabled(
    SessionSpec spec,
    String packageName,
    bool enabled,
  ) => _checkedShell(
    spec,
    'pm ${enabled ? 'enable' : 'disable-user'} ${_quote(packageName)}',
  );

  @override
  Future<void> openApplicationSettings(SessionSpec spec, String packageName) =>
      _checkedShell(
        spec,
        'am start -a android.settings.APPLICATION_DETAILS_SETTINGS '
        '-d package:${_quote(packageName)}',
      );

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

  Future<String> _runShell(SessionSpec spec, String command) async {
    final result = await _runAdbResult(_targetArgs(spec, ['shell', command]));
    if (result.exitCode != 0) throw _commandFailure(result);
    return result.stdout.toString();
  }

  Future<void> _checkedShell(SessionSpec spec, String command) async {
    final output = await _runShell(spec, command);
    if (RegExp(
      r'^(Failure|Error|Exception)\b',
      multiLine: true,
      caseSensitive: false,
    ).hasMatch(output)) {
      throw ProcessException(await _adbExecutable(), [command], output);
    }
  }

  Future<void> _checkedAdb(List<String> arguments) async {
    final result = await _runAdbResult(arguments);
    if (result.exitCode != 0) throw _commandFailure(result);
  }

  Future<void> _checkedProcess(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        _combinedOutput(result),
        result.exitCode,
      );
    }
  }

  Future<ProcessResult> _runAdbResult(List<String> arguments) async {
    await _ensureServer();
    return Process.run(await _adbExecutable(), arguments);
  }

  Future<String> _runAdb(List<String> arguments) async {
    final result = await _runAdbResult(arguments);
    if (result.exitCode != 0) throw _commandFailure(result);
    return result.stdout.toString();
  }

  Future<void> _ensureServer() => _serverStart ??= _startServer();

  Future<void> _startServer() async {
    await _checkedProcess(await _adbExecutable(), ['start-server']);
  }

  Future<String> _adbExecutable() async {
    final preferences = await SharedPreferences.getInstance();
    final configured = preferences.getString('platformToolsPath')?.trim() ?? '';
    final candidates = <String>[];
    if (configured.isNotEmpty) {
      final file = File(configured);
      if (await file.exists()) {
        candidates.add(file.path);
      } else {
        candidates.add(_join(configured, _adbName));
      }
    }
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    candidates.addAll([
      _join(_join(executableDirectory, 'platform-tools'), _adbName),
      _join(
        _join(_join(executableDirectory, 'data'), 'platform-tools'),
        _adbName,
      ),
      _join(
        _join(_join(executableDirectory, '..'), 'Resources'),
        _join('platform-tools', _adbName),
      ),
      _join(_join(Directory.current.path, 'platform-tools'), _adbName),
    ]);
    for (final candidate in candidates) {
      if (await FileSystemEntity.type(candidate) == FileSystemEntityType.file) {
        return candidate;
      }
    }
    return _adbName;
  }

  String get _adbName => Platform.isWindows ? 'adb.exe' : 'adb';

  List<String> _targetArgs(SessionSpec spec, List<String> command) {
    final serial = spec.serial;
    if (serial == null || serial.isEmpty) {
      throw ArgumentError(
        'A connected device serial is required for desktop ADB.',
      );
    }
    return ['-s', serial, ...command];
  }

  String _endpoint(String host, int port) {
    final normalizedHost = host.contains(':') && !host.startsWith('[')
        ? '[$host]'
        : host;
    return '$normalizedHost:$port';
  }

  String _join(String first, String second) =>
      '$first${Platform.pathSeparator}$second';

  String _quote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

  String _combinedOutput(ProcessResult result) =>
      '${result.stdout}${result.stderr}';

  ProcessException _commandFailure(ProcessResult result) => ProcessException(
    'adb',
    const [],
    _combinedOutput(result).trim(),
    result.exitCode,
  );
}

class _DesktopShellSession implements ShellSession {
  _DesktopShellSession(this.sessionId, this._process) {
    _process.stdout.listen(
      (bytes) => _events.add(
        ShellEvent(
          sessionId: sessionId,
          stream: ShellStream.stdout,
          data: utf8.decode(bytes, allowMalformed: true),
        ),
      ),
      onError: _emitError,
    );
    _process.stderr.listen(
      (bytes) => _events.add(
        ShellEvent(
          sessionId: sessionId,
          stream: ShellStream.stderr,
          data: utf8.decode(bytes, allowMalformed: true),
        ),
      ),
      onError: _emitError,
    );
    _process.exitCode.then((code) {
      _events.add(
        ShellEvent(
          sessionId: sessionId,
          stream: ShellStream.exit,
          data: 'ADB shell exited.',
          exitCode: code,
        ),
      );
      unawaited(_events.close());
    });
  }

  final String sessionId;
  final Process _process;
  final StreamController<ShellEvent> _events = StreamController.broadcast();

  @override
  Stream<ShellEvent> get events => _events.stream;

  @override
  Future<void> write(String data) async {
    _process.stdin.write(data);
    await _process.stdin.flush();
  }

  @override
  Future<void> close() async {
    await _process.stdin.close();
    _process.kill();
  }

  void _emitError(Object error, StackTrace stack) {
    _events.addError(error, stack);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adb_helper/core/model/device.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopDeviceGateway implements DeviceGateway {
  Future<void>? _serverStart;
  final Map<String, _DesktopShellSession> _sessions = {};
  final Map<String, (String label, String? versionName)>
  _applicationMetadataCache = {};
  final Map<String, bool> _remoteUnzipSupport = {};
  String? _aaptExecutablePath;
  bool _aaptResolved = false;

  FileSync fileSync(SessionSpec spec) => _DesktopFileSync(this, spec);

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

  Future<List<InstalledApp>> enrichApplications(
    SessionSpec spec,
    List<InstalledApp> applications,
  ) async {
    if (applications.isEmpty) return applications;
    final paths = await _packagePaths(spec);
    if (paths.isEmpty) return applications;

    final aapt = await _aaptExecutable();
    if (aapt == null || !await _remoteUnzipAvailable(spec)) {
      return applications;
    }

    final enriched = <InstalledApp>[];
    for (var start = 0; start < applications.length; start += 4) {
      var end = start + 4;
      if (end > applications.length) end = applications.length;
      final batch = applications.sublist(start, end);
      enriched.addAll(
        await Future.wait(
          batch.map(
            (app) => _enrichApplication(
              spec,
              app,
              paths[app.packageName],
              aapt,
            ),
          ),
        ),
      );
    }
    return enriched;
  }

  Future<Map<String, String>> _packagePaths(SessionSpec spec) async {
    try {
      final output = await _runShell(spec, 'pm list packages -f');
      final paths = <String, String>{};
      for (final line in const LineSplitter().convert(output)) {
        if (!line.startsWith('package:')) continue;
        final separator = line.lastIndexOf('=');
        if (separator <= 'package:'.length) continue;
        final path = line.substring('package:'.length, separator);
        final packageName = line.substring(separator + 1).trim();
        if (path.isNotEmpty && packageName.isNotEmpty) {
          paths[packageName] = path;
        }
      }
      return paths;
    } catch (_) {
      return const {};
    }
  }

  Future<bool> _remoteUnzipAvailable(SessionSpec spec) async {
    final key = spec.serial ?? '';
    final cached = _remoteUnzipSupport[key];
    if (cached != null) return cached;
    try {
      final output = await _runShell(
        spec,
        'command -v unzip || command -v toybox',
      );
      final available = output.trim().isNotEmpty;
      _remoteUnzipSupport[key] = available;
      return available;
    } catch (_) {
      _remoteUnzipSupport[key] = false;
      return false;
    }
  }

  Future<InstalledApp> _enrichApplication(
    SessionSpec spec,
    InstalledApp app,
    String? apkPath,
    String aapt,
  ) async {
    if (apkPath == null) return app;
    final key = '${spec.serial ?? ''}:${app.packageName}';
    final cached = _applicationMetadataCache[key];
    if (cached != null) {
      return _withMetadata(app, cached.$1, cached.$2);
    }

    final manifest = await _readRemoteEntry(
      spec,
      apkPath,
      'AndroidManifest.xml',
    );
    final resources = await _readRemoteEntry(
      spec,
      apkPath,
      'resources.arsc',
    );
    if (manifest == null || resources == null) {
      return _enrichFromPulledApk(spec, app, apkPath, aapt);
    }

    Directory? tempDirectory;
    try {
      tempDirectory = await Directory.systemTemp.createTemp(
        'adb_helper_manifest_',
      );
      final archivePath = _join(tempDirectory.path, 'manifest.zip');
      await File(archivePath).writeAsBytes(
        _buildStoredZip(<String, List<int>>{
          'AndroidManifest.xml': manifest,
          'resources.arsc': resources,
        }),
        flush: true,
      );

      final result = await Process.run(
        aapt,
        ['dump', 'badging', archivePath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return app;

      final output = result.stdout.toString();
      final label = _parseAaptLabel(output);
      final versionName = RegExp(
        r"^versionName:'([^']*)'",
        multiLine: true,
      ).firstMatch(output)?.group(1);
      if (label == null) return app;

      _applicationMetadataCache[key] = (label, versionName);
      return _withMetadata(app, label, versionName);
    } catch (_) {
      return app;
    } finally {
      try {
        await tempDirectory?.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<InstalledApp> _enrichFromPulledApk(
    SessionSpec spec,
    InstalledApp app,
    String apkPath,
    String aapt,
  ) async {
    Directory? tempDirectory;
    try {
      tempDirectory = await Directory.systemTemp.createTemp(
        'adb_helper_apk_',
      );
      final localApk = _join(tempDirectory.path, 'application.apk');
      final pull = await Process.run(
        await _adbExecutable(),
        _targetArgs(spec, ['pull', apkPath, localApk]),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (pull.exitCode != 0) return app;

      final result = await Process.run(
        aapt,
        ['dump', 'badging', localApk],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return app;

      final output = result.stdout.toString();
      final label = _parseAaptLabel(output);
      final versionName = RegExp(
        r"^versionName:'([^']*)'",
        multiLine: true,
      ).firstMatch(output)?.group(1);
      if (label == null) return app;

      final key = '${spec.serial ?? ''}:${app.packageName}';
      _applicationMetadataCache[key] = (label, versionName);
      return _withMetadata(app, label, versionName);
    } catch (_) {
      return app;
    } finally {
      try {
        await tempDirectory?.delete(recursive: true);
      } catch (_) {}
    }
  }

  InstalledApp _withMetadata(
    InstalledApp app,
    String label,
    String? versionName,
  ) => InstalledApp(
    packageName: app.packageName,
    label: label,
    versionName: versionName ?? app.versionName,
    versionCode: app.versionCode,
    iconBytes: app.iconBytes,
    systemApp: app.systemApp,
    enabled: app.enabled,
  );

  String? _parseAaptLabel(String output) {
    final pattern = RegExp(
      r"^application-label(?:-[^:]+)?:'([^']*)'",
      multiLine: true,
    );
    for (final match in pattern.allMatches(output)) {
      final value = (match.group(1) ?? match.group(2) ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<List<int>?> _readRemoteEntry(
    SessionSpec spec,
    String apkPath,
    String entry,
  ) async {
    final path = _quote(apkPath);
    for (final command in <String>[
      'unzip -p $path $entry',
      'toybox unzip -p $path $entry',
    ]) {
      final bytes = await _runAdbRaw(spec, command);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    return null;
  }

  Future<List<int>?> _runAdbRaw(SessionSpec spec, String command) async {
    try {
      await _ensureServer();
      final result = await Process.run(
        await _adbExecutable(),
        _targetArgs(spec, ['exec-out', command]),
        stdoutEncoding: null,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return null;
      final stdout = result.stdout;
      if (stdout is List<int>) return stdout;
      if (stdout is String) return utf8.encode(stdout);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _aaptExecutable() async {
    if (_aaptResolved) return _aaptExecutablePath;
    _aaptResolved = true;

    final executableName = Platform.isWindows ? 'aapt2.exe' : 'aapt2';
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final adjacentRoots = <String>{
      executableDirectory,
      Directory.current.path,
    };

    for (final root in adjacentRoots) {
      final candidates = <String>[
        _join(_join(root, 'platform-tools'), executableName),
        _join(_join(root, _platformToolsSourceName), executableName),
        _join(
          _join(_join(root, 'adb_sdk'), _platformToolsSourceName),
          executableName,
        ),
      ];
      for (final candidate in candidates) {
        if (FileSystemEntity.typeSync(candidate) ==
            FileSystemEntityType.file) {
          _aaptExecutablePath = candidate;
          return candidate;
        }
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final configured = preferences.getString('androidSdkPath')?.trim();
    final roots = <String>[];
    if (configured != null && configured.isNotEmpty) roots.add(configured);
    final androidHome = Platform.environment['ANDROID_HOME'];
    if (androidHome != null && androidHome.isNotEmpty) roots.add(androidHome);
    final androidSdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
    if (androidSdkRoot != null && androidSdkRoot.isNotEmpty) {
      roots.add(androidSdkRoot);
    }
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      roots.add(_join(userProfile, r'AppData\Local\Android\Sdk'));
    }

    for (final root in roots.where((value) => value.isNotEmpty)) {
      final direct = _join(root, executableName);
      if (FileSystemEntity.typeSync(direct) == FileSystemEntityType.file) {
        _aaptExecutablePath = direct;
        return direct;
      }

      final buildTools = Directory(_join(root, 'build-tools'));
      if (!buildTools.existsSync()) continue;
      final directories = buildTools
          .listSync()
          .whereType<Directory>()
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final directory in directories) {
        final candidate = _join(directory.path, executableName);
        if (FileSystemEntity.typeSync(candidate) ==
            FileSystemEntityType.file) {
          _aaptExecutablePath = candidate;
          return candidate;
        }
      }
    }
    return null;
  }

  List<int> _buildStoredZip(Map<String, List<int>> entries) {
    final builder = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    final offsets = <int>[];

    for (final entry in entries.entries) {
      final name = utf8.encode(entry.key);
      final data = entry.value;
      final crc = _crc32(data);
      offsets.add(builder.length);

      _addUint32(builder, 0x04034b50);
      _addUint16(builder, 20);
      _addUint16(builder, 0);
      _addUint16(builder, 0);
      _addUint16(builder, 0);
      _addUint16(builder, 0);
      _addUint32(builder, crc);
      _addUint32(builder, data.length);
      _addUint32(builder, data.length);
      _addUint16(builder, name.length);
      _addUint16(builder, 0);
      builder.add(name);
      builder.add(data);
    }

    final centralOffset = builder.length;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries.entries.elementAt(index);
      final name = utf8.encode(entry.key);
      final data = entry.value;
      final crc = _crc32(data);

      _addUint32(central, 0x02014b50);
      _addUint16(central, 20);
      _addUint16(central, 20);
      _addUint16(central, 0);
      _addUint16(central, 0);
      _addUint16(central, 0);
      _addUint16(central, 0);
      _addUint32(central, crc);
      _addUint32(central, data.length);
      _addUint32(central, data.length);
      _addUint16(central, name.length);
      _addUint16(central, 0);
      _addUint16(central, 0);
      _addUint16(central, 0);
      _addUint16(central, 0);
      _addUint32(central, 0);
      _addUint32(central, offsets[index]);
      central.add(name);
    }

    builder.add(central.takeBytes());
    _addUint32(builder, 0x06054b50);
    _addUint16(builder, 0);
    _addUint16(builder, 0);
    _addUint16(builder, entries.length);
    _addUint16(builder, entries.length);
    _addUint32(builder, builder.length - centralOffset);
    _addUint32(builder, centralOffset);
    _addUint16(builder, 0);
    return builder.takeBytes();
  }

  int _crc32(List<int> data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0
            ? (crc >> 1) ^ 0xedb88320
            : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  void _addUint16(BytesBuilder builder, int value) {
    builder.add([value & 0xff, (value >> 8) & 0xff]);
  }

  void _addUint32(BytesBuilder builder, int value) {
    builder.add([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
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
      final destination = await FilePicker.saveFile(
        fileName: saveAs,
        bytes: Uint8List(0),
      );
      return destination?.toString();
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
    final result = await Process.run(
      executable,
      arguments,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
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
    return Process.run(
      await _adbExecutable(),
      arguments,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
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
      if (await FileSystemEntity.type(configured) ==
          FileSystemEntityType.file) {
        candidates.add(configured);
      } else {
        candidates.addAll([
          _join(configured, _adbName),
          _join(_join(configured, 'platform-tools'), _adbName),
          _join(_join(configured, _platformToolsSourceName), _adbName),
        ]);
      }
    }

    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    for (final root in <String>{executableDirectory, Directory.current.path}) {
      candidates.addAll([
        _join(_join(root, 'platform-tools'), _adbName),
        _join(_join(root, _platformToolsSourceName), _adbName),
        _join(_join(_join(root, 'adb_sdk'), _platformToolsSourceName), _adbName),
        _join(_join(_join(root, 'data'), 'platform-tools'), _adbName),
        _join(
          _join(_join(root, '..'), 'Resources'),
          _join('platform-tools', _adbName),
        ),
      ]);
    }

    for (final candidate in candidates) {
      if (await FileSystemEntity.type(candidate) == FileSystemEntityType.file) {
        return candidate;
      }
    }
    return _adbName;
  }

  String get _platformToolsSourceName => switch (Platform.operatingSystem) {
    'windows' => 'platform-tools-windows',
    'macos' => 'platform-tools-darwin',
    _ => 'platform-tools-linux',
  };

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

class _DesktopFileSync implements FileSync {
  _DesktopFileSync(this._gateway, this._spec);

  final DesktopDeviceGateway _gateway;
  final SessionSpec _spec;

  @override
  FileSync forSession(SessionSpec spec) => _DesktopFileSync(_gateway, spec);

  @override
  Future<List<FileEntry>> list(String path) async {
    final normalized = _validatePath(path);
    final output = await _gateway._runShell(
      _spec,
      'ls -la -n ${_quote(normalized)}',
    );
    final entries = <FileEntry>[];
    for (final line in const LineSplitter().convert(output)) {
      final match = _fileListLine.firstMatch(line);
      if (match == null) continue;
      final name = match.group(5)!;
      if (name == '.' || name == '..') continue;
      entries.add(
        FileEntry(
          name: name,
          path: normalized == '/' ? '/$name' : '$normalized/$name',
          isDirectory: match.group(1)!.startsWith('d'),
          size: int.tryParse(match.group(2)!) ?? 0,
          mode: match.group(1)!,
          mtime: '${match.group(3)} ${match.group(4)}',
        ),
      );
    }
    if (entries.isEmpty &&
        output.trim().isNotEmpty &&
        !output.contains('total ')) {
      throw const FormatException(
        'The device returned an unsupported directory listing format.',
      );
    }
    return entries;
  }

  @override
  Future<void> push(
    String documentUri,
    String remote,
    ProgressSink onProgress,
  ) async {
    final source = _localPath(documentUri);
    final destination = _validatePath(remote);
    onProgress(0, 'Uploading');
    await _gateway._checkedAdb(
      _gateway._targetArgs(_spec, ['push', source, destination]),
    );
    onProgress(1, 'Upload complete');
  }

  @override
  Future<void> pull(
    String remote,
    String documentUri,
    ProgressSink onProgress,
  ) async {
    final source = _validatePath(remote);
    final destination = _localPath(documentUri);
    onProgress(0, 'Downloading');
    await _gateway._checkedAdb(
      _gateway._targetArgs(_spec, ['pull', source, destination]),
    );
    onProgress(1, 'Download complete');
  }

  @override
  Future<void> delete(String path) => _runShellOperation(
    'rm -rf ${_quote(_validatePath(path))}',
  );

  @override
  Future<void> mkdir(String path) => _runShellOperation(
    'mkdir -p ${_quote(_validatePath(path))}',
  );

  @override
  Future<void> rename(String from, String to) => _runShellOperation(
    'mv ${_quote(_validatePath(from))} ${_quote(_validatePath(to))}',
  );

  @override
  Future<FileStat> stat(String path) async {
    final normalized = _validatePath(path);
    final parent = _parent(normalized);
    final entry = (await list(parent)).where((item) {
      return item.path == normalized;
    }).firstOrNull;
    if (entry == null) {
      throw FileSystemException('File not found on the device', normalized);
    }
    return FileStat(
      size: entry.size,
      mode: entry.mode,
      mtime: entry.mtime,
    );
  }

  Future<void> _runShellOperation(String command) async {
    await _gateway._runShell(_spec, command);
  }

  String _validatePath(String path) {
    if (!path.startsWith('/') ||
        path.trim().isEmpty ||
        path.contains('\u0000') ||
        path.contains('\n') ||
        path.contains('\r')) {
      throw ArgumentError.value(path, 'path', 'Must be a valid absolute path.');
    }
    return path;
  }

  String _localPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'file') return uri.toFilePath();
    return value;
  }

  String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  String _parent(String path) {
    final separator = path.lastIndexOf('/');
    return separator <= 0 ? '/' : path.substring(0, separator);
  }

  static final RegExp _fileListLine = RegExp(
    r'^(\S+)\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)$',
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

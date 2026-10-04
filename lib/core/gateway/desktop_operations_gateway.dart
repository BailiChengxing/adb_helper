import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_helper/core/model/device.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopFastbootGateway implements FastbootGateway {
  @override
  Future<List<String>> devices() async {
    final executable = await _findTool('fastboot');
    final result = await Process.run(
      executable,
      ['devices'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        const ['devices'],
        _combinedOutput(result),
        result.exitCode,
      );
    }

    return result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.split(RegExp(r'\s+')).first)
        .where((serial) => serial != 'fastboot')
        .toSet()
        .toList(growable: false);
  }

  @override
  Future<void> flash(
    String partition,
    String image,
    ProgressSink onProgress, {
    String? serial,
  }) async {
    if (partition.isEmpty || !RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(partition)) {
      throw ArgumentError.value(partition, 'partition');
    }
    if (!await File(image).exists()) {
      throw FileSystemException('Image file does not exist.', image);
    }

    final executable = await _findTool('fastboot');
    final arguments = <String>[
      if (serial != null && serial.isNotEmpty) ...['-s', serial],
      'flash',
      partition,
      image,
    ];
    await _runStreaming(
      executable,
      arguments,
      onProgress,
      'Starting flash',
      'Flash completed',
    );
  }

  @override
  Future<void> reboot(
    String mode, {
    String? serial,
  }) async {
    const allowed = {'system', 'bootloader', 'recovery'};
    if (!allowed.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }

    final executable = await _findTool('fastboot');
    final arguments = <String>[
      if (serial != null && serial.isNotEmpty) ...['-s', serial],
      'reboot',
      if (mode != 'system') mode,
    ];
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

  Future<void> _runStreaming(
    String executable,
    List<String> arguments,
    ProgressSink onProgress,
    String startMessage,
    String successMessage,
  ) async {
    onProgress(0.05, startMessage);
    final process = await Process.start(executable, arguments);
    final output = StringBuffer();
    var progress = 0.15;

    Future<void> listen(Stream<List<int>> stream) => stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.trim().isEmpty) return;
          output.writeln(line);
          progress = progress < 0.85 ? progress + 0.08 : progress;
          onProgress(progress, line.trim());
        })
        .asFuture();

    final listeners = <Future<void>>[
      listen(process.stdout),
      listen(process.stderr),
    ];
    final exitCode = await process.exitCode;
    await Future.wait(listeners);

    if (exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        output.toString().trim(),
        exitCode,
      );
    }
    onProgress(1, successMessage);
  }
}

class DesktopSideloadGateway implements SideloadGateway {
  @override
  Future<void> sideload(
    String file,
    ProgressSink onProgress, {
    String? serial,
  }) async {
    if (!await File(file).exists()) {
      throw FileSystemException('Sideload package does not exist.', file);
    }

    final executable = await _findTool('adb');
    final arguments = <String>[
      if (serial != null && serial.isNotEmpty) ...['-s', serial],
      'sideload',
      file,
    ];
    onProgress(0.05, 'Starting sideload');

    final process = await Process.start(executable, arguments);
    final output = StringBuffer();
    var progress = 0.15;
    Future<void> listen(Stream<List<int>> stream) => stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.trim().isEmpty) return;
          output.writeln(line);
          progress = progress < 0.9 ? progress + 0.05 : progress;
          onProgress(progress, line.trim());
        })
        .asFuture();

    final listeners = <Future<void>>[
      listen(process.stdout),
      listen(process.stderr),
    ];
    final exitCode = await process.exitCode;
    await Future.wait(listeners);

    if (exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        output.toString().trim(),
        exitCode,
      );
    }
    onProgress(1, 'Sideload completed');
  }
}

class DesktopDeviceToolsGateway implements DeviceToolsGateway {
  @override
  Future<void> setWirelessDebugging(SessionSpec spec, bool enabled) =>
      _runAdb(
        spec,
        enabled
            ? ['tcpip', '5555']
            : ['usb'],
      );

  @override
  Future<void> screenshot(SessionSpec spec, String destination) async {
    final executable = await _findTool('adb');
    final result = await Process.run(
      executable,
      [
        if (spec.serial != null && spec.serial!.isNotEmpty) ...[
          '-s',
          spec.serial!,
        ],
        'exec-out',
        'screencap -p',
      ],
      stdoutEncoding: null,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        const ['exec-out', 'screencap -p'],
        '${result.stderr}',
        result.exitCode,
      );
    }
    final bytes = result.stdout;
    if (bytes is! List<int> || bytes.isEmpty) {
      throw ProcessException(
        executable,
        const ['exec-out', 'screencap -p'],
        'The device returned an empty screenshot.',
        1,
      );
    }
    final uri = Uri.tryParse(destination);
    final localPath = uri?.scheme == 'file' ? uri!.toFilePath() : destination;
    await File(localPath).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> advancedReboot(SessionSpec spec, String mode) {
    const allowed = {'system', 'bootloader', 'recovery'};
    if (!allowed.contains(mode)) {
      return Future.error(ArgumentError.value(mode, 'mode'));
    }
    return _runAdb(
      spec,
      mode == 'system'
          ? ['reboot']
          : ['reboot', mode],
    );
  }

  @override
  Future<void> setDpi(SessionSpec spec, int dpi) {
    if (dpi < 100 || dpi > 1000) {
      return Future.error(ArgumentError.value(dpi, 'dpi'));
    }
    return _runAdb(spec, ['shell', 'wm density $dpi']);
  }

  @override
  Future<void> setResolution(SessionSpec spec, int width, int height) {
    if (width < 1 || height < 1) {
      return Future.error(ArgumentError('Width and height must be positive.'));
    }
    return _runAdb(spec, ['shell', 'wm size ${width}x$height']);
  }

  @override
  Future<void> screenOff(SessionSpec spec) =>
      _runAdb(spec, ['shell', 'input keyevent 26']);

  Future<void> _runAdb(SessionSpec spec, List<String> command) async {
    final executable = await _findTool('adb');
    final arguments = <String>[
      if (spec.serial != null && spec.serial!.isNotEmpty) ...[
        '-s',
        spec.serial!,
      ],
      ...command,
    ];
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
        '${result.stdout}${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }
}

class ShellDeviceToolsGateway implements DeviceToolsGateway {
  ShellDeviceToolsGateway(this._gateway);

  final DeviceGateway _gateway;

  @override
  Future<void> setWirelessDebugging(SessionSpec spec, bool enabled) =>
      Future.error(
        UnsupportedError(
          'Wireless ADB toggling is available on desktop builds only.',
        ),
      );

  @override
  Future<void> screenshot(SessionSpec spec, String destination) =>
      Future.error(
        UnsupportedError(
          'Screenshots are available on desktop builds only.',
        ),
      );

  @override
  Future<void> advancedReboot(SessionSpec spec, String mode) =>
      _runShell(spec, 'reboot ${mode == 'system' ? '' : mode}'.trim());

  @override
  Future<void> setDpi(SessionSpec spec, int dpi) =>
      _runShell(spec, 'wm density $dpi');

  @override
  Future<void> setResolution(SessionSpec spec, int width, int height) =>
      _runShell(spec, 'wm size ${width}x$height');

  @override
  Future<void> screenOff(SessionSpec spec) =>
      _runShell(spec, 'input keyevent 26');

  Future<void> _runShell(SessionSpec spec, String command) async {
    final exitCode = await _gateway.execOnce(spec, command);
    if (exitCode != 0) {
      throw ProcessException('shell', [command], 'Command failed.', exitCode);
    }
  }
}

class UnsupportedFastbootGateway implements FastbootGateway {
  @override
  Future<List<String>> devices() async => const [];

  @override
  Future<void> flash(
    String partition,
    String image,
    ProgressSink onProgress, {
    String? serial,
  }) =>
      Future.error(
        UnsupportedError(
          'Fastboot flashing is available on desktop builds only.',
        ),
      );

  @override
  Future<void> reboot(String mode, {String? serial}) => Future.error(
    UnsupportedError(
      'Fastboot reboot is available on desktop builds only.',
    ),
  );
}

class UnsupportedSideloadGateway implements SideloadGateway {
  @override
  Future<void> sideload(
    String file,
    ProgressSink onProgress, {
    String? serial,
  }) =>
      Future.error(
        UnsupportedError(
          'Sideload is available on desktop builds only.',
        ),
      );
}

Future<String> _findTool(String toolName) async {
  final executableName = Platform.isWindows ? '$toolName.exe' : toolName;
  final preferences = await SharedPreferences.getInstance();
  final configured = preferences.getString('platformToolsPath')?.trim();
  final candidates = <String>[];

  if (configured != null && configured.isNotEmpty) {
    if (await FileSystemEntity.type(configured) == FileSystemEntityType.file) {
      if (configured.toLowerCase().endsWith(executableName.toLowerCase())) {
        candidates.add(configured);
      }
    } else {
      candidates.addAll([
        _join(configured, executableName),
        _join(_join(configured, 'platform-tools'), executableName),
        _join(_join(configured, _platformToolsSourceName), executableName),
      ]);
    }
  }

  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  for (final root in <String>{executableDirectory, Directory.current.path}) {
    candidates.addAll([
      _join(_join(root, 'platform-tools'), executableName),
      _join(_join(root, _platformToolsSourceName), executableName),
      _join(
        _join(_join(root, 'adb_sdk'), _platformToolsSourceName),
        executableName,
      ),
    ]);
  }

  for (final candidate in candidates) {
    if (FileSystemEntity.typeSync(candidate) == FileSystemEntityType.file) {
      return candidate;
    }
  }
  return executableName;
}

String get _platformToolsSourceName => switch (Platform.operatingSystem) {
  'windows' => 'platform-tools-windows',
  'macos' => 'platform-tools-darwin',
  _ => 'platform-tools-linux',
};

String _join(String first, String second) =>
    '$first${Platform.pathSeparator}$second';

String _combinedOutput(ProcessResult result) =>
    '${result.stdout}${result.stderr}'.trim();
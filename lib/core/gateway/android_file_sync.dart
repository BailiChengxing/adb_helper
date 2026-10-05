import 'dart:async';

import 'package:adb_helper/core/model/device.dart';
import 'package:flutter/services.dart';

class AndroidFileSync implements FileSync {
  AndroidFileSync(this._commands, this._spec);

  final MethodChannel _commands;
  final SessionSpec _spec;

  @override
  FileSync forSession(SessionSpec spec) => AndroidFileSync(_commands, spec);

  @override
  Future<List<FileEntry>> list(String path) async {
    final values = await _commands
        .invokeListMethod<Object?>(
          'listFiles',
          {..._sessionArguments, 'path': path},
        )
        .timeout(const Duration(seconds: 45));
    return (values ?? const [])
        .map((value) {
          final entry = Map<Object?, Object?>.from(value! as Map);
          return FileEntry(
            name: entry['name']! as String,
            path: entry['path']! as String,
            isDirectory: entry['isDirectory']! as bool,
            size: entry['size']! as int,
            mode: entry['mode']! as String,
            mtime: entry['mtime']! as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> push(
    String documentUri,
    String remote,
    ProgressSink onProgress,
  ) async {
    onProgress(0, 'Uploading');
    await _commands.invokeMethod<void>('pushFile', {
      ..._sessionArguments,
      'uri': documentUri,
      'path': remote,
    });
    onProgress(1, 'Upload complete');
  }

  @override
  Future<void> pull(
    String remote,
    String documentUri,
    ProgressSink onProgress,
  ) async {
    onProgress(0, 'Downloading');
    await _commands.invokeMethod<void>('pullFile', {
      ..._sessionArguments,
      'uri': documentUri,
      'path': remote,
    });
    onProgress(1, 'Download complete');
  }

  @override
  Future<void> delete(String path) async {
    await _invoke('deleteFile', {'path': path});
  }

  @override
  Future<void> mkdir(String path) async {
    await _invoke('createDirectory', {'path': path});
  }

  @override
  Future<void> rename(String from, String to) async {
    await _invoke('renameFile', {'from': from, 'to': to});
  }

  @override
  Future<FileStat> stat(String path) async {
    final value = await _commands.invokeMapMethod<Object?, Object?>(
      'statFile',
      {..._sessionArguments, 'path': path},
    );
    if (value == null) {
      throw PlatformException(code: 'FILE_NOT_FOUND', message: path);
    }
    return FileStat(
      size: value['size']! as int,
      mode: value['mode']! as String,
      mtime: value['mtime']! as String,
    );
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    await _commands.invokeMethod<void>(method, {
      ..._sessionArguments,
      ...arguments,
    });
  }

  Map<String, Object?> get _sessionArguments => {
    'transport': _spec.transport.name,
    'serial': _spec.serial,
    'host': _spec.host,
    'port': _spec.port,
    'workingDir': _spec.workingDir,
  };
}

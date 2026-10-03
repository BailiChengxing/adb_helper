enum Transport { local, shizuku, root, wireless, otg }
enum ShellStream { stdout, stderr, exit }

typedef ProgressSink = void Function(double progress, String message);

class DeviceRef {
  const DeviceRef({
    required this.id,
    required this.label,
    required this.transport,
  });

  final String id;
  final String label;
  final Transport transport;
}

class SessionSpec {
  const SessionSpec({
    required this.transport,
    this.serial,
    this.host,
    this.port,
    this.workingDir,
  });

  final Transport transport;
  final String? serial;
  final String? host;
  final int? port;
  final String? workingDir;
}

class PairSpec {
  const PairSpec({
    required this.host,
    required this.port,
    required this.code,
  });

  final String host;
  final int port;
  final String code;
}

class PairingResult {
  const PairingResult({
    required this.ok,
    this.message,
    this.serial,
  });

  final bool ok;
  final String? message;
  final String? serial;
}

abstract interface class DeviceGateway {
  Future<List<DeviceRef>> discover();
  Future<PairingResult> pair(PairSpec spec);
  Future<ShellSession> open(SessionSpec spec);
  Future<int> execOnce(SessionSpec spec, String command);
}

abstract interface class ShellSession {
  Stream<ShellEvent> get events;
  Future<void> write(String data);
  Future<void> close();
}

class ShellEvent {
  const ShellEvent({
    required this.sessionId,
    required this.stream,
    required this.data,
    this.exitCode,
  });

  final String sessionId;
  final ShellStream stream;
  final String data;
  final int? exitCode;
}

class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.mode,
    required this.mtime,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final String mode;
  final String mtime;
}

class FileStat {
  const FileStat({
    required this.size,
    required this.mode,
    required this.mtime,
  });

  final int size;
  final String mode;
  final String mtime;
}

abstract interface class FileSync {
  Future<List<FileEntry>> list(String path);
  Future<void> push(String local, String remote, ProgressSink onProgress);
  Future<void> pull(String remote, String local, ProgressSink onProgress);
  Future<void> delete(String path);
  Future<void> mkdir(String path);
  Future<void> rename(String from, String to);
  Future<FileStat> stat(String path);
}

abstract interface class FastbootGateway {
  Future<List<String>> devices();
  Future<void> flash(String partition, String image, ProgressSink p);
  Future<void> reboot(String mode);
}

abstract interface class SideloadGateway {
  Future<void> sideload(String file, ProgressSink p);
}

class SessionState {
  const SessionState({
    required this.id,
    required this.spec,
    this.status = 'ready',
    this.exitCode,
    this.output = '',
  });

  final String id;
  final SessionSpec spec;
  final String status;
  final int? exitCode;
  final String output;

  SessionState copyWith({
    String? id,
    SessionSpec? spec,
    String? status,
    int? exitCode,
    String? output,
  }) {
    return SessionState(
      id: id ?? this.id,
      spec: spec ?? this.spec,
      status: status ?? this.status,
      exitCode: exitCode ?? this.exitCode,
      output: output ?? this.output,
    );
  }
}

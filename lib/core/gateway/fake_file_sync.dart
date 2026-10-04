import 'package:adb_helper/core/model/device.dart';

class FakeFileSync implements FileSync {
  final Map<String, List<FileEntry>> _directories = {
    '/': [
      _directory('storage', '/storage'),
      _directory('system', '/system'),
      _directory('data', '/data'),
    ],
    '/storage': [
      _directory('emulated', '/storage/emulated'),
    ],
    '/storage/emulated': [
      _directory('0', '/storage/emulated/0'),
    ],
    '/storage/emulated/0': [
      _directory('Download', '/storage/emulated/0/Download'),
      _directory('Pictures', '/storage/emulated/0/Pictures'),
      _directory('Android', '/storage/emulated/0/Android'),
      _file('readme.txt', '/storage/emulated/0/readme.txt', 128),
    ],
    '/storage/emulated/0/Download': [],
    '/storage/emulated/0/Pictures': [],
    '/storage/emulated/0/Android': [
      _directory('media', '/storage/emulated/0/Android/media'),
      _directory('data', '/storage/emulated/0/Android/data'),
    ],
    '/storage/emulated/0/Android/media': [],
    '/storage/emulated/0/Android/data': [],
    '/system': [],
    '/data': [],
  };

  @override
  FileSync forSession(SessionSpec spec) => this;

  static FileEntry _directory(String name, String path) => FileEntry(
    name: name,
    path: path,
    isDirectory: true,
    size: 0,
    mode: 'drwxr-xr-x',
    mtime: '2026-10-03 12:00',
  );

  static FileEntry _file(String name, String path, int size) => FileEntry(
    name: name,
    path: path,
    isDirectory: false,
    size: size,
    mode: '-rw-r--r--',
    mtime: '2026-10-03 12:00',
  );

  @override
  Future<List<FileEntry>> list(String path) async {
    return List.unmodifiable(_directories[_normalize(path)] ?? const []);
  }

  @override
  Future<void> push(
    String documentUri,
    String remote,
    ProgressSink onProgress,
  ) async {
    onProgress(0.5, 'Uploading $documentUri');
    final normalized = _normalize(remote);
    final parent = _parent(normalized);
    _directories.putIfAbsent(parent, () => []).add(_file(_name(normalized), normalized, 4096));
    onProgress(1, 'Upload complete');
  }

  @override
  Future<void> pull(
    String remote,
    String documentUri,
    ProgressSink onProgress,
  ) async {
    onProgress(0.5, 'Downloading $remote');
    onProgress(1, 'Saved to $documentUri');
  }

  @override
  Future<void> delete(String path) async {
    final normalized = _normalize(path);
    _directories[_parent(normalized)]?.removeWhere((entry) => entry.path == normalized);
    _directories.remove(normalized);
  }

  @override
  Future<void> mkdir(String path) async {
    final normalized = _normalize(path);
    _directories.putIfAbsent(_parent(normalized), () => []).add(_directory(_name(normalized), normalized));
    _directories.putIfAbsent(normalized, () => []);
  }

  @override
  Future<void> rename(String from, String to) async {
    final source = _normalize(from);
    final destination = _normalize(to);
    final entries = _directories[_parent(source)];
    final index = entries?.indexWhere((entry) => entry.path == source) ?? -1;
    if (entries == null || index < 0) return;
    final entry = entries.removeAt(index);
    final renamed = FileEntry(
      name: _name(destination),
      path: destination,
      isDirectory: entry.isDirectory,
      size: entry.size,
      mode: entry.mode,
      mtime: entry.mtime,
    );
    _directories.putIfAbsent(_parent(destination), () => []).add(renamed);
    if (entry.isDirectory) {
      _directories[destination] = _directories.remove(source) ?? [];
    }
  }

  @override
  Future<FileStat> stat(String path) async {
    final normalized = _normalize(path);
    final parentEntries = _directories[_parent(normalized)] ?? const [];
    final entry = parentEntries.where((item) => item.path == normalized).firstOrNull;
    if (entry == null) throw StateError('File not found: $normalized');
    return FileStat(size: entry.size, mode: entry.mode, mtime: entry.mtime);
  }

  static String _normalize(String path) {
    final segments = path.split('/').where((segment) => segment.isNotEmpty);
    return '/${segments.join('/')}';
  }

  static String _parent(String path) {
    final separator = path.lastIndexOf('/');
    return separator <= 0 ? '/' : path.substring(0, separator);
  }

  static String _name(String path) => path.substring(path.lastIndexOf('/') + 1);
}

import 'package:adb_helper/core/gateway/fake_file_sync.dart';
import 'package:adb_helper/core/model/device.dart';
import 'package:adb_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fileSyncProvider = Provider<FileSync>((ref) => FakeFileSync());
final filesProvider = FutureProvider.family<List<FileEntry>, String>((ref, path) {
  return ref.watch(fileSyncProvider).list(path);
});

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  String _path = '/';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entriesAsync = ref.watch(filesProvider(_path));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.files),
        leading: _path == '/'
            ? null
            : IconButton(
                tooltip: l10n.filesRoot,
                onPressed: () => setState(() => _path = _parent(_path)),
                icon: const Icon(Icons.arrow_back),
              ),
        actions: [
          IconButton(
            tooltip: l10n.newFolder,
            onPressed: _createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: _runTransfer,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'push', child: Text(l10n.pushDemoFile)),
              PopupMenuItem(value: 'pull', child: Text(l10n.pullDemoFile)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(_path == '/' ? l10n.filesRoot : _path),
              ),
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) return Center(child: Text(l10n.emptyFolder));
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      leading: Icon(entry.isDirectory ? Icons.folder : Icons.description_outlined),
                      title: Text(entry.name),
                      subtitle: Text(entry.isDirectory ? entry.mode : '${entry.size} B · ${entry.mode}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _operate(action, entry),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                        ],
                      ),
                      onTap: entry.isDirectory ? () => setState(() => _path = entry.path) : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('$error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await _askName(l10n.newFolder, l10n.folderName);
    if (name == null || name.isEmpty) return;
    await ref.read(fileSyncProvider).mkdir(_join(_path, name));
    ref.invalidate(filesProvider(_path));
  }

  Future<void> _operate(String action, FileEntry entry) async {
    final l10n = AppLocalizations.of(context);
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.confirmDelete(entry.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(fileSyncProvider).delete(entry.path);
    } else {
      final name = await _askName(l10n.rename, l10n.renameTo, initialValue: entry.name);
      if (name == null || name.isEmpty || name == entry.name) return;
      await ref.read(fileSyncProvider).rename(entry.path, _join(_path, name));
    }
    ref.invalidate(filesProvider(_path));
  }

  Future<void> _runTransfer(String action) async {
    final gateway = ref.read(fileSyncProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'push') {
      await gateway.push('demo.txt', _join(_path, 'demo.txt'), (progress, message) {});
    } else {
      final entries = await gateway.list(_path);
      final file = entries.where((entry) => !entry.isDirectory).firstOrNull;
      if (file == null) return;
      await gateway.pull(file.path, 'downloads/${file.name}', (progress, message) {});
    }
    ref.invalidate(filesProvider(_path));
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(action == 'push' ? l10n.uploadComplete : l10n.downloadComplete)),
      );
    }
  }

  Future<String?> _askName(String title, String label, {String initialValue = ''}) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(title),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  static String _join(String parent, String name) => parent == '/' ? '/$name' : '$parent/$name';

  static String _parent(String path) {
    final index = path.lastIndexOf('/');
    return index <= 0 ? '/' : path.substring(0, index);
  }
}

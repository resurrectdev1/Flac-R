import 'dart:convert';
import 'dart:io';

enum RenameOutcome { renamed, unchanged, targetExists, invalidName, failed }

class RenameResult {
  const RenameResult(this.outcome, this.path);
  final RenameOutcome outcome;

  final String path;
}

class FileRenamer {
  static final _illegalChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

  static String? sanitizeBaseName(String title, {required int maxBytes}) {
    var name = title
        .replaceAll(_illegalChars, '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    name = name
        .replaceAll(RegExp(r'^\.+'), '')
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (name.isEmpty) return null;

    while (utf8.encode(name).length > maxBytes && name.isNotEmpty) {
      name = name.substring(0, name.length - 1);
    }
    name = name.trim();
    return name.isEmpty ? null : name;
  }

  static Future<RenameResult> renameToTitle(String path, String title) async {
    final sep = path.lastIndexOf('/');
    if (sep < 0) return RenameResult(RenameOutcome.failed, path);
    final dir = path.substring(0, sep);
    final fileName = path.substring(sep + 1);
    final dot = fileName.lastIndexOf('.');
    final ext = dot > 0 ? fileName.substring(dot) : '';

    final base = sanitizeBaseName(
      title,
      maxBytes: 240 - utf8.encode(ext).length,
    );
    if (base == null) return RenameResult(RenameOutcome.invalidName, path);

    final newPath = '$dir/$base$ext';
    if (newPath == path) return RenameResult(RenameOutcome.unchanged, path);

    try {
      if (await FileSystemEntity.type(newPath) !=
          FileSystemEntityType.notFound) {
        return RenameResult(RenameOutcome.targetExists, path);
      }
      await File(path).rename(newPath);
      return RenameResult(RenameOutcome.renamed, newPath);
    } catch (_) {
      return RenameResult(RenameOutcome.failed, path);
    }
  }
}

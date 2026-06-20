import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:audiotags/audiotags.dart';
import 'audio_file.dart';
import '../extra_tags_channel.dart';
import '../widgets/artwork_cache.dart';

class ScanProgress {
  final int    scanned;
  final int    total;
  final String currentFile;
  const ScanProgress({
    required this.scanned,
    required this.total,
    required this.currentFile,
  });
}

class _ScanRequest {
  final List<String> roots;
  final SendPort     progressPort;
  const _ScanRequest(this.roots, this.progressPort);
}

void _isolateEntry(SendPort mainPort) {
  final receivePort = ReceivePort();
  mainPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    if (message is _ScanRequest) {
      try {
        final result = await AudioScanner.scan(message);
        mainPort.send(result);
      } catch (e) {
        mainPort.send(e);
      }
    }
  });
}

class AudioLibrary extends ChangeNotifier {
  List<AudioFile>  _files        = [];
  bool             _scanning     = false;
  String?          _error;
  int              _skippedCount = 0;
  ScanProgress?    _progress;

  List<AudioFile>  get files        => List.unmodifiable(_files);
  bool             get scanning     => _scanning;
  String?          get error        => _error;
  int              get skippedCount => _skippedCount;
  ScanProgress?    get progress     => _progress;

  Map<String, List<AudioFile>>? _albumCache;
  Map<String, List<AudioFile>>? _artistCache;
  Map<String, List<AudioFile>>? _folderCache;

  Map<String, List<AudioFile>> get albums  => _albumCache  ??= _buildGroup((f) => f.album);
  Map<String, List<AudioFile>> get artists => _artistCache ??= _buildGroup((f) => f.artist);
  Map<String, List<AudioFile>> get folders => _folderCache ??= _buildGroup(
    (f) => f.path.substring(0, f.path.lastIndexOf('/')),
  );

  Map<String, List<AudioFile>> _buildGroup(String Function(AudioFile) key) {
    final map = <String, List<AudioFile>>{};
    for (final f in _files) {
      map.putIfAbsent(key(f), () => []).add(f);
    }
    return map;
  }

  Future<void> scan({List<String> roots = const []}) async {
    if (_scanning) return;
    _scanning = true;
    _error    = null;
    _progress = null;
    ArtworkCache.instance.clear();
    notifyListeners();

    try {
      final mainReceive = ReceivePort();
      final isolate     = await Isolate.spawn(_isolateEntry, mainReceive.sendPort);

      SendPort? isolateSend;
      ScanResult? result;

      await for (final msg in mainReceive) {
        if (msg is SendPort) {
          isolateSend = msg;
          isolateSend.send(_ScanRequest(roots, mainReceive.sendPort));
        } else if (msg is ScanProgress) {
          _progress = msg;
          notifyListeners();
        } else if (msg is ScanResult) {
          result = msg;
          break;
        } else if (msg is Exception || msg is Error) {
          throw msg;
        }
      }

      mainReceive.close();
      isolate.kill(priority: Isolate.immediate);

      _files        = result?.files        ?? [];
      _skippedCount = result?.skipped      ?? 0;
      _progress     = null;
      _invalidateCaches();
      notifyListeners();

      await _loadExtraTags();
    } catch (e) {
      _error    = e.toString();
      _progress = null;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<void> _loadExtraTags() async {
    final pathsNeeded = _files
    .where((f) => f.composer == null || f.comment == null)
    .map((f) => f.path)
    .toList();
    if (pathsNeeded.isEmpty) return;

    Map<String, ({String? composer, String? comment})> results;
    try {
      results = await ExtraTags.readBatch(pathsNeeded);
    } catch (e) {
      debugPrint('ExtraTags.readBatch failed: $e');
      return;
    }

    bool anyChanged = false;
    for (int i = 0; i < _files.length; i++) {
      final f     = _files[i];
      final extra = results[f.path];
      if (extra == null) continue;
      if (extra.composer == f.composer && extra.comment == f.comment) continue;
      _files[i] = f.copyWith(
        composer:      extra.composer,
        clearComposer: extra.composer == null,
        comment:       extra.comment,
        clearComment:  extra.comment == null,
      );
      anyChanged = true;
    }
    if (anyChanged) {
      _invalidateCaches();
      notifyListeners();
    }
  }

  void updateFile(AudioFile updated) {
    final idx = _files.indexWhere((f) => f.path == updated.path);
    if (idx == -1) return;
    _files = List.of(_files)..[idx] = updated;
    _invalidateCaches();
    notifyListeners();
  }

  void _invalidateCaches() {
    _albumCache  = null;
    _artistCache = null;
    _folderCache = null;
  }
}

class ScanResult {
  final List<AudioFile> files;
  final int             skipped;
  const ScanResult({required this.files, required this.skipped});
}

class AudioScanner {
  static const _supportedExts = {'.mp3', '.flac', '.m4a', '.aac', '.ogg'};

  static Future<ScanResult> scan(_ScanRequest request) async {
    final roots   = request.roots;
    final port    = request.progressPort;
    final results = <AudioFile>[];
    int   skipped = 0;

    final allFiles = <File>[];
    for (final root in roots.map((p) => Directory(p))) {
      if (!await root.exists()) continue;
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (!_supportedExts.any((ext) => lower.endsWith(ext))) continue;
        allFiles.add(entity);
      }
    }

    final total = allFiles.length;

    const concurrency = 6;
    int completed = 0;

    for (int start = 0; start < allFiles.length; start += concurrency) {
      final batch = allFiles.skip(start).take(concurrency).toList();
      final batchResults = await Future.wait(batch.map((entity) async {
        final result = await _readOne(entity);
        completed++;
        port.send(ScanProgress(
          scanned:     completed,
          total:       total,
          currentFile: entity.path.split('/').last,
        ));
        return result;
      }));

      for (final r in batchResults) {
        if (r != null) {
          results.add(r);
        } else {
          skipped++;
        }
      }
    }

    if (skipped > 0) debugPrint('AudioScanner: skipped $skipped unreadable file(s)');
    return ScanResult(files: results, skipped: skipped);
  }

  static Future<AudioFile?> _readOne(File entity) async {
    final lower = entity.path.toLowerCase();
    try {
      final tag        = await AudioTags.read(entity.path);
      final hasArtwork = tag?.pictures != null && tag!.pictures.isNotEmpty;

      final trackNumber = tag?.trackNumber ?? await _fallbackTrackNumber(entity.path, lower);
      final discNumber  = _parseSlashInt(tag?.discNumber?.toString()) ?? tag?.discNumber;
      final yearRaw     = tag?.year?.toString().trim() ?? '';
      final yearString  = yearRaw.isNotEmpty ? yearRaw : null;

      return AudioFile(
        path:        entity.path,
        title:       tag?.title?.isNotEmpty == true ? tag!.title! : entity.uri.pathSegments.last,
        artist:      tag?.trackArtist?.isNotEmpty == true ? tag!.trackArtist! : 'Unknown Artist',
        album:       tag?.album?.isNotEmpty == true ? tag!.album! : 'Unknown Album',
        genre:       tag?.genre,
        year:        yearString,
        trackNumber: trackNumber,
        hasArtwork:  hasArtwork,
        albumArtist: tag?.albumArtist,
        lyrics:      tag?.lyrics,
        discNumber:  discNumber,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _parseSlashInt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw.split('/').first.trim());
  }

  static Future<int?> _fallbackTrackNumber(String path, String lowerPath) async {
    const mp3Cap  = 2 * 1024 * 1024;
    const flacCap = 4 * 1024 * 1024;

    try {
      final file    = File(path);
      final length  = await file.length();
      final cap     = lowerPath.endsWith('.flac') ? flacCap : mp3Cap;
      final readLen = length < cap ? length : cap;

      final raf = await file.open();
      try {
        final bytes = await raf.read(readLen);
        if (lowerPath.endsWith('.mp3'))  return _id3TrackNumber(bytes);
        if (lowerPath.endsWith('.flac')) return _vorbisTrackNumber(bytes);
      } finally {
        await raf.close();
      }
    } catch (_) {}
    return null;
  }

  static int? _id3TrackNumber(Uint8List bytes) {
    if (bytes.length < 10) return null;
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return null;
    final tagSize = ((bytes[6] & 0x7F) << 21) |
    ((bytes[7] & 0x7F) << 14) |
    ((bytes[8] & 0x7F) <<  7) |
    (bytes[9] & 0x7F);
    int pos     = 10;
    final end   = (pos + tagSize).clamp(0, bytes.length);
    final isV24 = bytes[3] >= 4;
    while (pos + 10 <= end) {
      final frameId   = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final frameSize = isV24
      ? ((bytes[pos+4] & 0x7F) << 21 | (bytes[pos+5] & 0x7F) << 14 |
      (bytes[pos+6] & 0x7F) <<  7 |  (bytes[pos+7] & 0x7F))
      : (bytes[pos+4] << 24 | bytes[pos+5] << 16 |
      bytes[pos+6] <<  8 |  bytes[pos+7]);
      if (frameSize < 0 || frameSize > bytes.length) break;
      if (frameSize == 0) { pos += 10; continue; }
      if (frameId == 'TRCK' && pos + 10 + frameSize <= end) {
        final raw = utf8.decode(
          bytes.sublist(pos + 11, pos + 10 + frameSize),
          allowMalformed: true,
        ).trim();
        final n = int.tryParse(raw.split('/').first.trim());
        if (n != null) return n;
      }
      pos += 10 + frameSize;
    }
    return null;
  }

  static int? _vorbisTrackNumber(Uint8List bytes) {
    if (bytes.length < 4) return null;
    if (bytes[0] != 0x66 || bytes[1] != 0x4C || bytes[2] != 0x61 || bytes[3] != 0x43) return null;
    int pos = 4;
    while (pos + 4 <= bytes.length) {
      final blockType = bytes[pos] & 0x7F;
      final isLast    = (bytes[pos] & 0x80) != 0;
      final blockLen  = (bytes[pos+1] << 16) | (bytes[pos+2] << 8) | bytes[pos+3];
      pos += 4;
      if (blockType == 4 && pos + blockLen <= bytes.length) {
        final block = bytes.sublist(pos, pos + blockLen);
        int bp = 0;
        if (bp + 4 > block.length) break;
        final vendorLen = block[bp] | (block[bp+1]<<8) | (block[bp+2]<<16) | (block[bp+3]<<24);
        bp += 4 + vendorLen;
        if (bp + 4 > block.length) break;
        final commentCount = block[bp] | (block[bp+1]<<8) | (block[bp+2]<<16) | (block[bp+3]<<24);
        bp += 4;
        for (int i = 0; i < commentCount; i++) {
          if (bp + 4 > block.length) break;
          final len = block[bp] | (block[bp+1]<<8) | (block[bp+2]<<16) | (block[bp+3]<<24);
          bp += 4;
          if (bp + len > block.length) break;
          final comment = utf8.decode(block.sublist(bp, bp + len), allowMalformed: true);
          bp += len;
          final upper = comment.toUpperCase();
          if (upper.startsWith('TRACKNUMBER=')) {
            final val = comment.substring('TRACKNUMBER='.length).split('/').first.trim();
            final n   = int.tryParse(val);
            if (n != null) return n;
          }
        }
      }
      pos += blockLen;
      if (isLast) break;
    }
    return null;
  }
}

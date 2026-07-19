import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';

class ArtworkCache {
  ArtworkCache._();
  static final instance = ArtworkCache._();

  static const maxEntries = 60;

  final _cache = <String, Uint8List?>{};
  final _accessLog = <String>[];

  Future<Uint8List?> get(String path) async {
    if (_cache.containsKey(path)) {
      _touch(path);
      return _cache[path];
    }
    final bytes = await compute(_loadArtwork, path);
    _put(path, bytes);
    return bytes;
  }

  void invalidate(String path) {
    _cache.remove(path);
    _accessLog.remove(path);
  }

  void clear() {
    _cache.clear();
    _accessLog.clear();
  }

  void _touch(String path) {
    _accessLog.remove(path);
    _accessLog.add(path);
  }

  void _put(String path, Uint8List? bytes) {
    if (_cache.length >= maxEntries && _accessLog.isNotEmpty) {
      final lru = _accessLog.removeAt(0);
      _cache.remove(lru);
    }
    _cache[path] = bytes;
    _accessLog.add(path);
  }

  static Future<Uint8List?> _loadArtwork(String path) async {
    try {
      final tag = await AudioTags.read(path);
      if (tag?.pictures != null && tag!.pictures.isNotEmpty) {
        return tag.pictures.first.bytes;
      }
    } catch (_) {}
    return null;
  }
}

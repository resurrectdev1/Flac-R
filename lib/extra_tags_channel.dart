import 'package:flutter/services.dart';

class ExtraTags {
  static const _channel = MethodChannel('com.resurrect.flac_r/extra_tags');

  static bool isJaudiotaggerFormat(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.m4a') ||
    lower.endsWith('.ogg');
  }

  static bool isOggFormat(String path) => path.toLowerCase().endsWith('.ogg');

  static Future<({String? composer, String? comment})> read(String path) async {
    final Map result = await _channel.invokeMethod('readExtraTags', {'path': path});
    return (
      composer: result['composer'] as String?,
      comment:  result['comment']  as String?,
    );
  }

  static Future<Map<String, ({String? composer, String? comment})>> readBatch(
    List<String> paths,
  ) async {
    if (paths.isEmpty) return {};
    final Map result = await _channel.invokeMethod('readExtraTagsBatch', {'paths': paths});
    final out = <String, ({String? composer, String? comment})>{};
    result.forEach((key, value) {
      final m = value as Map;
      out[key as String] = (
        composer: m['composer'] as String?,
        comment:  m['comment']  as String?,
      );
    });
    return out;
  }

  static Future<void> write(
    String path, {
      String? composer,
      String? comment,
    }) async {
      await _channel.invokeMethod('writeExtraTags', {
        'path': path,
        if (composer != null) 'composer': composer,
          if (comment  != null) 'comment':  comment,
      });
    }

    static Future<void> writeAllTags(
      String path, {
        String?    title,
        String?    artist,
        String?    album,
        int?       year,
        String?    genre,
        int?       trackNumber,
        int?       discNumber,
        String?    albumArtist,
        String?    lyrics,
        String?    composer,
        String?    comment,
        List<int>? artworkBytes,
      }) async {
        await _channel.invokeMethod('writeAllTags', {
          'path': path,
          if (title       != null) 'title':       title,
            if (artist      != null) 'artist':      artist,
              if (album       != null) 'album':       album,
                if (year        != null) 'year':        year,
                  if (genre       != null) 'genre':       genre,
                    if (trackNumber != null) 'trackNumber': trackNumber,
                      if (discNumber  != null) 'discNumber':  discNumber,
                        if (albumArtist != null) 'albumArtist': albumArtist,
                          if (lyrics      != null) 'lyrics':      lyrics,
                            if (composer    != null) 'composer':    composer,
                              if (comment     != null) 'comment':     comment,
                                if (artworkBytes != null) 'artworkBytes': artworkBytes,
        });
      }
}

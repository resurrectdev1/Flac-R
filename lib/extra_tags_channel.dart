import 'package:flutter/services.dart';

class ExtraTags {
  static const _channel = MethodChannel('com.resurrect.flac_r/extra_tags');

  static bool isJaudiotaggerFormat(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.m4a') ||
    lower.endsWith('.mp4') ||
    lower.endsWith('.aac') ||
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

import 'package:flutter/services.dart';

class ExtraTags {
  static const _channel = MethodChannel('com.resurrect.flac_r/extra_tags');
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
}

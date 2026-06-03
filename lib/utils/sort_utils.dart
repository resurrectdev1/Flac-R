import '../models/audio_file.dart';

enum SortField { title, artist, album, year }
enum SortOrder { asc, desc }

extension SortLabel on SortField {
  String get label {
    switch (this) {
      case SortField.title:  return 'Title';
      case SortField.artist: return 'Artist';
      case SortField.album:  return 'Album';
      case SortField.year:   return 'Year';
    }
  }
}

List<AudioFile> sortFiles(
  List<AudioFile> files, {
    required SortField field,
    required SortOrder order,
    String             query = '',
  }) {
  List<AudioFile> filtered;
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    filtered = files.where((f) =>
    f.title.toLowerCase().contains(q)  ||
    f.artist.toLowerCase().contains(q) ||
    f.album.toLowerCase().contains(q)
    ).toList();
  } else {
    filtered = List.of(files);
  }

  filtered.sort((a, b) {
    int cmp;
    switch (field) {
      case SortField.title:  cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());   break;
      case SortField.artist: cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase()); break;
      case SortField.album:  cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());   break;
      case SortField.year:
        final ay = int.tryParse(a.year ?? '') ?? 0;
        final by = int.tryParse(b.year ?? '') ?? 0;
        cmp = ay.compareTo(by);
        break;
    }
    return order == SortOrder.asc ? cmp : -cmp;
  });

  return filtered;
  }

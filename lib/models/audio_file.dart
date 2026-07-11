
class AudioFile {
  final String     path;
  final String     title;
  final String     artist;
  final String     album;
  final String?    genre;
  final String?    year;
  final int?       trackNumber;
  final String?    albumArtist;
  final String?    lyrics;
  final int?       discNumber;
  final String?    composer;
  final String?    comment;

  final bool hasArtwork;

  const AudioFile({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.albumArtist,
    this.lyrics,
    this.discNumber,
    this.composer,
    this.comment,
    this.hasArtwork = false,
  });

  AudioFile copyWith({
    String?     title,
    String?     artist,
    String?     album,
    String?     genre,
    String?     year,
    bool        clearYear        = false,
    int?        trackNumber,
    bool        clearTrackNumber = false,
    bool?       hasArtwork,
    bool        clearArtwork     = false,
    String?     albumArtist,
    String?     lyrics,
    int?        discNumber,
    bool        clearDiscNumber  = false,
    String?     composer,
    bool        clearComposer    = false,
    String?     comment,
    bool        clearComment     = false,
  }) {
    return AudioFile(
      path:         path,
      title:        title        ?? this.title,
      artist:       artist       ?? this.artist,
      album:        album        ?? this.album,
      genre:        genre        ?? this.genre,
      year:         clearYear        ? null : (year        ?? this.year),
      trackNumber:  clearTrackNumber ? null : (trackNumber ?? this.trackNumber),
      hasArtwork:   clearArtwork     ? false : (hasArtwork ?? this.hasArtwork),
      albumArtist:  albumArtist  ?? this.albumArtist,
      lyrics:       lyrics       ?? this.lyrics,
      discNumber:   clearDiscNumber  ? null : (discNumber  ?? this.discNumber),
      composer:     clearComposer    ? null : (composer    ?? this.composer),
      comment:      clearComment     ? null : (comment     ?? this.comment),
    );
  }
}

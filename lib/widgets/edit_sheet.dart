import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiotags/audiotags.dart';
import 'package:image_picker/image_picker.dart';

import '../models/audio_file.dart';
import '../models/audio_library.dart';
import '../theme/flacr_theme.dart';
import '../extra_tags_channel.dart';
import 'shared_widgets.dart';
import 'artwork_cache.dart';

class EditSheet extends StatefulWidget {
  const EditSheet({super.key, required this.file, required this.theme});
  final AudioFile  file;
  final FlacRTheme theme;

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _genreCtrl;
  late final TextEditingController _trackCtrl;
  late final TextEditingController _discCtrl;
  late final TextEditingController _albumArtistCtrl;
  late final TextEditingController _lyricsCtrl;
  late final TextEditingController _composerCtrl;
  late final TextEditingController _commentCtrl;

  Uint8List? _pendingArtwork;
  bool       _artworkChanged = false;
  bool       _saving         = false;
  String?    _yearError;
  String?    _trackError;
  String?    _discError;

  @override
  void initState() {
    super.initState();
    final f          = widget.file;
    _titleCtrl       = TextEditingController(text: f.title);
    _artistCtrl      = TextEditingController(text: f.artist);
    _albumCtrl       = TextEditingController(text: f.album);
    _yearCtrl        = TextEditingController(text: f.year ?? '');
    _genreCtrl       = TextEditingController(text: f.genre ?? '');
    _trackCtrl       = TextEditingController(text: f.trackNumber?.toString() ?? '');
    _discCtrl        = TextEditingController(text: f.discNumber?.toString() ?? '');
    _albumArtistCtrl = TextEditingController(text: f.albumArtist ?? '');
    _lyricsCtrl      = TextEditingController(text: f.lyrics    ?? '');
    _composerCtrl    = TextEditingController(text: f.composer  ?? '');
    _commentCtrl     = TextEditingController(text: f.comment   ?? '');
    if (f.hasArtwork) {
      ArtworkCache.instance.get(f.path).then((bytes) {
        if (mounted) setState(() => _pendingArtwork = bytes);
      });
    }
    if (ExtraTags.isJaudiotaggerFormat(f.path)) {
      ExtraTags.read(f.path).then((extra) {
        if (!mounted) return;
        setState(() {
          if (_composerCtrl.text.isEmpty && extra.composer != null) {
            _composerCtrl.text = extra.composer!;
          }
          if (_commentCtrl.text.isEmpty && extra.comment != null) {
            _commentCtrl.text = extra.comment!;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();       _artistCtrl.dispose();
    _albumCtrl.dispose();       _yearCtrl.dispose();
    _genreCtrl.dispose();       _trackCtrl.dispose();
    _discCtrl.dispose();        _albumArtistCtrl.dispose();
    _lyricsCtrl.dispose();      _composerCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final f = widget.file;
    return _titleCtrl.text.trim()       != f.title                          ||
    _artistCtrl.text.trim()      != f.artist                         ||
    _albumCtrl.text.trim()       != f.album                          ||
    _yearCtrl.text.trim()        != (f.year                        ?? '') ||
    _genreCtrl.text.trim()       != (f.genre                   ?? '') ||
    _trackCtrl.text.trim()       != (f.trackNumber?.toString() ?? '') ||
    _discCtrl.text.trim()        != (f.discNumber?.toString()  ?? '') ||
    _albumArtistCtrl.text.trim() != (f.albumArtist             ?? '') ||
    _lyricsCtrl.text             != (f.lyrics                  ?? '') ||
    _composerCtrl.text.trim()    != (f.composer                ?? '') ||
    _commentCtrl.text.trim()     != (f.comment                 ?? '') ||
    _artworkChanged;
  }

  static final _yearRe = RegExp(r'^\d{4}(-(?:0[1-9]|1[0-2])(-(?:0[1-9]|[12]\d|3[01]))?)?$');

  void _validateYear(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) { setState(() => _yearError = null); return; }
    if (trimmed.length < 4) { setState(() => _yearError = 'Use YYYY, YYYY-MM, or YYYY-MM-DD'); return; }
    final year = int.tryParse(trimmed.substring(0, 4));
    setState(() {
      _yearError = (!_yearRe.hasMatch(trimmed) || year == null || year < 1000 || year > 2099)
      ? 'Use YYYY, YYYY-MM, or YYYY-MM-DD'
    : null;
    });
  }

  void _validateTrack(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) { setState(() => _trackError = null); return; }
    final n = int.tryParse(trimmed);
    setState(() {
      _trackError = (n == null || n < 0 || n > 999) ? 'Enter a number between 0 and 999' : null;
    });
  }

  void _validateDisc(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) { setState(() => _discError = null); return; }
    final n = int.tryParse(trimmed);
    setState(() {
      _discError = (n == null || n < 1 || n > 99) ? 'Enter a number between 1 and 99' : null;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = widget.theme;
        return AlertDialog(
          backgroundColor: theme.surfaceHigh,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          title: Text('Discard changes?',
                      style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700)),
                      content: Text('Your edits haven\'t been saved.',
                                    style: TextStyle(color: theme.textSecondary)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text('Keep editing', style: TextStyle(color: theme.textSecondary)),
                                      ),
                           TextButton(
                             onPressed: () => Navigator.pop(ctx, true),
                             child: Text('Discard',
                                         style: TextStyle(color: FlacRTheme.errorRed, fontWeight: FontWeight.w600)),
                           ),
                                    ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (_yearError != null || _trackError != null || _discError != null) return;
    final f       = widget.file;
    final theme   = widget.theme;
    final library = context.read<AudioLibrary>();

    final trackRaw      = _trackCtrl.text.trim();
    final discRaw       = _discCtrl.text.trim();
    final yearRaw       = _yearCtrl.text.trim();
    final resolvedTrack = trackRaw.isNotEmpty ? int.tryParse(trackRaw) : f.trackNumber;
    final resolvedDisc  = discRaw.isNotEmpty  ? int.tryParse(discRaw)  : f.discNumber;
    final resolvedYearInt = yearRaw.isNotEmpty
    ? int.tryParse(yearRaw.split('-').first)
    : (f.year != null ? int.tryParse(f.year!.split('-').first) : null);
    final resolvedYearStr = yearRaw.isNotEmpty ? yearRaw : f.year;

    setState(() => _saving = true);
    try {
      final artwork     = _pendingArtwork;
      final genre       = _genreCtrl.text.trim();
      final albumArt    = _albumArtistCtrl.text.trim();
      final lyrics      = _lyricsCtrl.text;
      final composerVal = _composerCtrl.text.trim();
      final commentVal  = _commentCtrl.text.trim();
      final tag = Tag(
        title:       _titleCtrl.text.trim(),
        trackArtist: _artistCtrl.text.trim(),
        album:       _albumCtrl.text.trim(),
        year:        resolvedYearInt,
        genre:       genre.isNotEmpty    ? genre    : null,
        trackNumber: resolvedTrack,
        discNumber:  resolvedDisc,
        albumArtist: albumArt.isNotEmpty ? albumArt : null,
        lyrics:      lyrics.isNotEmpty   ? lyrics   : null,
        pictures: artwork != null
        ? [Picture(bytes: artwork, mimeType: null, pictureType: PictureType.other)]
        : [],
      );
      if (ExtraTags.isJaudiotaggerFormat(f.path)) {
        if (ExtraTags.isOggFormat(f.path) && _artworkChanged) {
          await AudioTags.write(f.path, tag);
        }
        await ExtraTags.writeAllTags(
          f.path,
          title:       _titleCtrl.text.trim(),
          artist:      _artistCtrl.text.trim(),
          album:       _albumCtrl.text.trim(),
          year:        resolvedYearInt,
          genre:       genre,
          trackNumber: resolvedTrack,
          discNumber:  resolvedDisc,
          albumArtist: albumArt,
          lyrics:      lyrics,
          composer:    composerVal.isNotEmpty ? composerVal : (f.composer ?? ''),
          comment:     commentVal.isNotEmpty  ? commentVal  : (f.comment  ?? ''),
          artworkBytes: (!ExtraTags.isOggFormat(f.path) && _artworkChanged)
          ? (artwork != null ? artwork.toList() : [])
          : null,
        );
      } else {
        await AudioTags.write(f.path, tag);
        await ExtraTags.write(
          f.path,
          composer: composerVal,
          comment:  commentVal,
        );
      }
      final composerChanged = composerVal != (f.composer ?? '');
      final commentChanged  = commentVal  != (f.comment  ?? '');
      final updated = f.copyWith(
        title:        _titleCtrl.text.trim(),
        artist:       _artistCtrl.text.trim(),
        album:        _albumCtrl.text.trim(),
        year:         resolvedYearStr,
        genre:        genre.isNotEmpty    ? genre    : null,
        trackNumber:  resolvedTrack,
        hasArtwork:   artwork != null,
        clearArtwork: _artworkChanged && artwork == null,
        albumArtist:  albumArt.isNotEmpty ? albumArt : null,
        lyrics:       lyrics.isNotEmpty   ? lyrics   : null,
        discNumber:   resolvedDisc,
        composer:     composerChanged && composerVal.isNotEmpty ? composerVal : null,
        clearComposer: composerChanged && composerVal.isEmpty,
        comment:      commentChanged  && commentVal.isNotEmpty  ? commentVal  : null,
        clearComment:  commentChanged  && commentVal.isEmpty,
      );
      if (_artworkChanged) ArtworkCache.instance.invalidate(f.path);
      library.updateFile(updated);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         const Text('Tags saved'),
          backgroundColor: theme.primary,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Save failed: $e'),
          backgroundColor: FlacRTheme.errorRed,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = widget.theme;
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final kb     = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color:        theme.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navBar + kb),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHandle(theme: theme),
                const SizedBox(height: 16),
                Center(
                  child: ArtworkPicker(
                    filePath:   widget.file.path,
                    hasArtwork: widget.file.hasArtwork,
                    theme:        theme,
                    onChanged: (bytes) => setState(() {
                      _pendingArtwork = bytes;
                      _artworkChanged = true;
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Edit Tags',
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                      color: theme.textPrimary)),
                          const SizedBox(height: 4),
                          Text(widget.file.path.split('/').last,
                          style: TextStyle(fontSize: 11, color: theme.textMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 20),
                          _tagField('Title',        _titleCtrl,       theme, TextInputType.text),
                          _tagField('Artist',       _artistCtrl,      theme, TextInputType.text),
                          _tagField('Album',        _albumCtrl,       theme, TextInputType.text),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller:   _yearCtrl,
                              keyboardType: TextInputType.datetime,
                              onChanged:    _validateYear,
                              style:        TextStyle(color: theme.textPrimary, fontSize: 14),
                              decoration:   InputDecoration(
                                labelText: 'Year',
                                hintText:  'e.g. 2013 or 2013-04-12',
                                hintStyle: TextStyle(color: theme.textMuted, fontSize: 12),
                                errorText: _yearError,
                              ),
                            ),
                          ),
                          _tagField('Genre',        _genreCtrl,       theme, TextInputType.text),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller:   _trackCtrl,
                              keyboardType: TextInputType.number,
                              onChanged:    _validateTrack,
                              style:        TextStyle(color: theme.textPrimary, fontSize: 14),
                              decoration:   InputDecoration(labelText: 'Track Number', errorText: _trackError),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller:   _discCtrl,
                              keyboardType: TextInputType.number,
                              onChanged:    _validateDisc,
                              style:        TextStyle(color: theme.textPrimary, fontSize: 14),
                              decoration:   InputDecoration(labelText: 'Disc Number', errorText: _discError),
                            ),
                          ),
                          _tagField('Album Artist', _albumArtistCtrl, theme, TextInputType.text),
                          _tagField('Composer',     _composerCtrl,    theme, TextInputType.text),
                          _tagField('Comment',      _commentCtrl,     theme, TextInputType.multiline, maxLines: 3),
                          _tagField('Lyrics',       _lyricsCtrl,      theme, TextInputType.multiline, maxLines: 6),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primary,
                              foregroundColor: Colors.white,
                                minimumSize:     const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: (_saving || _yearError != null || _trackError != null || _discError != null)
                            ? null
                            : _save,
                            child: _saving
                            ? const SizedBox(width: 22, height: 22,
                                             child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Save Tags', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagField(
    String label,
    TextEditingController ctrl,
    FlacRTheme theme,
    TextInputType keyboardType, {
      int maxLines = 1,
    }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller:   ctrl,
        keyboardType: keyboardType,
        maxLines:     maxLines,
        style:        TextStyle(color: theme.textPrimary, fontSize: 14),
        decoration:   InputDecoration(
          labelText:          label,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
    }
}

class ArtworkPicker extends StatefulWidget {
  const ArtworkPicker({
    super.key,
    required this.filePath,
    required this.hasArtwork,
    required this.theme,
    required this.onChanged,
  });

  final String                   filePath;
  final bool                     hasArtwork;
  final FlacRTheme               theme;
  final ValueChanged<Uint8List?> onChanged;

  @override
  State<ArtworkPicker> createState() => _ArtworkPickerState();
}

class _ArtworkPickerState extends State<ArtworkPicker> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    if (widget.hasArtwork) {
      ArtworkCache.instance.get(widget.filePath).then((bytes) {
        if (mounted) setState(() => _bytes = bytes);
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _bytes = bytes);
    widget.onChanged(bytes);
  }

  void _removeImage() {
    setState(() => _bytes = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color:        theme.surface,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: theme.textMuted.withValues(alpha: 0.4), width: 1.5),
            ),
            child: _bytes != null
            ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.memory(_bytes!, fit: BoxFit.cover),
            )
            : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded, color: theme.textMuted, size: 32),
                const SizedBox(height: 4),
                Text('Add Cover', style: TextStyle(fontSize: 11, color: theme.textMuted)),
              ],
            ),
          ),
          if (_bytes != null)
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: _removeImage,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color:        FlacRTheme.errorRed,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

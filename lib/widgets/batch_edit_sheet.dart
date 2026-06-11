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

class BatchEditSheet extends StatefulWidget {
  const BatchEditSheet({
    super.key,
    required this.files,
    required this.theme,
    required this.onDone,
  });
  final List<AudioFile> files;
  final FlacRTheme      theme;
  final VoidCallback    onDone;

  @override
  State<BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends State<BatchEditSheet> {
  final _artistCtrl      = TextEditingController();
  final _albumCtrl       = TextEditingController();
  final _yearCtrl        = TextEditingController();
  final _genreCtrl       = TextEditingController();
  final _albumArtistCtrl = TextEditingController();
  final _trackCtrl       = TextEditingController();
  final _discCtrl        = TextEditingController();
  final _composerCtrl    = TextEditingController();
  final _commentCtrl     = TextEditingController();

  Uint8List? _pendingArtwork;
  bool       _artworkChanged = false;

  bool    _saving     = false;
  String? _yearError;
  String? _trackError;
  String? _discError;

  @override
  void dispose() {
    _artistCtrl.dispose();      _albumCtrl.dispose();
    _yearCtrl.dispose();        _genreCtrl.dispose();
    _albumArtistCtrl.dispose(); _trackCtrl.dispose();
    _discCtrl.dispose();        _composerCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  static final _yearRe = RegExp(r'^\d{4}(-(?:0[1-9]|1[0-2])(-(?:0[1-9]|[12]\d|3[01]))?)?$');

  void _validateYear(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) { setState(() => _yearError = null); return; }
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

  Future<void> _save() async {
    if (_yearError != null || _trackError != null || _discError != null) return;
    final library = context.read<AudioLibrary>();
    setState(() => _saving = true);

    final newArtist      = _artistCtrl.text.trim();
    final newAlbum       = _albumCtrl.text.trim();
    final newYearRaw     = _yearCtrl.text.trim();
    final newYearStr     = newYearRaw.isNotEmpty ? newYearRaw : null;
    final newYearInt     = newYearStr != null ? int.tryParse(newYearStr.split('-').first) : null;
    final newGenre       = _genreCtrl.text.trim();
    final newAlbumArtist = _albumArtistCtrl.text.trim();
    final newTrackRaw    = _trackCtrl.text.trim();
    final newDiscRaw     = _discCtrl.text.trim();
    final newComposer    = _composerCtrl.text.trim();
    final newComment     = _commentCtrl.text.trim();

    int ok = 0, fail = 0;
    for (final file in widget.files) {
      try {
        final resolvedTrack   = newTrackRaw.isNotEmpty ? int.tryParse(newTrackRaw) : file.trackNumber;
        final resolvedDisc    = newDiscRaw.isNotEmpty  ? int.tryParse(newDiscRaw)  : file.discNumber;
        final resolvedYearInt = newYearInt ?? (file.year != null ? int.tryParse(file.year!.split('-').first) : null);
        final resolvedYearStr = newYearStr ?? file.year;
        final resolvedArtwork = _artworkChanged
        ? _pendingArtwork
        : await ArtworkCache.instance.get(file.path);
        final tag = Tag(
          title:       file.title,
          trackArtist: newArtist.isNotEmpty      ? newArtist      : file.artist,
          album:       newAlbum.isNotEmpty        ? newAlbum       : file.album,
          year:        resolvedYearInt,
          genre:       newGenre.isNotEmpty        ? newGenre       : file.genre,
          trackNumber: resolvedTrack,
          discNumber:  resolvedDisc,
          albumArtist: newAlbumArtist.isNotEmpty  ? newAlbumArtist : file.albumArtist,
          lyrics:      file.lyrics,
          pictures: resolvedArtwork != null
          ? [Picture(bytes: resolvedArtwork, mimeType: null, pictureType: PictureType.other)]
          : [],
        );
        if (ExtraTags.isJaudiotaggerFormat(file.path)) {
          if (ExtraTags.isOggFormat(file.path) && _artworkChanged) {
            await AudioTags.write(file.path, tag);
          }
          await ExtraTags.writeAllTags(
            file.path,
            title:       file.title,
            artist:      newArtist.isNotEmpty     ? newArtist      : file.artist,
            album:       newAlbum.isNotEmpty       ? newAlbum       : file.album,
            year:        resolvedYearInt,
            genre:       newGenre.isNotEmpty       ? newGenre       : file.genre,
            trackNumber: resolvedTrack,
            discNumber:  resolvedDisc,
            albumArtist: newAlbumArtist.isNotEmpty ? newAlbumArtist : file.albumArtist,
            lyrics:      file.lyrics,
            composer:    newComposer.isNotEmpty ? newComposer : file.composer,
            comment:     newComment.isNotEmpty  ? newComment  : file.comment,
            artworkBytes: (!ExtraTags.isOggFormat(file.path) && _artworkChanged)
            ? (resolvedArtwork != null ? resolvedArtwork.toList() : [])
            : null,
          );
        } else {
          await AudioTags.write(file.path, tag);
          await ExtraTags.write(
            file.path,
            composer: newComposer.isNotEmpty ? newComposer : file.composer,
            comment:  newComment.isNotEmpty  ? newComment  : file.comment,
          );
        }

        library.updateFile(file.copyWith(
          artist:       newArtist.isNotEmpty      ? newArtist      : null,
          album:        newAlbum.isNotEmpty        ? newAlbum       : null,
          year:         resolvedYearStr,
          genre:        newGenre.isNotEmpty        ? newGenre       : null,
          albumArtist:  newAlbumArtist.isNotEmpty  ? newAlbumArtist : null,
          trackNumber:  resolvedTrack,
          discNumber:   resolvedDisc,
          hasArtwork:   _artworkChanged ? (resolvedArtwork != null) : file.hasArtwork,
          clearArtwork: _artworkChanged && _pendingArtwork == null,
          composer:     newComposer.isNotEmpty ? newComposer : null,
          comment:      newComment.isNotEmpty  ? newComment  : null,
        ));
        ok++;
      } catch (_) {
        fail++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fail == 0
        ? 'Updated $ok track${ok == 1 ? '' : 's'}'
        : 'Updated $ok, failed $fail'),
        backgroundColor: fail == 0 ? widget.theme.primary : FlacRTheme.errorRed,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = widget.theme;
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final kb     = MediaQuery.of(context).viewInsets.bottom;

    return Container(
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
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:        theme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_rounded, color: theme.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Batch Edit',
                             style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                              color: theme.textPrimary)),
                                  Text(
                                    '${widget.files.length} track${widget.files.length == 1 ? '' : 's'} selected'
                                  ' — leave blank to keep existing',
                                  style: TextStyle(fontSize: 11, color: theme.textMuted),
                                  ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: BatchArtworkPicker(
                  theme:     theme,
                  onChanged: (bytes) => setState(() {
                    _pendingArtwork = bytes;
                    _artworkChanged = true;
                  }),
                  onCleared: () => setState(() {
                    _pendingArtwork = null;
                    _artworkChanged = true;
                  }),
                  onReset: () => setState(() {
                    _pendingArtwork = null;
                    _artworkChanged = false;
                  }),
                  artworkChanged: _artworkChanged,
                  pendingArtwork: _pendingArtwork,
                ),
              ),
              const SizedBox(height: 20),
              _batchField('Artist',       _artistCtrl,      theme, TextInputType.text),
              _batchField('Album',        _albumCtrl,       theme, TextInputType.text),
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
              _batchField('Genre',        _genreCtrl,       theme, TextInputType.text),
              _batchField('Album Artist', _albumArtistCtrl, theme, TextInputType.text),
              _batchField('Composer',     _composerCtrl,    theme, TextInputType.text),
              _batchField('Comment',      _commentCtrl,     theme, TextInputType.multiline, maxLines: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller:   _trackCtrl,
                  keyboardType: TextInputType.number,
                  onChanged:    _validateTrack,
                  style:        TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration:   InputDecoration(
                    labelText: 'Track Number',
                    hintText:  'Leave blank to keep existing',
                    errorText: _trackError,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller:   _discCtrl,
                  keyboardType: TextInputType.number,
                  onChanged:    _validateDisc,
                  style:        TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration:   InputDecoration(
                    labelText: 'Disc Number',
                    hintText:  'Leave blank to keep existing',
                    errorText: _discError,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TRACKS TO UPDATE',
                         style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                          color: theme.textMuted, letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              ...widget.files.take(5).map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(f.title,
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                              )),
                              if (widget.files.length > 5)
                                Text('+ ${widget.files.length - 5} more',
                                     style: TextStyle(fontSize: 11, color: theme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                : const Text('Apply to All', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _batchField(String label, TextEditingController ctrl,
                     FlacRTheme theme, TextInputType kt, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller:   ctrl,
        keyboardType: kt,
        maxLines:     maxLines,
        style:        TextStyle(color: theme.textPrimary, fontSize: 14),
        decoration:   InputDecoration(
          labelText:          label,
          hintText:           'Leave blank to keep existing',
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
                     }
}

class BatchArtworkPicker extends StatelessWidget {
  const BatchArtworkPicker({
    super.key,
    required this.theme,
    required this.onChanged,
    required this.onCleared,
    required this.onReset,
    required this.artworkChanged,
    required this.pendingArtwork,
  });

  final FlacRTheme               theme;
  final ValueChanged<Uint8List?> onChanged;
  final VoidCallback             onCleared;
  final VoidCallback             onReset;
  final bool                     artworkChanged;
  final Uint8List?               pendingArtwork;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    onChanged(await picked.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    if (!artworkChanged) {
      return GestureDetector(
        onTap: _pick,
        child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color:        theme.surface,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(
              color: theme.textMuted.withValues(alpha: 0.4),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: theme.textMuted, size: 28),
              const SizedBox(height: 4),
              Text('Set Cover Art',
                   style: TextStyle(fontSize: 10, color: theme.textMuted),
                   textAlign: TextAlign.center),
                   const SizedBox(height: 2),
                   Text('(optional)',
                   style: TextStyle(fontSize: 9, color: theme.textMuted.withValues(alpha: 0.6))),
            ],
          ),
        ),
      );
    }

    if (pendingArtwork != null) {
      return Stack(
        children: [
          GestureDetector(
            onTap: _pick,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(pendingArtwork!, width: 120, height: 120, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onCleared,
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
          Positioned(
            bottom: 4, right: 4,
            child: GestureDetector(
              onTap: onReset,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color:        theme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: theme.textMuted.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.undo_rounded, size: 13, color: theme.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pick,
      child: Stack(
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color:        FlacRTheme.errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(
                color: FlacRTheme.errorRed.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hide_image_rounded,
                     color: FlacRTheme.errorRed.withValues(alpha: 0.7), size: 28),
                     const SizedBox(height: 4),
                     Text('Cover will be\nremoved',
                          style: TextStyle(
                            fontSize: 10,
                            color:    FlacRTheme.errorRed.withValues(alpha: 0.8),
                            height:   1.4,
                          ),
                          textAlign: TextAlign.center),
              ],
            ),
          ),

          Positioned(
            bottom: 4, right: 4,
            child: GestureDetector(
              onTap: onReset,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color:        theme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: theme.textMuted.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.undo_rounded, size: 13, color: theme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

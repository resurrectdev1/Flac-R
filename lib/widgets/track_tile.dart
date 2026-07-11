import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_file.dart';
import '../models/audio_library.dart';
import '../providers/flacr_settings.dart';
import '../theme/flacr_theme.dart';
import 'edit_sheet.dart';
import 'batch_edit_sheet.dart';
import 'batch_banner.dart';
import 'artwork_image.dart';

class DetailListPage extends StatefulWidget {
  const DetailListPage({super.key, required this.title, required this.files});

  final String          title;
  final List<AudioFile> files;

  @override
  State<DetailListPage> createState() => _DetailListPageState();
}

class _DetailListPageState extends State<DetailListPage> {
  bool              _selectMode = false;
  final Set<String> _selected   = {};

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selectMode = true;
        _selected.add(path);
      }
    });
  }

  void _exitSelectMode() => setState(() { _selected.clear(); _selectMode = false; });

  void _selectAll(List<AudioFile> live) =>
  setState(() => _selected.addAll(live.map((f) => f.path)));

  void _showBatchEdit(List<AudioFile> live) {
    final theme         = context.read<FlacRSettings>().theme;
    final selectedFiles = live.where((f) => _selected.contains(f.path)).toList();
    if (selectedFiles.isEmpty) return;
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BatchEditSheet(
        files:  selectedFiles,
        theme:  theme,
        onDone: _exitSelectMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme     = context.watch<FlacRSettings>().theme;
    final library   = context.watch<AudioLibrary>();
    final paths     = widget.files.map((f) => f.path).toSet();
    final liveFiles = library.files.where((f) => paths.contains(f.path)).toList();

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surfaceHigh,
        elevation:       0,
        title: Text(
          widget.title,
          style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: theme.textSecondary),
        actions: [
          if (!_selectMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip:   'Batch edit',
                icon:      Icon(Icons.checklist_rounded, color: theme.textSecondary, size: 22),
                onPressed: () {
                  if (liveFiles.isEmpty) return;
                  setState(() { _selectMode = true; });
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectMode)
            BatchBanner(
              count:       _selected.length,
              total:       liveFiles.length,
              theme:       theme,
              onSelectAll: () => _selectAll(liveFiles),
              onCancel:    _exitSelectMode,
              onBatchEdit: () => _showBatchEdit(liveFiles),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${liveFiles.length} track${liveFiles.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: theme.textMuted),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding:     const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount:   liveFiles.length,
                itemBuilder: (ctx, i) => TrackTile(
                  file:           liveFiles[i],
                  theme:          theme,
                  selectMode:     _selectMode,
                  isSelected:     _selected.contains(liveFiles[i].path),
                  onToggleSelect: _toggleSelect,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.file,
    required this.theme,
    this.selectMode     = false,
    this.isSelected     = false,
    this.onToggleSelect,
  });

  final AudioFile             file;
  final FlacRTheme            theme;
  final bool                  selectMode;
  final bool                  isSelected;
  final ValueChanged<String>? onToggleSelect;

  String get _ext {
    final p = file.path.toLowerCase();
    if (p.endsWith('.flac')) return 'FLAC';
    if (p.endsWith('.m4a'))  return 'M4A';
    if (p.endsWith('.aac'))  return 'AAC';
    if (p.endsWith('.ogg'))  return 'OGG';
    return 'MP3';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (selectMode) {
          onToggleSelect?.call(file.path);
        } else {
          _showEditSheet(context);
        }
      },
      onLongPress: () => onToggleSelect?.call(file.path),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin:   const EdgeInsets.only(bottom: 8),
        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary.withValues(alpha: 0.12) : theme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.primary : theme.textMuted.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (selectMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color:        isSelected ? theme.primary : Colors.transparent,
                    border:       Border.all(
                      color: isSelected ? theme.primary : theme.textMuted,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isSelected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
                ),
              ),
              ArtworkImage(
                path:             file.path,
                hasArtwork:       file.hasArtwork,
                size:             44,
                borderRadius:     10,
                placeholderColor: theme.primary.withValues(alpha: 0.12),
                placeholderChild: Center(
                  child: Text(_ext,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                               color: theme.primary, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.title,
                         maxLines: 1, overflow: TextOverflow.ellipsis,
                         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                          color: theme.textPrimary)),
                              const SizedBox(height: 2),
                              Text('${file.artist} — ${file.album}',
                                   maxLines: 1, overflow: TextOverflow.ellipsis,
                                   style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                                   if (file.year != null || file.trackNumber != null || file.genre != null) ...[
                                     const SizedBox(height: 2),
                                     Text(
                                       [
                                         if (file.trackNumber != null) '#${file.trackNumber}',
                                           if (file.year        != null) '${file.year}',
                                             if (file.genre       != null)  file.genre!,
                                       ].join(' · '),
                                       style: TextStyle(fontSize: 10, color: theme.textMuted),
                                     ),
                                   ],
                  ],
                ),
              ),
              if (!selectMode)
                Icon(Icons.chevron_right_rounded, color: theme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext ctx) {
    showModalBottomSheet(
      context:            ctx,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => EditSheet(file: file, theme: theme),
    );
  }
}

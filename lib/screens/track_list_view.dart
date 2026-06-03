import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_file.dart';
import '../models/audio_library.dart';
import '../theme/flacr_theme.dart';
import '../utils/sort_utils.dart';
import '../widgets/batch_banner.dart';
import '../widgets/batch_edit_sheet.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/track_tile.dart';

class TrackListView extends StatefulWidget {
  const TrackListView({super.key, required this.theme});
  final FlacRTheme theme;

  @override
  State<TrackListView> createState() => TrackListViewState();
}

class TrackListViewState extends State<TrackListView> {
  SortField         _sortField  = SortField.title;
  SortOrder         _sortOrder  = SortOrder.asc;
  String            _query      = '';
  bool              _selectMode = false;
  final Set<String> _selected   = {};
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AudioFile> _sorted(List<AudioFile> files) =>
  sortFiles(files, field: _sortField, order: _sortOrder, query: _query);

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(path);
      }
    });
  }

  void _exitSelectMode() => setState(() { _selected.clear(); _selectMode = false; });

  void _showSortSheet() {
    final theme = widget.theme;
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      useSafeArea:     true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final navBar = MediaQuery.of(ctx).viewPadding.bottom;
        return StatefulBuilder(
          builder: (ctx2, setSortState) => Container(
            decoration: BoxDecoration(
              color:        theme.surfaceHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navBar),
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHandle(theme: theme),
                  const SizedBox(height: 20),
                  Text('Sort & Order',
                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                        color: theme.textPrimary)),
                            const SizedBox(height: 16),
                            Text('SORT BY',
                                 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                  color: theme.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: SortField.values.map((f) {
                                final active = _sortField == f;
                                return ChoiceChip(
                                  label:           Text(f.label),
                                  selected:        active,
                                  selectedColor:   theme.primary.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color:      active ? theme.primary : theme.textSecondary,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                  backgroundColor: theme.surface,
                                  side: BorderSide(
                                    color: active ? theme.primary : theme.textMuted.withValues(alpha: 0.3),
                                  ),
                                  onSelected: (_) {
                                    setState(() => _sortField = f);
                                    setSortState(() {});
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            Text('ORDER',
                                 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                  color: theme.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _orderChip('A → Z', SortOrder.asc,  theme, setSortState),
                                const SizedBox(width: 8),
                                _orderChip('Z → A', SortOrder.desc, theme, setSortState),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primary,
                                foregroundColor: Colors.white,
                                  minimumSize:     const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _orderChip(String label, SortOrder order, FlacRTheme theme, StateSetter setSortState) {
    final active = _sortOrder == order;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _sortOrder = order);
          setSortState(() {});
        },
        child: AnimatedContainer(
          duration:   const Duration(milliseconds: 150),
          padding:    const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        active ? theme.primary.withValues(alpha: 0.18) : theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? theme.primary : theme.textMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      active ? theme.primary : theme.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize:   13,
            ),
          ),
        ),
      ),
    );
  }

  void _showBatchEdit(List<AudioFile> sorted) {
    final selectedFiles = sorted.where((f) => _selected.contains(f.path)).toList();
    if (selectedFiles.isEmpty) return;
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => BatchEditSheet(
        files:  selectedFiles,
        theme:  widget.theme,
        onDone: _exitSelectMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme   = widget.theme;
    final library = context.watch<AudioLibrary>();

    if (library.scanning) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: theme.primary),
          const SizedBox(height: 20),
          Text('Scanning library…', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
        ]),
      );
    }

    if (library.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline_rounded, color: FlacRTheme.errorRed, size: 48),
            const SizedBox(height: 16),
            Text('Scan failed', style: TextStyle(color: theme.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            Text(library.error!, style: TextStyle(color: theme.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => library.scan(
                roots: context.read<FlacRSettings>().scanRoots.toList(),
              ),
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary, foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),
      );
    }

    final files = library.files;

    if (files.isEmpty) {
      final noFolders = context.read<FlacRSettings>().scanRoots.isEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:        theme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                noFolders ? Icons.folder_open_rounded : Icons.music_off_rounded,
                color: theme.primary.withValues(alpha: 0.6), size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              noFolders ? 'No folders chosen' : 'No tracks found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300,
                               color: theme.textMuted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              noFolders
              ? 'Open Settings and add a folder\ncontaining your MP3 or FLAC files.'
            : 'No MP3 or FLAC files were found\nin your selected folders.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.textMuted, height: 1.6),
            ),
            const SizedBox(height: 24),
            if (!noFolders)
              ElevatedButton.icon(
                onPressed: () => library.scan(
                  roots: context.read<FlacRSettings>().scanRoots.toList(),
                ),
                icon:  const Icon(Icons.refresh_rounded),
                label: const Text('Scan again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary, foregroundColor: Colors.white,
                ),
              ),
          ]),
        ),
      );
    }

    final sorted = _sorted(files);

    return Column(
      children: [
        if (_selectMode)
          BatchBanner(
            count:       _selected.length,
            total:       sorted.length,
            theme:       theme,
            onSelectAll: () => setState(() => _selected.addAll(sorted.map((f) => f.path))),
            onCancel:    _exitSelectMode,
            onBatchEdit: () => _showBatchEdit(sorted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style:      TextStyle(color: theme.textPrimary, fontSize: 14),
                    onChanged:  (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText:   'Search tracks…',
                      prefixIcon: Icon(Icons.search_rounded, color: theme.textMuted, size: 20),
                      suffixIcon: _query.isNotEmpty
                      ? IconButton(
                        icon:      Icon(Icons.clear_rounded, color: theme.textMuted, size: 18),
                        onPressed: () { setState(() => _query = ''); _searchCtrl.clear(); },
                      )
                      : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showSortSheet,
                  child: Container(
                    height:  48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color:        theme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border:       Border.all(color: theme.textMuted.withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sort_rounded, color: theme.textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${_sortField.label} ${_sortOrder == SortOrder.asc ? '↑' : '↓'}',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12,
                                         fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(
                sorted.isEmpty && _query.isNotEmpty
                ? 'No results for "$_query"'
              : '${sorted.length} track${sorted.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: theme.textMuted),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              color:     theme.primary,
              onRefresh: () => library.scan(
                roots: context.read<FlacRSettings>().scanRoots.toList(),
              ),
              child: sorted.isEmpty
              ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text('No results for "$_query"',
                                style: TextStyle(color: theme.textMuted, fontSize: 14)),
                  ),
                ],
              )
              : ListView.builder(
                padding:     const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount:   sorted.length,
                itemBuilder: (ctx, i) => TrackTile(
                  file:           sorted[i],
                  theme:          theme,
                  selectMode:     _selectMode,
                  isSelected:     _selected.contains(sorted[i].path),
                  onToggleSelect: (path) {
                    setState(() {
                      _selectMode = true;
                      _toggleSelect(path);
                    });
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_file.dart';
import '../models/audio_library.dart';
import '../theme/flacr_theme.dart';
import '../utils/sort_utils.dart';
import '../widgets/scan_progress_view.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/track_tile.dart';

class GroupView extends StatefulWidget {
  const GroupView({
    super.key,
    required this.theme,
    required this.label,
    required this.groupGetter,
    this.iconData,
  });

  final FlacRTheme theme;
  final String label;
  final Map<String, List<AudioFile>> Function(AudioLibrary) groupGetter;
  final IconData? iconData;

  @override
  State<GroupView> createState() => _GroupViewState();
}

class _GroupViewState extends State<GroupView> {
  SortOrder _order = SortOrder.asc;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final library = context.watch<AudioLibrary>();

    if (library.scanning) {
      return ScanProgressView(theme: theme, progress: library.progress);
    }

    if (library.files.isEmpty) {
      return Center(
        child: Text(
          'No tracks found',
          style: TextStyle(color: theme.textMuted, fontSize: 14),
        ),
      );
    }

    final groups = widget.groupGetter(library);
    final keys =
        groups.keys
            .where(
              (k) =>
                  _query.isEmpty ||
                  k.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => _order == SortOrder.asc
                ? a.toLowerCase().compareTo(b.toLowerCase())
                : b.toLowerCase().compareTo(a.toLowerCase()),
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.label}s…',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.textMuted,
                      size: 20,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: theme.textMuted,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _query = '');
                              _searchCtrl.clear();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SortOrderToggle(
                order: _order,
                theme: theme,
                onToggle: () => setState(
                  () => _order = _order == SortOrder.asc
                      ? SortOrder.desc
                      : SortOrder.asc,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              keys.isEmpty && _query.isNotEmpty
                  ? 'No results for "$_query"'
                  : '${keys.length} ${widget.label}${keys.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: theme.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: keys.length,
            itemBuilder: (ctx, i) {
              final groupName = keys[i];
              final tracks = groups[groupName]!;
              final coverTrack = tracks.firstWhere(
                (t) => t.hasArtwork,
                orElse: () => tracks.first,
              );
              return GroupTile(
                theme: theme,
                artworkPath: coverTrack.hasArtwork ? coverTrack.path : null,
                icon: widget.iconData,
                title: groupName,
                subtitle:
                    '${tracks.length} track${tracks.length == 1 ? '' : 's'}',
                tracks: tracks,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
                        DetailListPage(title: groupName, files: tracks),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AlbumView extends StatelessWidget {
  const AlbumView({super.key, required this.theme});
  final FlacRTheme theme;
  @override
  Widget build(BuildContext context) =>
      GroupView(theme: theme, label: 'album', groupGetter: (lib) => lib.albums);
}

class ArtistView extends StatelessWidget {
  const ArtistView({super.key, required this.theme});
  final FlacRTheme theme;
  @override
  Widget build(BuildContext context) => GroupView(
    theme: theme,
    label: 'artist',
    groupGetter: (lib) => lib.artists,
    iconData: Icons.person_rounded,
  );
}

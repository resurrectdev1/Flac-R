import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_library.dart';
import '../theme/flacr_theme.dart';
import '../utils/sort_utils.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/track_tile.dart';

class FolderView extends StatefulWidget {
  const FolderView({super.key, required this.theme});
  final FlacRTheme theme;

  @override
  State<FolderView> createState() => FolderViewState();
}

class FolderViewState extends State<FolderView> {
  SortOrder _order = SortOrder.asc;

  @override
  Widget build(BuildContext context) {
    final theme   = widget.theme;
    final library = context.watch<AudioLibrary>();

    if (library.scanning) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    if (library.files.isEmpty) {
      return Center(
        child: Text('No tracks found', style: TextStyle(color: theme.textMuted, fontSize: 14)),
      );
    }

    final folders = library.folders;
    final keys    = folders.keys.toList()
    ..sort((a, b) => _order == SortOrder.asc
    ? a.toLowerCase().compareTo(b.toLowerCase())
    : b.toLowerCase().compareTo(a.toLowerCase()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${keys.length} folder${keys.length == 1 ? '' : 's'}',
                   style: TextStyle(fontSize: 11, color: theme.textMuted)),
                   SortOrderToggle(
                     order:    _order,
                     theme:    theme,
                     onToggle: () => setState(() =>
                     _order = _order == SortOrder.asc ? SortOrder.desc : SortOrder.asc),
                   ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding:     const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount:   keys.length,
            itemBuilder: (ctx, i) {
              final dir    = keys[i];
              final tracks = folders[dir]!;
              final label  = dir.split('/').last;
              return GroupTile(
                theme:    theme,
                artworkPath: null,
                icon:     Icons.folder_rounded,
                title:    label,
                subtitle: dir.length > 48
                ? '…${dir.substring(dir.length - 46)}'
              : dir,
              trailing: '${tracks.length} file${tracks.length == 1 ? '' : 's'}',
              onTap: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => DetailListPage(title: label, files: tracks),
              )),
              );
            },
          ),
        ),
      ],
    );
  }
}

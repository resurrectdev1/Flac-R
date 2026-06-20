import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/audio_file.dart';
import '../theme/flacr_theme.dart';
import '../utils/sort_utils.dart';
import 'artwork_image.dart';
import 'batch_edit_sheet.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, required this.theme});
  final FlacRTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
          color:        theme.textMuted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class SortOrderToggle extends StatelessWidget {
  const SortOrderToggle({
    super.key,
    required this.order,
    required this.theme,
    required this.onToggle,
  });

  final SortOrder    order;
  final FlacRTheme   theme;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height:  44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:        theme.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: theme.textMuted.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            order == SortOrder.asc
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
            color: theme.textSecondary, size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            order == SortOrder.asc ? 'A–Z' : 'Z–A',
            style: TextStyle(
              color:      theme.textSecondary,
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.artworkPath,
    this.icon,
    this.trailing,
    this.tracks,
  });

  final FlacRTheme         theme;
  final String?            artworkPath;
  final IconData?          icon;
  final String             title;
  final String             subtitle;
  final String?            trailing;
  final VoidCallback       onTap;
  final List<AudioFile>?   tracks;

  void _showBatchEdit(BuildContext context) {
    final t = tracks;
    if (t == null || t.isEmpty) return;
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BatchEditSheet(
        files:  t,
        theme:  theme,
        onDone: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:     const EdgeInsets.only(bottom: 8),
        padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        theme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: theme.textMuted.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            ArtworkImage(
              path:             artworkPath ?? '',
              hasArtwork:       artworkPath != null,
              size:             48,
              borderRadius:     10,
              placeholderColor: theme.primary.withValues(alpha: 0.12),
              placeholderChild: Icon(
                icon ?? Icons.album_rounded,
                color: theme.primary.withValues(alpha: 0.6), size: 24,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: theme.textSecondary),
                  ),
                  if (tracks != null && tracks!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showBatchEdit(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        theme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, size: 11, color: theme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Batch edit all',
                              style: TextStyle(
                                fontSize:   10,
                                fontWeight: FontWeight.w600,
                                color:      theme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (trailing != null) ...[
              Text(trailing!, style: TextStyle(fontSize: 11, color: theme.textMuted)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, color: theme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class AboutLinkTile extends StatelessWidget {
  const AboutLinkTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.url,
    required this.theme,
  });

  final IconData   icon;
  final Color      iconColor;
  final String     label;
  final String     sublabel;
  final String     url;
  final FlacRTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding:    const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        theme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      theme.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(fontSize: 11, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: theme.textMuted),
          ],
        ),
      ),
    );
  }
}

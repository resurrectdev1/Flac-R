import 'package:flutter/material.dart';
import '../models/audio_library.dart';
import '../theme/flacr_theme.dart';

class ScanProgressView extends StatelessWidget {
  const ScanProgressView({
    super.key,
    required this.theme,
    required this.progress,
  });

  final FlacRTheme theme;
  final ScanProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final frac = (p != null && p.total > 0) ? p.scanned / p.total : null;
    final label = p != null
        ? '${p.scanned} / ${p.total}  ·  ${p.currentFile}'
        : 'Scanning library…';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.library_music_rounded,
                color: theme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Scanning Library',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: theme.surface,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
              ),
            ),
            const SizedBox(height: 10),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

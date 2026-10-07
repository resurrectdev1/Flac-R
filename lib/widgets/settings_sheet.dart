import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../models/audio_library.dart';
import '../providers/flacr_settings.dart';
import '../theme/flacr_theme.dart';
import 'accent_picker_sheet.dart';
import 'shared_widgets.dart';

class FlacRSettingsSheet extends StatefulWidget {
  const FlacRSettingsSheet({super.key});

  @override
  State<FlacRSettingsSheet> createState() => _FlacRSettingsSheetState();
}

class _FlacRSettingsSheetState extends State<FlacRSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final liveSettings = context.watch<FlacRSettings>();
    final theme = liveSettings.theme;
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + navBar + kb),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHandle(theme: theme),
              const SizedBox(height: 20),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'THEME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              RadioGroup<FlacRThemeMode>(
                groupValue: liveSettings.themeMode,
                onChanged: (mode) {
                  if (mode == null) return;
                  HapticFeedback.selectionClick();
                  liveSettings.setThemeMode(mode);
                },
                child: Column(
                  children: FlacRThemeMode.values.map((mode) {
                    const labels = {
                      FlacRThemeMode.darkSlate: 'Dark Slate',
                      FlacRThemeMode.amoledBlack: 'AMOLED Black',
                      FlacRThemeMode.materialYou: 'Material You',
                      FlacRThemeMode.whiteMinimal: 'White Minimal',
                    };
                    return RadioListTile<FlacRThemeMode>(
                      value: mode,
                      activeColor: theme.primary,
                      fillColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? theme.primary
                            : theme.textMuted,
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        labels[mode]!,
                        style: TextStyle(color: theme.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              _AccentRow(settings: liveSettings),
              const SizedBox(height: 28),
              Text(
                'SCAN FOLDERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                liveSettings.scanRoots.isEmpty
                    ? 'Tap on "Add Folder" to begin'
                    : '${liveSettings.scanRoots.length} '
                          'folder${liveSettings.scanRoots.length == 1 ? '' : 's'} selected',
                style: TextStyle(fontSize: 11, color: theme.textMuted),
              ),
              const SizedBox(height: 12),
              ...liveSettings.scanRoots.map((path) {
                final label = path.split('/').where((s) => s.isNotEmpty).last;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.textMuted.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        color: theme.primary.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                            ),
                            Text(
                              path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          await liveSettings.removeScanRoot(path);
                          setState(() {});
                          if (!context.mounted) return;
                          context.read<AudioLibrary>().scan(
                            roots: liveSettings.scanRoots.toList(),
                          );
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: FlacRTheme.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            color: FlacRTheme.errorRed,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              GestureDetector(
                onTap: () async {
                  final picked = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: 'Choose a folder to scan',
                  );
                  if (picked != null) {
                    await liveSettings.addScanRoot(picked);
                    setState(() {});
                    if (!context.mounted) return;
                    context.read<AudioLibrary>().scan(
                      roots: liveSettings.scanRoots.toList(),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: theme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Add Folder',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (liveSettings.scanRoots.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    for (final p in [...liveSettings.scanRoots]) {
                      await liveSettings.removeScanRoot(p);
                    }
                    setState(() {});
                    if (!context.mounted) return;
                    context.read<AudioLibrary>().scan(roots: []);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          color: theme.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reset to defaults',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Rescan Library',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  final library = context.read<AudioLibrary>();
                  library.scan(roots: liveSettings.scanRoots.toList());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showFlacRSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const FlacRSettingsSheet(),
  );
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.settings});
  final FlacRSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = settings.theme;
    final usesSystemColors = settings.themeMode == FlacRThemeMode.materialYou;
    final custom = settings.customAccent;

    final subtitle = usesSystemColors
        ? 'Not available with Material You'
        : custom != null
        ? '#${colorToHex(custom)}'
        : 'Default';

    return Opacity(
      opacity: usesSystemColors ? 0.5 : 1,
      child: GestureDetector(
        onTap: usesSystemColors
            ? null
            : () {
                HapticFeedback.selectionClick();
                showAccentPickerSheet(context);
              },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.textMuted.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.textMuted.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Accent',
                      style: TextStyle(fontSize: 14, color: theme.textPrimary),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: theme.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

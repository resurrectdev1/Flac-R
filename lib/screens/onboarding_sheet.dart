import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/audio_library.dart';
import '../theme/flacr_theme.dart';

class FlacROnboardingSheet extends StatefulWidget {
  const FlacROnboardingSheet({super.key});
  @override
  State<FlacROnboardingSheet> createState() => _FlacROnboardingSheetState();
}

class _FlacROnboardingSheetState extends State<FlacROnboardingSheet> {
  int  _page       = 0;
  bool _requesting = false;

  static const _steps = [
    _OnboardStep(
      icon:      Icons.audiotrack_rounded,
      iconColor: FlacRTheme.accentPurple,
      title:     'Welcome to Flac-R 🎵',
      body:      'A free, open-source tag editor for your music library. '
    'Suppourts .mp3 .flac .m4a .ogg & .aac',
    kind:      _StepKind.intro,
    ),
    _OnboardStep(
      icon:      Icons.warning_amber_rounded,
      iconColor: FlacRTheme.accentAmber,
      title:     'Before You Start',
      body:      'Flac-R is provided as-is, with no warranty of any kind. '
    'We recommend testing on a few files before fully committing your library. '
    'Libraries with 1000+ tracks are expected to load slowly so splitting '
    'your library or scanning folder by folder is recommended.',
    kind:      _StepKind.disclaimer,
    ),
    _OnboardStep(
      icon:      Icons.folder_open_rounded,
      iconColor: FlacRTheme.accentBlue,
      title:     'Read Your Library',
      body:      'Flac-R needs permission to read audio files from your storage. '
    'Without this, no tracks can be listed or displayed.',
    kind:      _StepKind.readAudio,
    ),
    _OnboardStep(
      icon:      Icons.edit_rounded,
      iconColor: FlacRTheme.accentPurple,
      title:     'Allow Tag Editing',
      body:      'To save changes to your music files, Flac-R needs full '
    'storage access. Android will open a system screen, tap "Allow" '
    'to enable tag editing. Your files are never uploaded anywhere.',
    kind:      _StepKind.manageStorage,
    ),
    _OnboardStep(
      icon:      Icons.create_new_folder_rounded,
      iconColor: FlacRTheme.accentTeal,
      title:     'Choose Music Folders',
      body:      'Pick the folders where your music files live. '
    'You can add or remove folders anytime from Settings.',
    kind:      _StepKind.folderPick,
    ),
  ];

  Future<void> _advance() async {
    final step = _steps[_page];
    HapticFeedback.selectionClick();

    switch (step.kind) {
      case _StepKind.intro:
        setState(() => _page++);

      case _StepKind.disclaimer:
        setState(() => _page++);

      case _StepKind.readAudio:
        setState(() => _requesting = true);
        PermissionStatus status = await Permission.audio.request();
        if (!status.isGranted) await Permission.storage.request();
        if (mounted) setState(() { _requesting = false; _nextPageOrFinish(); });

      case _StepKind.manageStorage:
        setState(() => _requesting = true);
        await Permission.manageExternalStorage.request();
        if (mounted) setState(() { _requesting = false; _nextPageOrFinish(); });

      case _StepKind.folderPick:
        final picked = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Choose a music folder',
        );
        if (picked != null && mounted) {
          await context.read<FlacRSettings>().addScanRoot(picked);
          final roots = context.read<FlacRSettings>().scanRoots.toList();
          context.read<AudioLibrary>().scan(roots: roots);
        }
        if (mounted) _nextPageOrFinish();
    }
  }

  void _nextPageOrFinish() {
    if (_page < _steps.length - 1) {
      setState(() => _page++);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme     = context.watch<FlacRSettings>().theme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final step      = _steps[_page];
    final isLast    = _page == _steps.length - 1;
    final isIntro   = step.kind == _StepKind.intro;
    final isDisclaimer = step.kind == _StepKind.disclaimer;

    return Container(
      decoration: BoxDecoration(
        color:        theme.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        theme.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
            child: Container(
              key:    ValueKey('icon_$_page'),
              width:  96, height: 96,
              decoration: BoxDecoration(
                color:        step.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(step.icon, color: step.iconColor, size: 48),
            ),
          ),
          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              step.title,
              key:       ValueKey('title_$_page'),
              style:     TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              step.body,
              key:       ValueKey('body_$_page'),
              style:     TextStyle(fontSize: 14, color: theme.textSecondary, height: 1.65),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) => AnimatedContainer(
              duration:  const Duration(milliseconds: 250),
              margin:    const EdgeInsets.symmetric(horizontal: 3),
              width:     i == _page ? 18 : 6,
              height:    6,
              decoration: BoxDecoration(
                color:        i == _page
                ? theme.primary
                : theme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              if (_page > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _requesting ? null : () => setState(() => _page--),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textSecondary,
                        side:            BorderSide(color: theme.textMuted.withValues(alpha: 0.4)),
                        minimumSize:     const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              const SizedBox(width: 12),
              ],
              Expanded(
                flex: _page > 0 ? 2 : 1,
                child: FilledButton(
                  onPressed: _requesting ? null : _advance,
                  style: FilledButton.styleFrom(
                    backgroundColor: isLast ? FlacRTheme.accentPurple : theme.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _requesting
                  ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                  )
                  : Text(
                    isLast                              ? 'Start Editing 🎵'  :
                    isIntro                             ? 'Get Started'        :
                    isDisclaimer                        ? 'I Understand'       :
                    step.kind == _StepKind.folderPick  ? 'Choose Folder'      :
                    'Grant Permission',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),

          if (!isIntro && !isDisclaimer) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _requesting ? null : _nextPageOrFinish,
              child: Text(
                'Skip this step',
                style: TextStyle(color: theme.textMuted, fontSize: 13),
              ),
            ),
          ] else
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

enum _StepKind { intro, disclaimer, readAudio, manageStorage, folderPick }

class _OnboardStep {
  final IconData  icon;
  final Color     iconColor;
  final String    title;
  final String    body;
  final _StepKind kind;
  const _OnboardStep({
    required this.icon, required this.iconColor,
    required this.title, required this.body, required this.kind,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/audio_library.dart';
import '../providers/flacr_settings.dart';
import '../theme/flacr_theme.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/onboarding_sheet.dart';
import 'track_list_view.dart';
import '../widgets/group_view.dart';
import 'folder_view.dart';

enum HomeTab { track, album, artist, folders }

class FlacRHomeScreen extends StatefulWidget {
  const FlacRHomeScreen({super.key});
  @override
  State<FlacRHomeScreen> createState() => _FlacRHomeScreenState();
}

class _FlacRHomeScreenState extends State<FlacRHomeScreen> {
  HomeTab _currentTab = HomeTab.track;
  String _appVersion = '';

  static const _tabMeta = {
    HomeTab.track:   (icon: Icons.music_note_rounded, label: 'Track'),
    HomeTab.album:   (icon: Icons.album_rounded,      label: 'Album'),
    HomeTab.artist:  (icon: Icons.person_rounded,     label: 'Artist'),
    HomeTab.folders: (icon: Icons.folder_rounded,     label: 'Folders'),
  };

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final library  = context.read<AudioLibrary>();
        final settings = context.read<FlacRSettings>();

        if (!settings.onboardingDone) {
          _showOnboarding();
          return;
        }

        if (settings.scanRoots.isEmpty) return;
        await library.scan(roots: settings.scanRoots.toList());
        if (mounted && library.skippedCount > 0) {
          final n = library.skippedCount;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              '$n file${n == 1 ? '' : 's'} couldn\'t be read and '
            '${n == 1 ? 'was' : 'were'} skipped — tags may be corrupt or unsupported.',
            ),
            backgroundColor: FlacRTheme.errorRed,
            behavior:        SnackBarBehavior.floating,
            duration:        const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      });
  }

  void _showOnboarding() {
    final settingsProvider = context.read<FlacRSettings>();
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      useSafeArea:        true,
      isDismissible:      false,
      enableDrag:         false,
      builder: (_) => const FlacROnboardingSheet(),
    ).then((_) {
      settingsProvider.completeOnboarding();
      final library = context.read<AudioLibrary>();
      if (!library.scanning && settingsProvider.scanRoots.isNotEmpty) {
        library.scan(roots: settingsProvider.scanRoots.toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FlacRSettings>();
    final theme    = settings.theme;

    return Scaffold(
      backgroundColor:        theme.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        centerTitle:     true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon:      Icon(Icons.info_outline_rounded, color: theme.textSecondary, size: 20),
            onPressed: () => _showAboutSheet(context),
            tooltip:   'About',
          ),
        ),
        title: Text(
          'F L A C - R',
          style: TextStyle(
            color:         theme.textSecondary,
            fontSize:      13,
            fontWeight:    FontWeight.w400,
            letterSpacing: 6,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon:      Icon(Icons.settings_outlined, color: theme.textSecondary, size: 20),
              onPressed: () => showFlacRSettingsSheet(context),
              tooltip:   'Settings',
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _buildTabBody(theme),
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildTabBody(FlacRTheme theme) {
    final library  = context.watch<AudioLibrary>();
    final settings = context.watch<FlacRSettings>();

    if (!library.scanning && library.files.isEmpty && settings.scanRoots.isEmpty) {
      return _buildNoFoldersState(theme);
    }

    switch (_currentTab) {
      case HomeTab.track:
        return TrackListView(theme: theme);
      case HomeTab.album:
        return AlbumView(theme: theme);
      case HomeTab.artist:
        return ArtistView(theme: theme);
      case HomeTab.folders:
        return FolderView(theme: theme);
    }
  }

  Widget _buildNoFoldersState(FlacRTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:        theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.folder_open_rounded, color: theme.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'No music folders added',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Open Settings and add the folders where your music files live.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon:     const Icon(Icons.settings_outlined, size: 18),
              label:    const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => showFlacRSettingsSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(FlacRTheme theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color:  theme.surfaceHigh,
        border: Border(
          top: BorderSide(color: theme.textMuted.withValues(alpha: 0.15), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: HomeTab.values.map((tab) {
              final meta     = _tabMeta[tab]!;
              final isActive = _currentTab == tab;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_currentTab != tab) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentTab = tab);
                    }
                  },
                  child: AnimatedContainer(
                    duration:   const Duration(milliseconds: 200),
                    curve:      Curves.easeInOut,
                    margin:     const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    padding:    const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                      ? theme.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                      : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(meta.icon, size: 22,
                             color: isActive ? theme.primary : theme.textMuted),
                             const SizedBox(height: 3),
                             Text(
                               meta.label,
                               style: TextStyle(
                                 fontSize:      10,
                                 fontWeight:    isActive ? FontWeight.w600 : FontWeight.w400,
                                 color:         isActive ? theme.primary : theme.textMuted,
                                 letterSpacing: 0.3,
                               ),
                             ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext ctx) {
    final theme     = ctx.read<FlacRSettings>().theme;
    final bottomPad = MediaQuery.of(ctx).padding.bottom;

    showModalBottomSheet(
      context:            ctx,
      backgroundColor:    theme.surfaceHigh,
      isScrollControlled: true,
      useSafeArea:        true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color:        theme.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 52, height: 52,
                    fit:   BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flac-R', style: TextStyle(
                      fontSize:      24,
                      fontWeight:    FontWeight.w800,
                      color:         theme.textPrimary,
                      letterSpacing: 1,
                    )),
                    Text('v${_appVersion.isEmpty ? '...' : _appVersion} • Open Source',
                         style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Flac-R is a minimalistic tag editor designed to keep your music library clean. '
            'It comes packed with many QOL features and is, '
            'proudly built with love as a free, open-source tool.',
            style: TextStyle(fontSize: 13, color: theme.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 24),
            Text('LINKS', style: TextStyle(
              fontSize:      11,
              fontWeight:    FontWeight.w700,
              color:         theme.textMuted,
              letterSpacing: 1.0,
            )),
            const SizedBox(height: 12),
            _AboutLinkTile(
              icon:      Icons.code_rounded,
              iconColor: theme.textPrimary,
              label:     'GitHub',
              sublabel:  'Source code & contributions',
              url:       'https://github.com/resurrectdev1/flac-r',
              theme:     theme,
            ),
            const SizedBox(height: 10),
            _AboutLinkTile(
              icon:      Icons.coffee_rounded,
              iconColor: const Color(0xFFFFDD57),
              label:     'Buy Me a Coffee',
              sublabel:  'Support development',
              url:       'https://buymeacoffee.com/resurrect',
              theme:     theme,
            ),
            const SizedBox(height: 24),
            Text(
              'Made with 🎵 • all data stays on your device.',
              style:     TextStyle(fontSize: 10, color: theme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}

class _AboutLinkTile extends StatelessWidget {
  final IconData   icon;
  final Color      iconColor;
  final String     label;
  final String     sublabel;
  final String     url;
  final FlacRTheme theme;

  const _AboutLinkTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.url,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        theme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                    Text(sublabel, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: theme.textMuted),
          ],
        ),
      ),
    ),
  );
}

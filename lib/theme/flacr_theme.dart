import 'package:flutter/material.dart';

enum FlacRThemeMode { darkSlate, amoledBlack, whiteMinimal }

class FlacRTheme {
  final FlacRThemeMode mode;

  final bool materialYou;
  final ColorScheme? dynamicLight;
  final ColorScheme? dynamicDark;
  final Color? customAccent;
  const FlacRTheme({
    required this.mode,
    this.materialYou = false,
    this.dynamicLight,
    this.dynamicDark,
    this.customAccent,
  });

  ColorScheme? get _dyn {
    if (!materialYou) return null;
    return brightness == Brightness.light ? dynamicLight : dynamicDark;
  }

  bool get _dynSurfaces => _dyn != null && mode != FlacRThemeMode.amoledBlack;

  Color get bg {
    if (_dynSurfaces) return _dyn!.surface;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF0D0F14);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFF000000);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFFF5F5F5);
    }
  }

  Color get surface {
    if (_dynSurfaces) return _dyn!.surfaceContainerLow;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF13161E);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFF0A0A0A);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFFFFFFFF);
    }
  }

  Color get surfaceHigh {
    if (_dynSurfaces) return _dyn!.surfaceContainerHigh;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF1C2030);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFF121212);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFFE8E8E8);
    }
  }

  Color get cardBg {
    if (_dynSurfaces) return _dyn!.surfaceContainer;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF161929);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFF000000);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFFFAFAFA);
    }
  }

  Color get primary {
    if (_dyn != null) return _dyn!.primary;
    if (customAccent != null) return customAccent!;
    return defaultPrimary;
  }

  Color get defaultPrimary {
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF7B68EE);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFF7B68EE);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFF5A4FCF);
    }
  }

  Color get textPrimary {
    if (_dynSurfaces) return _dyn!.onSurface;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFFE8E8F0);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFFFFFFFF);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get textSecondary {
    if (_dynSurfaces) return _dyn!.onSurfaceVariant;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF8888AA);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFFAAAAAA);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFF666666);
    }
  }

  Color get textMuted {
    if (_dynSurfaces) return _dyn!.outline;
    switch (mode) {
      case FlacRThemeMode.darkSlate:
        return const Color(0xFF444466);
      case FlacRThemeMode.amoledBlack:
        return const Color(0xFF555555);
      case FlacRThemeMode.whiteMinimal:
        return const Color(0xFF999999);
    }
  }

  Brightness get brightness {
    switch (mode) {
      case FlacRThemeMode.whiteMinimal:
        return Brightness.light;
      default:
        return Brightness.dark;
    }
  }

  static const accentPurple = Color(0xFF7B68EE);
  static const accentAmber = Color(0xFFFFBF00);
  static const accentBlue = Color(0xFF5B8DEF);
  static const accentTeal = Color(0xFF3EC9C9);
  static const errorRed = Color(0xFFCF6679);

  static const List<Color> accentPresets = [
    Color(0xFF7B68EE),
    Color(0xFF5B8DEF),
    Color(0xFF42A5C8),
    Color(0xFF3EC9C9),
    Color(0xFF4E8B7A),
    Color(0xFF4CAF82),
    Color(0xFF7A9E3B),
    Color(0xFFFFBF00),
    Color(0xFFC46A4A),
    Color(0xFFE5624D),
    Color(0xFFE0529C),
    Color(0xFF9E3B6B),
    Color(0xFF8B5E9E),
    Color(0xFF6B7A7D),
  ];
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FlacRThemeMode { darkSlate, amoledBlack, materialYou, whiteMinimal }

class FlacRTheme {
  final FlacRThemeMode mode;
  final ColorScheme?   dynamicScheme;
  const FlacRTheme({required this.mode, this.dynamicScheme});

  Color get bg {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF0D0F14);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFF000000);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFFF5F5F5);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.surface ?? const Color(0xFF0D0F14);
    }
  }

  Color get surface {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF13161E);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFF0A0A0A);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFFFFFFFF);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.surfaceContainerLow ?? const Color(0xFF13161E);
    }
  }

  Color get surfaceHigh {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF1C2030);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFF121212);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFFE8E8E8);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.surfaceContainerHigh ?? const Color(0xFF1C2030);
    }
  }

  Color get cardBg {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF161929);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFF000000);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFFFAFAFA);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.surfaceContainer ?? const Color(0xFF161929);
    }
  }

  Color get primary {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF7B68EE);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFF7B68EE);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFF5A4FCF);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.primary ?? const Color(0xFF7B68EE);
    }
  }

  Color get textPrimary {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFFE8E8F0);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFFFFFFFF);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFF1A1A1A);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.onSurface ?? const Color(0xFFE8E8F0);
    }
  }

  Color get textSecondary {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF8888AA);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFFAAAAAA);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFF666666);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.onSurfaceVariant ?? const Color(0xFF8888AA);
    }
  }

  Color get textMuted {
    switch (mode) {
      case FlacRThemeMode.darkSlate:    return const Color(0xFF444466);
      case FlacRThemeMode.amoledBlack:  return const Color(0xFF555555);
      case FlacRThemeMode.whiteMinimal: return const Color(0xFF999999);
      case FlacRThemeMode.materialYou:  return dynamicScheme?.outline ?? const Color(0xFF444466);
    }
  }

  Brightness get brightness {
    switch (mode) {
      case FlacRThemeMode.whiteMinimal: return Brightness.light;
      default:                          return Brightness.dark;
    }
  }

  static const accentPurple = Color(0xFF7B68EE);
  static const accentAmber  = Color(0xFFFFBF00);
  static const accentBlue   = Color(0xFF5B8DEF);
  static const accentTeal   = Color(0xFF3EC9C9);
  static const errorRed     = Color(0xFFCF6679);
}

class FlacRSettings extends ChangeNotifier {
  FlacRThemeMode _themeMode      = FlacRThemeMode.darkSlate;
  ColorScheme?   _dynamicScheme;
  bool           _onboardingDone = false;
  List<String>   _scanRoots      = [];

  FlacRThemeMode get themeMode      => _themeMode;
  bool           get onboardingDone => _onboardingDone;
  FlacRTheme     get theme          => FlacRTheme(mode: _themeMode, dynamicScheme: _dynamicScheme);
  List<String>   get scanRoots      => List.unmodifiable(_scanRoots);

  Future<void> init(ColorScheme? dynamicLight, ColorScheme? dynamicDark) async {
    final prefs      = await SharedPreferences.getInstance();
    final savedTheme = prefs.getInt('flacr_theme_mode') ?? 0;
    if (savedTheme < FlacRThemeMode.values.length) {
      _themeMode = FlacRThemeMode.values[savedTheme];
    }
    _onboardingDone = prefs.getBool('flacr_onboarding_done') ?? false;
    _scanRoots      = prefs.getStringList('flacr_scan_roots') ?? [];
    _dynamicScheme  = dynamicDark;
    notifyListeners();
  }

  Future<void> addScanRoot(String path) async {
    if (_scanRoots.contains(path)) return;
    _scanRoots = [..._scanRoots, path];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('flacr_scan_roots', _scanRoots);
    notifyListeners();
  }

  Future<void> removeScanRoot(String path) async {
    _scanRoots = _scanRoots.where((p) => p != path).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('flacr_scan_roots', _scanRoots);
    notifyListeners();
  }

  void applyDynamicColors(ColorScheme? light, ColorScheme? dark) {
    _dynamicScheme = dark ?? light;
    notifyListeners();
  }

  void applyDynamicColorsIfChanged(ColorScheme? light, ColorScheme? dark) {
    final next = dark ?? light;
    if (next?.primary == _dynamicScheme?.primary &&
      next?.surface == _dynamicScheme?.surface) return;
    _dynamicScheme = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> setThemeMode(FlacRThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flacr_theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flacr_onboarding_done', true);
    notifyListeners();
  }
}

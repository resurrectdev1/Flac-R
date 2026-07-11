import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/flacr_theme.dart';

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
      next?.surface == _dynamicScheme?.surface) {
      return;
    }
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

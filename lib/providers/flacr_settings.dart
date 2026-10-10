import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/flacr_theme.dart';

class FlacRSettings extends ChangeNotifier {
  FlacRThemeMode _themeMode = FlacRThemeMode.darkSlate;
  bool _materialYou = false;
  ColorScheme? _dynamicLight;
  ColorScheme? _dynamicDark;
  bool _onboardingDone = false;
  List<String> _scanRoots = [];
  Color? _customAccent;

  FlacRThemeMode get themeMode => _themeMode;
  bool get materialYou => _materialYou;
  bool get hasDynamicColors => _dynamicLight != null || _dynamicDark != null;
  bool get onboardingDone => _onboardingDone;
  Color? get customAccent => _customAccent;
  FlacRTheme get theme => FlacRTheme(
    mode: _themeMode,
    materialYou: _materialYou,
    dynamicLight: _dynamicLight,
    dynamicDark: _dynamicDark,
    customAccent: _customAccent,
  );
  List<String> get scanRoots => List.unmodifiable(_scanRoots);

  Future<void> init(ColorScheme? dynamicLight, ColorScheme? dynamicDark) async {
    final prefs = await SharedPreferences.getInstance();
    final savedBase = prefs.getInt('flacr_theme_base');
    if (savedBase != null) {
      if (savedBase >= 0 && savedBase < FlacRThemeMode.values.length) {
        _themeMode = FlacRThemeMode.values[savedBase];
      }
      _materialYou = prefs.getBool('flacr_material_you') ?? false;
    } else {
      switch (prefs.getInt('flacr_theme_mode') ?? 0) {
        case 1:
          _themeMode = FlacRThemeMode.amoledBlack;
        case 2:
          _themeMode = FlacRThemeMode.darkSlate;
          _materialYou = true;
        case 3:
          _themeMode = FlacRThemeMode.whiteMinimal;
        default:
          _themeMode = FlacRThemeMode.darkSlate;
      }
    }
    _onboardingDone = prefs.getBool('flacr_onboarding_done') ?? false;
    _scanRoots = prefs.getStringList('flacr_scan_roots') ?? [];
    final accentInt = prefs.getInt('flacr_custom_accent');
    if (accentInt != null) _customAccent = Color(accentInt);
    _dynamicLight = dynamicLight;
    _dynamicDark = dynamicDark;
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
    _dynamicLight = light;
    _dynamicDark = dark;
    notifyListeners();
  }

  void applyDynamicColorsIfChanged(ColorScheme? light, ColorScheme? dark) {
    if (light?.primary == _dynamicLight?.primary &&
        light?.surface == _dynamicLight?.surface &&
        dark?.primary == _dynamicDark?.primary &&
        dark?.surface == _dynamicDark?.surface) {
      return;
    }
    _dynamicLight = light;
    _dynamicDark = dark;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> setThemeMode(FlacRThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flacr_theme_base', mode.index);
    await prefs.setBool('flacr_material_you', _materialYou);
    notifyListeners();
  }

  Future<void> setMaterialYou(bool value) async {
    _materialYou = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flacr_material_you', value);
    await prefs.setInt('flacr_theme_base', _themeMode.index);
    notifyListeners();
  }

  Future<void> setCustomAccent(Color? color) async {
    _customAccent = color;
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove('flacr_custom_accent');
    } else {
      await prefs.setInt('flacr_custom_accent', color.toARGB32());
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flacr_onboarding_done', true);
    notifyListeners();
  }
}

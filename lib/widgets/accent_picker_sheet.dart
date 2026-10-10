import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/flacr_settings.dart';
import '../theme/flacr_theme.dart';
import '../theme/motion.dart';
import 'shared_widgets.dart';

String colorToHex(Color color) => color
    .toARGB32()
    .toRadixString(16)
    .padLeft(8, '0')
    .substring(2)
    .toUpperCase();

class _HexInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
    if (text.length > 6) text = text.substring(0, 6);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class AccentPickerSheet extends StatefulWidget {
  const AccentPickerSheet({super.key});

  @override
  State<AccentPickerSheet> createState() => _AccentPickerSheetState();
}

class _AccentPickerSheetState extends State<AccentPickerSheet> {
  late final TextEditingController _hexCtrl;
  late Color _color;
  bool _hexComplete = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<FlacRSettings>();
    _color = settings.customAccent ?? settings.theme.defaultPrimary;
    _hexCtrl = TextEditingController(text: colorToHex(_color));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _onHexChanged(String value) {
    final complete = value.length == 6;
    setState(() {
      _hexComplete = complete;
      if (complete) _color = Color(int.parse('FF$value', radix: 16));
    });
  }

  void _selectPreset(Color c) {
    HapticFeedback.selectionClick();
    setState(() {
      _color = c;
      _hexCtrl.text = colorToHex(c);
      _hexComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FlacRSettings>();
    final theme = settings.theme;
    final mq = MediaQuery.of(context);
    final bottomPad = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);
    final onColor =
        ThemeData.estimateBrightnessForColor(_color) == Brightness.light
        ? Colors.black87
        : Colors.white;
    final showError = !_hexComplete && _hexCtrl.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHandle(theme: theme),
            const SizedBox(height: 20),
            Text(
              'Custom Accent',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Applied across buttons, icons, and highlights',
              style: TextStyle(fontSize: 13, color: theme.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(
              'PRESET COLORS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: FlacRTheme.accentPresets.map((c) {
                final sel = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => _selectPreset(c),
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.standard,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? theme.textPrimary : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: sel
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color:
                                ThemeData.estimateBrightnessForColor(c) ==
                                    Brightness.light
                                ? Colors.black87
                                : Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'CUSTOM HEX CODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    style: TextStyle(color: theme.textPrimary),
                    inputFormatters: [_HexInputFormatter()],
                    onChanged: _onHexChanged,
                    decoration: InputDecoration(
                      labelText: 'Hex Code',
                      prefixText: '#',
                      prefixStyle: TextStyle(color: theme.textSecondary),
                      hintText: colorToHex(theme.defaultPrimary),
                      prefixIcon: Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: theme.textMuted,
                      ),
                      errorText: showError ? 'Enter 6 hex digits' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.textMuted.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _hexComplete
                  ? () {
                      HapticFeedback.lightImpact();
                      final color = _color;
                      Navigator.pop(context);
                      settings.setCustomAccent(color);
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: onColor,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Apply Accent',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (settings.customAccent != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  settings.setCustomAccent(null);
                },
                child: Text(
                  'Reset to default',
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showAccentPickerSheet(BuildContext context) {
  final theme = context.read<FlacRSettings>().theme;
  return showModalBottomSheet(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const AccentPickerSheet(),
  );
}

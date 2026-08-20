import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/PurchaseOrder/services/theme.dart' show ErpColors;
import 'theme_controller.dart';

// ══════════════════════════════════════════════════════════════
//  THE CONTROL, IN TWO SIZES
//
//  [ThemeToggleButton] is one tap in an app bar: go to the other one.
//  [ThemeModePicker] is the full three-way choice for a settings
//  screen, because "match phone" is a real answer and a two-state
//  switch cannot express it.
//
//  The button lives on the dark navy bar, so it takes textOnDark
//  rather than textPrimary — the bar is dark in BOTH themes, and a
//  toggle that inverts with the page would disappear into it.
// ══════════════════════════════════════════════════════════════

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.onDarkBar = true});

  /// True when this sits on the navy app bar (the usual case).
  final bool onDarkBar;

  @override
  Widget build(BuildContext context) {
    final c = ThemeController.to;
    return Obx(() {
      c.revision.value; // rebuild when the phone flips under us
      final dark = c.isDark;
      return IconButton(
        tooltip: dark ? 'Switch to light' : 'Switch to dark',
        onPressed: c.toggle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            key: ValueKey(dark),
            size: 20,
            color: onDarkBar ? ErpColors.textOnDark : ErpColors.textPrimary,
          ),
        ),
      );
    });
  }
}

/// Three explicit choices, for a settings screen.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ThemeController.to;
    return Obx(() {
      final active = c.mode.value;
      c.revision.value;
      return Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ErpColors.borderLight),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 3),
            Text(
              // Says what "match phone" will actually do right now,
              // rather than leaving somebody to test it at dusk.
              active == ErpThemeMode.system
                  ? 'Following the phone — currently '
                      '${c.isDark ? 'dark' : 'light'}.'
                  : 'Set to ${active.label.toLowerCase()} on this device.',
              style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final m in ErpThemeMode.values) ...[
                  Expanded(
                    child: _Option(
                      mode: m,
                      selected: m == active,
                      onTap: () => c.setMode(m),
                    ),
                  ),
                  if (m != ErpThemeMode.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ErpThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: mode.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? ErpColors.accentBlue.withOpacity(0.12)
                : ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? ErpColors.accentBlue : ErpColors.borderLight,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(mode.icon,
                  size: 19,
                  color: selected
                      ? ErpColors.accentBlue
                      : ErpColors.textSecondary),
              const SizedBox(height: 5),
              Text(
                mode.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? ErpColors.accentBlue
                      : ErpColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  THE PALETTE, AS DATA
//
//  Every colour this app draws with, in one immutable object, with
//  two instances: light and dark. ErpColors then becomes a set of
//  getters over "whichever one is current", which is what lets a
//  theme switch reach 5,500 call sites without editing them.
//
//  ── The dark set is designed, not inverted ─────────────────────
//  Inverting a light palette produces grey text on grey and status
//  tints that all read the same. Three rules were applied instead:
//
//  1. The GROUND goes darkest, surfaces come UP from it. A card has
//     to be lighter than the page or the whole screen is one plane.
//     navyDark stays below bgSurface so a header strip inside a card
//     still reads as recessed, which is the job it does in light.
//
//  2. Accents get BRIGHTER, not darker. #1D6FEB is a good blue on
//     white and nearly invisible on #0B1219, so the dark accent is
//     lifted to #4D93FF — same hue, enough luminance to carry.
//
//  3. Status pairs stay PAIRS. Each status has a background tint and
//     a text colour that must remain legible against it. Darkening
//     the tint without lifting the text is the classic way a status
//     chip becomes unreadable in dark mode, so both move together.
//
//  ── Why textOnDark barely changes ──────────────────────────────
//  It names text sitting on the NAVY, not text on the page. The navy
//  is dark in both themes, so white stays right in both. Renaming it
//  would be more honest and would also touch several hundred call
//  sites; the name is left alone and explained here instead.
// ══════════════════════════════════════════════════════════════

@immutable
class ErpPalette {
  // ── Brand ──────────────────────────────────────────────────
  final Color navyDark;    // AppBar, header strips
  final Color navyMid;     // Secondary surfaces
  final Color navyLight;   // Hover states
  final Color accentBlue;  // Primary action
  final Color accentLight; // Icon accents

  // ── Background ─────────────────────────────────────────────
  final Color bgBase;      // Page background
  final Color bgSurface;   // Cards, panels
  final Color bgMuted;     // Table alt rows
  final Color bgHover;     // Row hover

  // ── Borders ────────────────────────────────────────────────
  final Color borderLight;
  final Color borderMid;

  // ── Text ───────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnDark;
  final Color textOnDarkSub;

  // ── Status ─────────────────────────────────────────────────
  final Color statusOpenBg;
  final Color statusOpenText;
  final Color statusOpenBorder;

  final Color statusPartialBg;
  final Color statusPartialText;
  final Color statusPartialBorder;

  final Color statusCompletedBg;
  final Color statusCompletedText;
  final Color statusCompletedBorder;

  final Color statusApprovedBg;
  final Color statusApprovedBorder;
  final Color statusApprovedText;

  final Color statusInProgressBg;
  final Color statusInProgressBorder;
  final Color statusInProgressText;

  final Color statusCancelledBg;
  final Color statusCancelledBorder;
  final Color statusCancelledText;

  final Color errorRed;
  final Color successGreen;
  final Color warningAmber;

  /// True for the dark set. Screens that need to make a real
  /// either/or decision — an image overlay, a chart grid — ask this
  /// rather than comparing a colour against a literal.
  final bool isDark;

  const ErpPalette({
    required this.navyDark,
    required this.navyMid,
    required this.navyLight,
    required this.accentBlue,
    required this.accentLight,
    required this.bgBase,
    required this.bgSurface,
    required this.bgMuted,
    required this.bgHover,
    required this.borderLight,
    required this.borderMid,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnDark,
    required this.textOnDarkSub,
    required this.statusOpenBg,
    required this.statusOpenText,
    required this.statusOpenBorder,
    required this.statusPartialBg,
    required this.statusPartialText,
    required this.statusPartialBorder,
    required this.statusCompletedBg,
    required this.statusCompletedText,
    required this.statusCompletedBorder,
    required this.statusApprovedBg,
    required this.statusApprovedBorder,
    required this.statusApprovedText,
    required this.statusInProgressBg,
    required this.statusInProgressBorder,
    required this.statusInProgressText,
    required this.statusCancelledBg,
    required this.statusCancelledBorder,
    required this.statusCancelledText,
    required this.errorRed,
    required this.successGreen,
    required this.warningAmber,
    required this.isDark,
  });

  /// The palette this app has always drawn in, unchanged.
  static const ErpPalette light = ErpPalette(
    navyDark:    Color(0xFF0D1B2A),
    navyMid:     Color(0xFF1B2B45),
    navyLight:   Color(0xFF2D4A6E),
    accentBlue:  Color(0xFF1D6FEB),
    accentLight: Color(0xFF5A9EFF),

    bgBase:      Color(0xFFEEF1F7),
    bgSurface:   Color(0xFFFFFFFF),
    bgMuted:     Color(0xFFF8FAFD),
    bgHover:     Color(0xFFEFF4FF),

    borderLight: Color(0xFFDDE3EE),
    borderMid:   Color(0xFFBCC6D8),

    textPrimary:   Color(0xFF0D1B2A),
    textSecondary: Color(0xFF5A6A85),
    textMuted:     Color(0xFF94A3B8),
    textOnDark:    Color(0xFFFFFFFF),
    textOnDarkSub: Color(0xFFB0C4E0),

    statusOpenBg:     Color(0xFFEFF6FF),
    statusOpenText:   Color(0xFF1D6FEB),
    statusOpenBorder: Color(0xFFBFDBFE),

    statusPartialBg:     Color(0xFFFFFBEB),
    statusPartialText:   Color(0xFFB45309),
    statusPartialBorder: Color(0xFFFDE68A),

    statusCompletedBg:     Color(0xFFF0FDF4),
    statusCompletedText:   Color(0xFF15803D),
    statusCompletedBorder: Color(0xFFBBF7D0),

    statusApprovedBg:     Color(0xFFEFF6FF),
    statusApprovedBorder: Color(0xFFBFDBFE),
    statusApprovedText:   Color(0xFF1D6FEB),

    statusInProgressBg:     Color(0xFFFFFBEB),
    statusInProgressBorder: Color(0xFFFDE68A),
    statusInProgressText:   Color(0xFFD97706),

    statusCancelledBg:     Color(0xFFFEF2F2),
    statusCancelledBorder: Color(0xFFFECACA),
    statusCancelledText:   Color(0xFFDC2626),

    errorRed:     Color(0xFFDC2626),
    successGreen: Color(0xFF16A34A),
    warningAmber: Color(0xFFD97706),

    isDark: false,
  );

  /// See the three rules at the top of this file.
  static const ErpPalette dark = ErpPalette(
    // Below bgSurface on purpose: a header strip inside a card has to
    // stay recessed, which is the job navyDark does in light too.
    navyDark:    Color(0xFF111C28),
    navyMid:     Color(0xFF1B2735),
    navyLight:   Color(0xFF26374B),
    // Lifted from #1D6FEB — the light accent is nearly invisible on
    // a #0B1219 ground.
    accentBlue:  Color(0xFF4D93FF),
    accentLight: Color(0xFF7FB4FF),

    bgBase:      Color(0xFF0B1219),
    bgSurface:   Color(0xFF151E2A),
    bgMuted:     Color(0xFF101922),
    bgHover:     Color(0xFF1B2837),

    borderLight: Color(0xFF24313F),
    borderMid:   Color(0xFF35455A),

    textPrimary:   Color(0xFFE8EEF6),
    textSecondary: Color(0xFFA5B4C8),
    textMuted:     Color(0xFF6F8098),
    // Still text on the NAVY, which is dark in both themes.
    textOnDark:    Color(0xFFFFFFFF),
    textOnDarkSub: Color(0xFF9DB2CE),

    statusOpenBg:     Color(0xFF13243A),
    statusOpenText:   Color(0xFF6BA5FF),
    statusOpenBorder: Color(0xFF22405F),

    statusPartialBg:     Color(0xFF2A2113),
    statusPartialText:   Color(0xFFF0B45C),
    statusPartialBorder: Color(0xFF4A3A1C),

    statusCompletedBg:     Color(0xFF12271B),
    statusCompletedText:   Color(0xFF5FD48A),
    statusCompletedBorder: Color(0xFF1F4630),

    statusApprovedBg:     Color(0xFF13243A),
    statusApprovedBorder: Color(0xFF22405F),
    statusApprovedText:   Color(0xFF6BA5FF),

    statusInProgressBg:     Color(0xFF2A2113),
    statusInProgressBorder: Color(0xFF4A3A1C),
    statusInProgressText:   Color(0xFFF0B45C),

    statusCancelledBg:     Color(0xFF2C1414),
    statusCancelledBorder: Color(0xFF4D2422),
    statusCancelledText:   Color(0xFFFF8A80),

    errorRed:     Color(0xFFFF6B6B),
    successGreen: Color(0xFF4ADE80),
    warningAmber: Color(0xFFFBBF24),

    isDark: true,
  );
}

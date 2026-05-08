import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  ERP DESIGN SYSTEM — Employee App
//
//  Mirrors the admin app's theme (deep navy + cool white +
//  electric blue accent) so the two apps feel like one product.
//  Kept self-contained here so the employee_app folder is
//  buildable without leaning on the admin app's source tree.
// ══════════════════════════════════════════════════════════════

class ErpColors {
  ErpColors._();

  // Brand
  static const navyDark    = Color(0xFF0D1B2A);
  static const navyMid     = Color(0xFF1B2B45);
  static const navyLight   = Color(0xFF2D4A6E);
  static const accentBlue  = Color(0xFF1D6FEB);
  static const accentLight = Color(0xFF5A9EFF);

  // Backgrounds
  static const bgBase    = Color(0xFFEEF1F7);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgMuted   = Color(0xFFF8FAFD);
  static const bgHover   = Color(0xFFEFF4FF);

  // Borders
  static const borderLight = Color(0xFFDDE3EE);
  static const borderMid   = Color(0xFFBCC6D8);

  // Text
  static const textPrimary   = Color(0xFF0D1B2A);
  static const textSecondary = Color(0xFF5A6A85);
  static const textMuted     = Color(0xFF94A3B8);
  static const textOnDark    = Color(0xFFFFFFFF);
  static const textOnDarkSub = Color(0xFFB0C4E0);

  // Status palette
  static const statusOpenBg     = Color(0xFFEFF6FF);
  static const statusOpenText   = Color(0xFF1D6FEB);
  static const statusOpenBorder = Color(0xFFBFDBFE);

  static const statusCompletedBg     = Color(0xFFF0FDF4);
  static const statusCompletedText   = Color(0xFF15803D);
  static const statusCompletedBorder = Color(0xFFBBF7D0);

  static const statusInProgressBg     = Color(0xFFFFFBEB);
  static const statusInProgressBorder = Color(0xFFFDE68A);
  static const statusInProgressText   = Color(0xFFD97706);

  static const statusCancelledBg     = Color(0xFFFEF2F2);
  static const statusCancelledBorder = Color(0xFFFECACA);
  static const statusCancelledText   = Color(0xFFDC2626);

  // Semantic
  static const errorRed     = Color(0xFFDC2626);
  static const successGreen = Color(0xFF16A34A);
  static const warningAmber = Color(0xFFD97706);
}

class ErpTextStyles {
  ErpTextStyles._();

  static const pageTitle = TextStyle(
    color: ErpColors.textOnDark,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const sectionHeader = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  static const cardTitle = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static const fieldLabel = TextStyle(
    color: ErpColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const fieldValue = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const kpiValue = TextStyle(
    color: ErpColors.textOnDark,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static const kpiLabel = TextStyle(
    color: ErpColors.textOnDarkSub,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}

class ErpDecorations {
  ErpDecorations._();

  static InputDecoration formInput(String label,
      {String? hint, Widget? suffix, Widget? prefix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: ErpColors.textMuted, fontSize: 13),
        labelStyle: const TextStyle(
          color: ErpColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: ErpColors.accentBlue,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: ErpColors.bgSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: suffix,
        prefixIcon: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ErpColors.accentBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: ErpColors.errorRed),
        ),
      );

  static BoxDecoration card = BoxDecoration(
    color: ErpColors.bgSurface,
    border: Border.all(color: ErpColors.borderLight),
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1B2B45).withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// Reusable section card mirroring the admin app's `ErpSectionCard`.
class ErpSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;

  const ErpSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor = ErpColors.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: const Border(
                bottom: BorderSide(color: ErpColors.borderLight),
              ),
            ),
            child: Row(children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(title, style: ErpTextStyles.sectionHeader),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

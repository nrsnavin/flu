import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  ERP DESIGN SYSTEM — Production Tracking App
//  Palette: Deep Navy + Cool White + Electric Blue accent
//  Typography: Weight-driven hierarchy, tight letter-spacing
// ══════════════════════════════════════════════════════════════

class ErpColors {
  ErpColors._();

  // ── Brand ──────────────────────────────────────────────────
  static const navyDark    = Color(0xFF0D1B2A);   // AppBar, header strips
  static const navyMid     = Color(0xFF1B2B45);   // Secondary surfaces
  static const navyLight   = Color(0xFF2D4A6E);   // Hover states
  static const accentBlue  = Color(0xFF1D6FEB);   // Primary action
  static const accentLight = Color(0xFF5A9EFF);   // Icon accents

  // ── Background ─────────────────────────────────────────────
  static const bgBase      = Color(0xFFEEF1F7);   // Page background
  static const bgSurface   = Color(0xFFFFFFFF);   // Cards, panels
  static const bgMuted     = Color(0xFFF8FAFD);   // Table alt rows
  static const bgHover     = Color(0xFFEFF4FF);   // Row hover

  // ── Borders ────────────────────────────────────────────────
  static const borderLight = Color(0xFFDDE3EE);
  static const borderMid   = Color(0xFFBCC6D8);

  // ── Text ───────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0D1B2A);
  static const textSecondary = Color(0xFF5A6A85);
  static const textMuted     = Color(0xFF94A3B8);
  static const textOnDark    = Color(0xFFFFFFFF);
  static const textOnDarkSub = Color(0xFFB0C4E0);

  // ── Status ─────────────────────────────────────────────────
  static const statusOpenBg     = Color(0xFFEFF6FF);
  static const statusOpenText   = Color(0xFF1D6FEB);
  static const statusOpenBorder = Color(0xFFBFDBFE);

  static const statusPartialBg     = Color(0xFFFFFBEB);
  static const statusPartialText   = Color(0xFFB45309);
  static const statusPartialBorder = Color(0xFFFDE68A);

  static const statusCompletedBg     = Color(0xFFF0FDF4);
  static const statusCompletedText   = Color(0xFF15803D);
  static const statusCompletedBorder = Color(0xFFBBF7D0);

  static const errorRed    = Color(0xFFDC2626);
  static const successGreen = Color(0xFF16A34A);
  static const warningAmber = Color(0xFFD97706);



  static const Color statusApprovedBg     = Color(0xFFEFF6FF);
  static const Color statusApprovedBorder = Color(0xFFBFDBFE);
  static const Color statusApprovedText   = Color(0xFF1D6FEB);

  static const Color statusInProgressBg     = Color(0xFFFFFBEB);
  static const Color statusInProgressBorder = Color(0xFFFDE68A);
  static const Color statusInProgressText   = Color(0xFFD97706);


  static const Color statusCancelledBg     = Color(0xFFFEF2F2);
  static const Color statusCancelledBorder = Color(0xFFFECACA);
  static const Color statusCancelledText   = Color(0xFFDC2626);
}

class ErpTextStyles {
  ErpTextStyles._();

  // ── Page title (AppBar) ────────────────────────────────────
  static const pageTitle = TextStyle(
    color: ErpColors.textOnDark,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  // ── Section header ─────────────────────────────────────────
  static const sectionHeader = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  // ── Card title ─────────────────────────────────────────────
  static const cardTitle = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  // ── Field label ────────────────────────────────────────────
  static const fieldLabel = TextStyle(
    color: ErpColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ── Field value ────────────────────────────────────────────
  static const fieldValue = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  // ── Table header ───────────────────────────────────────────
  static const tableHeader = TextStyle(
    color: ErpColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  // ── Table cell ─────────────────────────────────────────────
  static const tableCell = TextStyle(
    color: ErpColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  // ── KPI number ─────────────────────────────────────────────
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

  // ── Button ─────────────────────────────────────────────────
  static const buttonPrimary = TextStyle(
    color: ErpColors.textOnDark,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const buttonSecondary = TextStyle(
    color: ErpColors.accentBlue,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

class ErpDecorations {
  ErpDecorations._();

  static BoxDecoration card = BoxDecoration(
    color: ErpColors.bgSurface,
    border: Border.all(color: ErpColors.borderLight),
    borderRadius: BorderRadius.circular(6),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1B2B45).withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration cardHover = BoxDecoration(
    color: ErpColors.bgHover,
    border: Border.all(color: ErpColors.accentBlue.withOpacity(0.3)),
    borderRadius: BorderRadius.circular(6),
    boxShadow: [
      BoxShadow(
        color: ErpColors.accentBlue.withOpacity(0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration inputField = BoxDecoration(
    color: ErpColors.bgSurface,
    border: Border.all(color: ErpColors.borderLight, width: 1),
    borderRadius: BorderRadius.circular(4),
  );

  static BoxDecoration inputFieldFocus = BoxDecoration(
    color: ErpColors.bgSurface,
    border: Border.all(color: ErpColors.accentBlue, width: 1.5),
    borderRadius: BorderRadius.circular(4),
  );

  static InputDecoration formInput(String label, {String? hint, Widget? suffix, Widget? prefix}) =>
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
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color bg, border, text;
    switch (status) {
      case "Approved":
        bg = ErpColors.statusApprovedBg;
        border = ErpColors.statusApprovedBorder;
        text = ErpColors.statusApprovedText;
        break;
      case "InProgress":
        bg = ErpColors.statusInProgressBg;
        border = ErpColors.statusInProgressBorder;
        text = ErpColors.statusInProgressText;
        break;
      case "Completed":
        bg = ErpColors.statusCompletedBg;
        border = ErpColors.statusCompletedBorder;
        text = ErpColors.statusCompletedText;
        break;
      case "Cancelled":
        bg = ErpColors.statusCancelledBg;
        border = ErpColors.statusCancelledBorder;
        text = ErpColors.statusCancelledText;
        break;
      default: // Open
        bg = ErpColors.statusOpenBg;
        border = ErpColors.statusOpenBorder;
        text = ErpColors.statusOpenText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: text, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
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
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(children: [
              Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(icon, size: 13, color: ErpColors.textSecondary),
              const SizedBox(width: 6),
              Text(title, style: ErpTextStyles.sectionHeader),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  REUSABLE INFO ROW
// ══════════════════════════════════════════════════════════════
class ErpInfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const ErpInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(label, style: ErpTextStyles.fieldLabel)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value?.toString().isNotEmpty == true
                    ? value.toString()
                    : "—",
                style: ErpTextStyles.fieldValue,
              ),
            ),
          ]),
    );
  }
}
// ══════════════════════════════════════════════════════════════
//  SHARED ERP COMPONENTS
// ══════════════════════════════════════════════════════════════

/// Deep-navy AppBar used across all PO screens
class ErpAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  const ErpAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: ErpColors.textOnDark),
        onPressed: () => Navigator.of(context).maybePop(),
      )
          : null,
      titleSpacing: showBack ? 0 : 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: ErpTextStyles.pageTitle),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                color: ErpColors.textOnDarkSub,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFF1E3A5F),
        ),
      ),
    );
  }


}

// ── Status Badge ───────────────────────────────────────────────
class ErpStatusBadge extends StatelessWidget {
  final String status;

  const ErpStatusBadge({super.key, required this.status});

  static const _configs = {
    'Open': (ErpColors.statusOpenBg, ErpColors.statusOpenText,
    ErpColors.statusOpenBorder, Icons.radio_button_unchecked),
    'Partial': (ErpColors.statusPartialBg, ErpColors.statusPartialText,
    ErpColors.statusPartialBorder, Icons.timelapse),
    'Completed': (ErpColors.statusCompletedBg, ErpColors.statusCompletedText,
    ErpColors.statusCompletedBorder, Icons.check_circle_outline),
  };

  @override
  Widget build(BuildContext context) {
    final config = _configs[status] ??
        (ErpColors.bgMuted, ErpColors.textSecondary, ErpColors.borderLight,
        Icons.help_outline);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: config.$1,
        border: Border.all(color: config.$3, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.$4, size: 11, color: config.$2),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: config.$2,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI Card (dark navy) ───────────────────────────────────────
class ErpKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color accentColor;

  const ErpKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    this.accentColor = ErpColors.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ErpColors.navyMid, ErpColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ErpTextStyles.kpiLabel),
                const SizedBox(height: 2),
                Text(value, style: ErpTextStyles.kpiValue),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Divider with Label ─────────────────────────────────
class ErpSectionLabel extends StatelessWidget {
  final String text;
  final Widget? action;

  const ErpSectionLabel({super.key, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: ErpColors.accentBlue,
              margin: const EdgeInsets.only(right: 8)),
          Text(text.toUpperCase(), style: ErpTextStyles.sectionHeader),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: ErpColors.borderLight)),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

// ── Form Section Card ──────────────────────────────────────────
class ErpFormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? titleAction;

  const ErpFormSection({
    super.key,
    required this.title,
    required this.children,
    this.titleAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: ErpDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header bar ─────────────────────────
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                        width: 3,
                        height: 14,
                        color: ErpColors.accentBlue,
                        margin: const EdgeInsets.only(right: 8)),
                    Text(title.toUpperCase(),
                        style: ErpTextStyles.sectionHeader),
                  ],
                ),
                if (titleAction != null) titleAction!,
              ],
            ),
          ),
          // ── Content ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row (label + value) ───────────────────────────────────

// ── Primary ERP Button ─────────────────────────────────────────
class ErpPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool compact;

  const ErpPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 34 : 40,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ErpColors.accentBlue,
          disabledBackgroundColor: ErpColors.accentBlue.withOpacity(0.5),
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding:
          EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: 0),
        ),
        child: isLoading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(label, style: ErpTextStyles.buttonPrimary),
          ],
        ),
      ),
    );
  }
}

// ── Outline ERP Button ─────────────────────────────────────────
class ErpOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  const ErpOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 34 : 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: ErpColors.accentBlue, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding:
          EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: 0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: ErpColors.accentBlue),
              const SizedBox(width: 6),
            ],
            Text(label, style: ErpTextStyles.buttonSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Table header row ───────────────────────────────────────────
class ErpTableHeader extends StatelessWidget {
  final List<_ColDef> columns;

  const ErpTableHeader({super.key, required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: ErpColors.bgMuted,
        border: Border(
          top: BorderSide(color: ErpColors.borderLight),
          bottom: BorderSide(color: ErpColors.borderLight),
        ),
      ),
      child: Row(
        children: columns.map((col) {
          return Expanded(
            flex: col.flex,
            child: Text(col.label.toUpperCase(),
                style: ErpTextStyles.tableHeader,
                textAlign: col.align),
          );
        }).toList(),
      ),
    );
  }
}

class _ColDef {
  final String label;
  final int flex;
  final TextAlign align;

  const _ColDef(this.label, {this.flex = 1, this.align = TextAlign.left});
}

// ── Data Row ───────────────────────────────────────────────────
class ErpDataRow extends StatefulWidget {
  final List<Widget> cells;
  final List<int> flexes;
  final VoidCallback? onTap;
  final bool isAlt;

  const ErpDataRow({
    super.key,
    required this.cells,
    required this.flexes,
    this.onTap,
    this.isAlt = false,
  });

  @override
  State<ErpDataRow> createState() => _ErpDataRowState();
}

class _ErpDataRowState extends State<ErpDataRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? ErpColors.bgHover
                : widget.isAlt
                ? ErpColors.bgMuted
                : ErpColors.bgSurface,
            border: const Border(
                bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(
            children: List.generate(
              widget.cells.length,
                  (i) => Expanded(
                flex: widget.flexes[i],
                child: widget.cells[i],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress Bar ───────────────────────────────────────────────
class ErpProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color? color;

  const ErpProgressBar({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (value >= 1 ? ErpColors.successGreen : ErpColors.accentBlue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            backgroundColor: ErpColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(c),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          "${(value * 100).clamp(0, 100).toStringAsFixed(0)}%",
          style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Page wrapper for all PO pages ─────────────────────────────
class ErpPage extends StatelessWidget {
  final Widget appBar;
  final Widget body;
  final Widget? bottomBar;
  final Widget? fab;

  const ErpPage({
    super.key,
    required this.appBar,
    required this.body,
    this.bottomBar,
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: appBar as PreferredSizeWidget,
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: fab,
    );
  }
}
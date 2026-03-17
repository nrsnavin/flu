import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_po.dart';

import '../models/po_models.dart';
import '../services/theme.dart';


class AddPOPage extends StatefulWidget {
  final POFormMode mode;
  final Map<String, dynamic>? seedData;

  const AddPOPage({super.key, required this.mode, this.seedData});

  @override
  State<AddPOPage> createState() => _AddPOPageState();
}

class _AddPOPageState extends State<AddPOPage> {
  late final AddPOController c;

  @override
  void initState() {
    super.initState();
    Get.delete<AddPOController>(force: true);
    c = Get.put(AddPOController(
      mode: widget.mode,
      seedData: widget.seedData,
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  @override
  void dispose() {
    Get.delete<AddPOController>(force: true);
    super.dispose();
  }

  String get _title {
    switch (widget.mode) {
      case POFormMode.edit:   return "Edit PO";
      case POFormMode.clone:  return "Clone PO";
      case POFormMode.create: return "New PO";
    }
  }

  IconData get _modeIcon {
    switch (widget.mode) {
      case POFormMode.edit:   return Icons.edit_outlined;
      case POFormMode.clone:  return Icons.copy_all_outlined;
      case POFormMode.create: return Icons.add_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (c.isDataLoading.value) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: ErpColors.accentBlue),
                SizedBox(height: 14),
                Text(
                  "Loading form data...",
                  style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(child: _FormBody(c: c)),
            _FooterBar(c: c, mode: widget.mode),
          ],
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(_modeIcon, color: ErpColors.accentLight, size: 15),
          ),
          const SizedBox(width: 8),
          // FIX: Flexible wraps the Column so it never overflows
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: ErpTextStyles.pageTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Procurement  ›  Purchase Orders",
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Mode badge — icon-only on small screens, avoids overflow
        if (widget.mode == POFormMode.edit)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ErpColors.warningAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                  color: ErpColors.warningAmber.withOpacity(0.4)),
            ),
            child: const Icon(Icons.edit_note,
                size: 16, color: ErpColors.warningAmber),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Form body ──────────────────────────────────────────────────
class _FormBody extends StatelessWidget {
  final AddPOController c;
  const _FormBody({required this.c});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section: Supplier ────────────────────────────
          _SectionCard(
            title: "SUPPLIER",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Supplier dropdown
                Obx(() => DropdownButtonFormField<String>(
                  value: c.selectedSupplier.value?.id,
                  isExpanded: true,
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput(
                    "Select Supplier *",
                    prefix: const Icon(Icons.business_outlined,
                        size: 18, color: ErpColors.textSecondary),
                  ),
                  items: c.suppliers
                      .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.name,
                      overflow: TextOverflow.ellipsis,
                      style: ErpTextStyles.fieldValue,
                    ),
                  ))
                      .toList(),
                  onChanged: (v) => c.selectedSupplier.value =
                      c.suppliers.firstWhereOrNull((s) => s.id == v),
                )),

                // Supplier info strip
                Obx(() {
                  final sup = c.selectedSupplier.value;
                  if (sup == null) return const SizedBox();
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: ErpColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: ErpColors.accentBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sup.gstin != null
                                ? "GSTIN: ${sup.gstin}"
                                : "No GSTIN on record",
                            style: const TextStyle(
                                color: ErpColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sup.phone != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            sup.phone!,
                            style: const TextStyle(
                                color: ErpColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Section: Line Items ──────────────────────────
          _SectionCard(
            title: "LINE ITEMS",
            titleSuffix: Obx(() => Text(
              "${c.rows.length} item${c.rows.length != 1 ? 's' : ''}",
              style: const TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            )),
            child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Item cards — one per row, vertical layout
                ...List.generate(c.rows.length, (i) => _ItemCard(
                  index: i,
                  row: c.rows[i],
                  materials: c.materials,
                  onRemove: () => c.removeRow(i),
                  onChanged: () => c.rows.refresh(),
                )),

                const SizedBox(height: 10),

                // Add item button
                OutlinedButton.icon(
                  onPressed: c.addRow,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ErpColors.accentBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.add,
                      size: 18, color: ErpColors.accentBlue),
                  label: const Text(
                    "Add Line Item",
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ],
            )),
          ),

          const SizedBox(height: 14),

          // ── Order Summary ────────────────────────────────
          Obx(() {
            final validRows = c.rows
                .where((r) => r.material != null && r.lineTotal > 0)
                .toList();
            if (validRows.isEmpty) return const SizedBox();

            final total = validRows.fold<double>(0, (s, r) => s + r.lineTotal);

            return _SectionCard(
              title: "ORDER SUMMARY",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary rows
                  ...validRows.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Material name (full width, safe)
                        Text(
                          r.material?.name ?? "",
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 3),
                        // Qty × price → total
                        Row(
                          children: [
                            Text(
                              "${r.quantity} kg  ×  ₹${r.price}",
                              style: const TextStyle(
                                  color: ErpColors.textSecondary,
                                  fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              "₹${r.lineTotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: ErpColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Divider(
                            height: 1, color: ErpColors.borderLight),
                      ],
                    ),
                  )),

                  const SizedBox(height: 8),

                  // Grand total row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "GRAND TOTAL",
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            color: ErpColors.textPrimary),
                      ),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: ErpColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // bottom breathing room for footer
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Item Card — vertical layout, zero horizontal overflow risk ──
class _ItemCard extends StatelessWidget {
  final int index;
  final POItemRow row;
  final List<MaterialMini> materials;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemCard({
    required this.index,
    required this.row,
    required this.materials,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card header: index badge + delete ──────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "LINE ITEM",
                  style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ErpColors.errorRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: ErpColors.errorRed, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // ── Card body ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Material dropdown — full width
                const _Label("MATERIAL *"),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: row.material?.id,
                  isExpanded: true,
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput("Select raw material"),
                  items: materials
                      .map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      "${m.name}${m.unit != null ? '  (${m.unit})' : ''}",
                      overflow: TextOverflow.ellipsis,
                      style: ErpTextStyles.fieldValue,
                    ),
                  ))
                      .toList(),
                  onChanged: (v) {
                    row.material =
                        materials.firstWhereOrNull((m) => m.id == v);
                    onChanged();
                  },
                ),

                const SizedBox(height: 12),

                // Row 2: Price + Quantity side by side
                // Each gets exactly half the width — safe on any screen
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label("PRICE (₹/UNIT)"),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: row.priceCtrl,
                            style: ErpTextStyles.fieldValue,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                            ErpDecorations.formInput("0.00").copyWith(
                              prefixText: "₹ ",
                              prefixStyle: const TextStyle(
                                  color: ErpColors.textSecondary,
                                  fontSize: 13),
                            ),
                            onChanged: (_) => onChanged(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label("QUANTITY"),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: row.quantityCtrl,
                            style: ErpTextStyles.fieldValue,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                            ErpDecorations.formInput("0").copyWith(
                              suffixText: "kg",
                              suffixStyle: const TextStyle(
                                  color: ErpColors.textSecondary,
                                  fontSize: 12),
                            ),
                            onChanged: (_) => onChanged(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Row 3: Line total — shown only when both price & qty filled
                if (row.lineTotal > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: ErpColors.accentBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Line Total",
                          style: TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          "₹${row.lineTotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: ErpColors.accentBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Received qty notice for edit mode
                if (row.receivedQuantity > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: ErpColors.warningAmber.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: ErpColors.warningAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 13, color: ErpColors.warningAmber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Already received: ${row.receivedQuantity} kg — quantity cannot go below this",
                            style: const TextStyle(
                                color: ErpColors.warningAmber, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky footer bar ──────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  final AddPOController c;
  final POFormMode mode;
  const _FooterBar({required this.c, required this.mode});

  String get _submitLabel {
    switch (mode) {
      case POFormMode.edit:   return "Update";
      case POFormMode.clone:  return "Clone";
      case POFormMode.create: return "Create PO";
    }
  }

  IconData get _submitIcon {
    switch (mode) {
      case POFormMode.edit:   return Icons.save_outlined;
      case POFormMode.clone:  return Icons.copy_all_outlined;
      case POFormMode.create: return Icons.check;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: const Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Obx(() {
        final total = c.rows.fold<double>(0, (s, r) => s + r.lineTotal);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOTAL ORDER VALUE",
                  style: TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "₹${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: ErpColors.accentBlue,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Buttons row — Cancel takes 1/3, Submit takes 2/3
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ErpColors.borderMid),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                            color: ErpColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed:
                      c.isSubmitting.value ? null : c.submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.accentBlue,
                        disabledBackgroundColor:
                        ErpColors.accentBlue.withOpacity(0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: c.isSubmitting.value
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : Icon(_submitIcon, size: 16, color: Colors.white),
                      label: Text(
                        _submitLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────

/// Section card — replaces ErpFormSection to avoid fixed header width issues
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? titleSuffix;

  const _SectionCard({
    required this.title,
    required this.child,
    this.titleSuffix,
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
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border:
              Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                    width: 3,
                    height: 13,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue,
                      borderRadius: BorderRadius.circular(2),
                    )),
                Text(title, style: ErpTextStyles.sectionHeader),
                if (titleSuffix != null) ...[
                  const Spacer(),
                  titleSuffix!,
                ],
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Uppercase field label
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: ErpTextStyles.fieldLabel);
  }
}
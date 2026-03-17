import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart';
import 'package:production/src/features/Orders/models/elasticLite.dart';
import 'package:production/src/features/Orders/models/order_elastic_row.dart';
import 'package:production/src/features/Orders/screens/searchable_picker.dart';

import '../../PurchaseOrder/services/theme.dart';

class AddOrderPage extends StatefulWidget {
  const AddOrderPage({super.key});

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  late final AddOrderController c;

  @override
  void initState() {
    super.initState();
    Get.delete<AddOrderController>(force: true);
    c = Get.put(AddOrderController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  @override
  void dispose() {
    Get.delete<AddOrderController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Order', style: ErpTextStyles.pageTitle),
            Text('Orders  ›  Create New',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      // No loading gate — we no longer pre-load customers/elastics
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                _orderInfoCard(context),
                const SizedBox(height: 12),
                _customerCard(context),
                const SizedBox(height: 12),
                _elasticsCard(context),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          _footerBar(),
        ],
      ),
    );
  }

  // ── Order Info ──────────────────────────────────────────────
  Widget _orderInfoCard(BuildContext ctx) {
    return ErpSectionCard(
      title: 'ORDER INFORMATION',
      icon: Icons.receipt_long_outlined,
      child: Column(children: [
        _ErpField(
            label: 'PO Number *',
            ctrl: c.poCtrl,
            prefix: Icons.tag_outlined),
        const SizedBox(height: 10),
        _ErpField(
            label: 'Description',
            ctrl: c.descCtrl,
            prefix: Icons.notes_outlined,
            maxLines: 2),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _DatePicker(
                  label: 'Order Date', date: c.orderDate, ctx: ctx)),
          const SizedBox(width: 10),
          Expanded(
              child: _DatePicker(
                  label: 'Supply Date',
                  date: c.supplyDate,
                  ctx: ctx,
                  accentColor: ErpColors.warningAmber)),
        ]),
      ]),
    );
  }

  // ── Customer ────────────────────────────────────────────────
  Widget _customerCard(BuildContext ctx) {
    return ErpSectionCard(
      title: 'CUSTOMER',
      icon: Icons.business_outlined,
      child: Obx(() => _PickerField(
        label: 'Select Customer',
        selected: c.selectedCustomerName.value,
        icon: Icons.person_outline,
        onTap: () async {
          final sel = await showSearchablePicker<CustomerLite>(
            context: ctx,
            title: 'Select Customer',
            label: (cu) => cu.name,
            // API search — calls controller on every debounced keystroke
            onSearch: c.searchCustomers,
            itemIcon: Icons.person_outline,
          );
          if (sel != null) {
            c.selectedCustomerId.value   = sel.id;
            c.selectedCustomerName.value = sel.name;
          }
        },
      )),
    );
  }

  // ── Elastics ────────────────────────────────────────────────
  Widget _elasticsCard(BuildContext ctx) {
    return ErpSectionCard(
      title: 'ELASTICS ORDERED',
      icon: Icons.layers_outlined,
      child: Column(children: [
        Obx(() => Column(
          children: List.generate(c.elasticRows.length, (i) {
            final row = c.elasticRows[i];
            return _ElasticRowCard(
              index:    i,
              row:      row,
              ctx:      ctx,
              // Pass the search callback instead of a static list
              onSearchElastics: c.searchElastics,
              onRemove:  () => c.removeElasticRow(i),
              onChanged: () => c.elasticRows.refresh(),
            );
          }),
        )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: c.addElasticRow,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.accentBlue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.add,
                size: 16, color: ErpColors.accentBlue),
            label: const Text('Add Elastic',
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Footer ──────────────────────────────────────────────────
  Widget _footerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
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
      child: Row(children: [
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
              child: const Text('Cancel',
                  style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Obx(() => SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed:
              c.isSubmitting.value ? null : c.submitOrder,
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
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check,
                  size: 16, color: Colors.white),
              label: Text(
                c.isSubmitting.value ? 'Saving…' : 'Create Order',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          )),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Elastic row card
//  Receives onSearchElastics callback instead of a static list
// ══════════════════════════════════════════════════════════════



class _ElasticRowCard extends StatelessWidget {
  final int index;
  final OrderElasticRow row;
  final BuildContext ctx;
  final Future<List<ElasticLite>> Function(String) onSearchElastics;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ElasticRowCard({
    required this.index,
    required this.row,
    required this.ctx,
    required this.onSearchElastics,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(children: [
        // Row header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Elastic',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: ErpColors.textPrimary)),
            ),
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
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Elastic picker — uses API search
            Obx(() => _PickerField(
              label: 'Select Elastic',
              selected: row.selectedElasticName.value,
              icon: Icons.layers_outlined,
              onTap: () async {
                final sel = await showSearchablePicker<ElasticLite>(
                  context: ctx,
                  title: 'Select Elastic',
                  label: (e) => e.name,
                  onSearch: onSearchElastics,
                );
                if (sel != null) {
                  row.elasticId.value           = sel.id;
                  row.selectedElasticName.value = sel.name;
                  onChanged();
                }
              },
            )),
            const SizedBox(height: 8),
            TextFormField(
              controller: row.qtyCtrl,
              keyboardType: TextInputType.number,
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput(
                'Quantity (meters)',
                prefix: const Icon(Icons.straighten,
                    size: 18, color: ErpColors.textMuted),
              ),
              onChanged: (_) => onChanged(),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Shared small widgets
// ══════════════════════════════════════════════════════════════

class _ErpField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData? prefix;
  final int maxLines;
  const _ErpField({
    required this.label,
    required this.ctrl,
    this.prefix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput(
        label,
        prefix: prefix != null
            ? Icon(prefix, size: 18, color: ErpColors.textMuted)
            : null,
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final Rx<DateTime> date;
  final BuildContext ctx;
  final Color accentColor;

  const _DatePicker({
    required this.label,
    required this.date,
    required this.ctx,
    this.accentColor = ErpColors.accentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx,
          initialDate: date.value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (d != null) date.value = d;
      },
      child: Obx(() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ErpTextStyles.fieldLabel),
                const SizedBox(height: 1),
                Text(
                  DateFormat('dd MMM yyyy').format(date.value),
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ]),
      )),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? selected;
  final IconData icon;
  final VoidCallback onTap;
  const _PickerField({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          border: Border.all(
            color: selected != null
                ? ErpColors.accentBlue.withOpacity(0.4)
                : ErpColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color: selected != null
                  ? ErpColors.accentBlue
                  : ErpColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: selected != null
                          ? ErpColors.accentBlue
                          : ErpColors.textSecondary,
                      fontSize: selected != null ? 10 : 13,
                      fontWeight: FontWeight.w500),
                ),
                if (selected != null) ...[
                  const SizedBox(height: 1),
                  Text(selected!,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ErpColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (selected == null)
            const Text('Tap to search',
                style: TextStyle(
                    color: ErpColors.textMuted, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down,
              color: ErpColors.textMuted, size: 20),
        ]),
      ),
    );
  }
}
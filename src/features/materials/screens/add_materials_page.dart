import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/rawMaterial_controller.dart';
import '../models/RawMaterial.dart';


// ══════════════════════════════════════════════════════════════
//  ADD RAW MATERIAL PAGE
//
//  FIX: original Get.put(RawMaterialController()) at class field
//       in StatefulWidget → stale controller on re-navigation.
//       Now uses initState() with Get.delete(force:true).
//  FIX: original _submit() called double.parse() without
//       validation gate → FormatException crash on empty fields.
//  FIX: original Get.off(RawMaterialListPage()) after save →
//       replaced with onSuccess callback → Navigator.of(context).pop(true).
//  FIX: SearchableSupplierDropdown in dropdown.dart referenced
//       'SupplierController' which doesn't exist in the codebase
//       → compile error. Replaced with inline supplier list built
//       from AddMaterialController.
// ══════════════════════════════════════════════════════════════

class AddRawMaterialPage extends StatefulWidget {
  const AddRawMaterialPage({super.key});

  @override
  State<AddRawMaterialPage> createState() => _AddRawMaterialPageState();
}

class _AddRawMaterialPageState extends State<AddRawMaterialPage> {
  late final AddMaterialController c;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // FIX: delete stale instance before creating fresh one
    Get.delete<AddMaterialController>(force: true);
    c = Get.put(AddMaterialController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1: Basic Info ──────────────────────
              ErpSectionCard(
                title: 'MATERIAL INFO',
                icon: Icons.grain_rounded,
                child: Column(children: [
                  TextFormField(
                    controller: c.nameCtrl,
                    style: ErpTextStyles.fieldValue,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                    ErpDecorations.formInput('Material Name *'),
                    validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  // Category dropdown
                  Obx(() => DropdownButtonFormField<String>(
                    value: c.selectedCategory.value,
                    decoration: ErpDecorations.formInput('Category *'),
                    style: ErpTextStyles.fieldValue,
                    dropdownColor: ErpColors.bgSurface,
                    items: AddMaterialController.kCategories
                        .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _catColor(cat),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(cat),
                      ]),
                    ))
                        .toList(),
                    onChanged: (v) =>
                    c.selectedCategory.value = v!,
                  )),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Section 2: Supplier ────────────────────────
              ErpSectionCard(
                title: 'SUPPLIER',
                icon: Icons.business_outlined,
                child: Obx(() {
                  if (c.isLoadingSup.value) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            color: ErpColors.accentBlue, strokeWidth: 2),
                      ),
                    );
                  }
                  if (c.suppliers.isEmpty) {
                    return Column(children: [
                      const Text('No suppliers found',
                          style: TextStyle(
                              color: ErpColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => c.searchSuppliers(''),
                        icon: const Icon(Icons.refresh,
                            size: 14, color: ErpColors.accentBlue),
                        label: const Text('Retry',
                            style: TextStyle(
                                color: ErpColors.accentBlue,
                                fontSize: 12)),
                      ),
                    ]);
                  }
                  return DropdownButtonFormField<SupplierDropdownItem>(
                    value: c.suppliers
                        .firstWhereOrNull((s) =>
                    s.id == c.selectedSupplierId.value),
                    decoration:
                    ErpDecorations.formInput('Supplier *'),
                    style: ErpTextStyles.fieldValue,
                    dropdownColor: ErpColors.bgSurface,
                    items: c.suppliers
                        .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) c.selectSupplier(v);
                    },
                    validator: (_) => c.selectedSupplierId.value == null
                        ? 'Select a supplier'
                        : null,
                  );
                }),
              ),
              const SizedBox(height: 12),

              // ── Section 3: Stock & Price ───────────────────
              ErpSectionCard(
                title: 'STOCK & PRICING',
                icon: Icons.inventory_2_outlined,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: c.stockCtrl,
                        style: ErpTextStyles.fieldValue,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: ErpDecorations.formInput(
                            'Opening Stock (kg)'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: c.minStockCtrl,
                        style: ErpTextStyles.fieldValue,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration:
                        ErpDecorations.formInput('Min Stock (kg)'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: c.priceCtrl,
                    style: ErpTextStyles.fieldValue,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: ErpDecorations.formInput(
                        'Price per kg (₹)'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: c.isSaving.value ? null : _submit,
                  icon: c.isSaving.value
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.save_rounded,
                      color: Colors.white, size: 18),
                  label: Text(
                      c.isSaving.value
                          ? 'Saving…'
                          : 'Save Material',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              )),
            ],
          ),
        ),
      ),
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
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Raw Material', style: ErpTextStyles.pageTitle),
          Text('Raw Materials  ›  Add',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  void _submit() {
    // FIX: validation gate before any parsing — no FormatException
    if (!_formKey.currentState!.validate()) return;
    if (c.selectedSupplierId.value == null) {
      Get.snackbar('Validation', 'Please select a supplier',
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    c.save();
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'warp':      return const Color(0xFF1D6FEB);
      case 'weft':      return const Color(0xFF7C3AED);
      case 'covering':  return const Color(0xFF0891B2);
      case 'Rubber':    return const Color(0xFFD97706);
      case 'Chemicals': return const Color(0xFFDC2626);
      default:          return const Color(0xFF5A6A85);
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controller/edit_supplier_controller.dart';
import '../widgets/supplier_form_fields.dart';

// ══════════════════════════════════════════════════════════════
//  EDIT SUPPLIER
//
//  What is on file, under the supplier's own field names (see the
//  controller), and the GSTIN with "Verify" beside it.
// ══════════════════════════════════════════════════════════════
class EditSupplierPage extends StatefulWidget {
  final Map supplier;

  const EditSupplierPage({super.key, required this.supplier});

  @override
  State<EditSupplierPage> createState() => _EditSupplierPageState();
}

class _EditSupplierPageState extends State<EditSupplierPage> {
  late final EditSupplierController c;

  @override
  void initState() {
    super.initState();
    // This supplier's form, not the one left from the supplier opened before.
    Get.delete<EditSupplierController>(force: true);
    c = Get.put(EditSupplierController(widget.supplier));
  }

  @override
  void dispose() {
    Get.delete<EditSupplierController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(title: 'Edit Supplier', subtitle: (widget.supplier['name'] ?? 'Supplier').toString()),
      body: Form(
        key: c.formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    ErpSectionCard(
                      title: 'BASIC DETAILS',
                      icon: Icons.business_outlined,
                      child: Column(
                        children: [
                          SupplierField(
                            label: 'Supplier Name *',
                            controller: c.nameCtrl,
                            required: true,
                            icon: Icons.storefront_outlined,
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          SupplierField(
                            label: 'Contact Person',
                            controller: c.contactCtrl,
                            icon: Icons.badge_outlined,
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          SupplierField(
                            label: 'Phone Number',
                            controller: c.phoneCtrl,
                            keyboard: TextInputType.phone,
                            icon: Icons.phone_outlined,
                          ),
                          const SizedBox(height: 10),
                          SupplierField(
                            label: 'Email',
                            controller: c.emailCtrl,
                            keyboard: TextInputType.emailAddress,
                            icon: Icons.email_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ErpSectionCard(
                      title: 'GST & ADDRESS',
                      icon: Icons.receipt_long_outlined,
                      child: SupplierGstFields(
                        gstin: c.gstinCtrl,
                        name: c.nameCtrl,
                        address: c.addressCtrl,
                        pan: c.panCtrl,
                        gstRegistration: c.gstRegistration,
                        showEarlier: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ErpSectionCard(
                      title: 'TERMS & STATUS',
                      icon: Icons.schedule_outlined,
                      child: Column(
                        children: [
                          SupplierField(
                            label: 'Bills fall due after (days)',
                            controller: c.paymentDaysCtrl,
                            keyboard: TextInputType.number,
                            icon: Icons.event_outlined,
                            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              return (n == null || n > 365) ? '0 to 365 days' : null;
                            },
                          ),
                          const SizedBox(height: 6),
                          // A row and a switch, not a SwitchListTile: a list
                          // tile paints on the page behind this card, where
                          // the card's own colour hides it.
                          Obx(() => Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Active', style: ErpTextStyles.fieldValue),
                                        Text(
                                          c.isActive.value ? 'Offered when raising a purchase order' : 'Kept on file, no longer offered',
                                          style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    key: const Key('supplier-active'),
                                    value: c.isActive.value,
                                    onChanged: (v) => c.isActive.value = v,
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SupplierFooterBar(saveLabel: 'Update Supplier', loading: c.loading, onSave: c.updateSupplier),
          ],
        ),
      ),
    );
  }
}

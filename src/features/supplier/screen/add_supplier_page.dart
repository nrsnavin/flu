import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controller/add_supplier_controller.dart';
import '../widgets/supplier_form_fields.dart';

// ══════════════════════════════════════════════════════════════
//  ADD SUPPLIER
//
//  Name and phone, then the GSTIN with "Verify" beside it: one tap asks
//  the GST system who the number belongs to and fills the name, the
//  address and the PAN.
// ══════════════════════════════════════════════════════════════
class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  late final AddSupplierController c;

  @override
  void initState() {
    super.initState();
    // A form of its own each time it is opened, not the last one's text.
    Get.delete<AddSupplierController>(force: true);
    c = Get.put(AddSupplierController());
  }

  @override
  void dispose() {
    Get.delete<AddSupplierController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: 'New Supplier', subtitle: 'Suppliers  ›  Add New'),
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
                            label: 'Phone Number *',
                            controller: c.phoneCtrl,
                            required: true,
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
                          const SizedBox(height: 10),
                          SupplierField(
                            label: 'Contact Person',
                            controller: c.contactPersonCtrl,
                            icon: Icons.badge_outlined,
                            capitalization: TextCapitalization.words,
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
                        // As before: a GSTIN is asked for — unless they
                        // are marked as not registered.
                        requireGstin: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SupplierFooterBar(saveLabel: 'Save Supplier', loading: c.loading, onSave: c.submit),
          ],
        ),
      ),
    );
  }
}

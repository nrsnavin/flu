import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';


import '../controllers/customer_controller.dart';
class EditCustomerPage extends StatelessWidget {
  // FIX: typed as Map<String, dynamic> — no more RxMap type mismatch
  final Map<String, dynamic> customer;
  const EditCustomerPage({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    Get.delete<EditCustomerController>(force: true);
    final c = Get.put(EditCustomerController(
      customer: customer,
      onSuccess: () => Navigator.of(context).pop(),
    ));

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
        title: Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Customer",
                  style: ErpTextStyles.pageTitle,
                  overflow: TextOverflow.ellipsis),
              Text(
                customer['name'] ?? 'Customer',
                style: const TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Form(
        key: c.formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    // ── Basic details ──────────────────────
                    _SectionCard(
                      title: "BASIC DETAILS",
                      icon: Icons.business_outlined,
                      child: Column(
                        children: [
                          _Field(
                              label: "Customer Name *",
                              ctrl: c.nameCtrl,
                              required: true,
                              prefix: Icons.person_outline),
                          const SizedBox(height: 10),
                          _Field(
                              label: "Email Address",
                              ctrl: c.emailCtrl,
                              keyboard: TextInputType.emailAddress,
                              prefix: Icons.email_outlined),
                          const SizedBox(height: 10),
                          _Field(
                              label: "GSTIN",
                              ctrl: c.gstinCtrl,
                              prefix: Icons.receipt_outlined),
                          const SizedBox(height: 10),
                          _StatusDropdown(c: c),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Primary contact ────────────────────
                    _SectionCard(
                      title: "PRIMARY CONTACT",
                      icon: Icons.person_pin_outlined,
                      child: Column(
                        children: [
                          _Field(
                              label: "Contact Name *",
                              ctrl: c.contactNameCtrl,
                              required: true,
                              prefix: Icons.badge_outlined),
                          const SizedBox(height: 10),
                          _Field(
                              label: "Phone Number *",
                              ctrl: c.phoneCtrl,
                              required: true,
                              keyboard: TextInputType.phone,
                              prefix: Icons.phone_outlined),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Commercial ─────────────────────────
                    _SectionCard(
                      title: "COMMERCIAL",
                      icon: Icons.account_balance_outlined,
                      child: _PaymentTermsDropdown(c: c),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Footer bar ─────────────────────────────────
            _FooterBar(c: c),
          ],
        ),
      ),
    );
  }
}

// ── Section card ───────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

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
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                    width: 3,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue,
                      borderRadius: BorderRadius.circular(2),
                    )),
                Icon(icon, size: 13, color: ErpColors.textSecondary),
                const SizedBox(width: 6),
                Text(title, style: ErpTextStyles.sectionHeader),
              ],
            ),
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

// ── Text field ─────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final TextInputType keyboard;
  final IconData? prefix;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
    this.keyboard = TextInputType.text,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: ErpTextStyles.fieldValue,
      validator: required
          ? (v) =>
      (v == null || v.trim().isEmpty) ? "Required" : null
          : null,
      decoration: ErpDecorations.formInput(
        label,
        prefix: prefix != null
            ? Icon(prefix, size: 18, color: ErpColors.textMuted)
            : null,
      ),
    );
  }
}

// ── Status dropdown ────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final EditCustomerController c;
  const _StatusDropdown({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => DropdownButtonFormField<String>(
      value: c.status.value,
      isExpanded: true,
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput("Status",
          prefix: const Icon(Icons.toggle_on_outlined,
              size: 18, color: ErpColors.textMuted)),
      items: const [
        DropdownMenuItem(value: "Active",   child: Text("Active")),
        DropdownMenuItem(value: "Inactive", child: Text("Inactive")),
      ],
      onChanged: (v) => c.status.value = v!,
    ));
  }
}

// ── Payment terms dropdown ─────────────────────────────────────
class _PaymentTermsDropdown extends StatelessWidget {
  final EditCustomerController c;
  const _PaymentTermsDropdown({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => DropdownButtonFormField<String>(
      value: c.paymentTerms.value,
      isExpanded: true,
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput("Payment Terms",
          prefix: const Icon(Icons.schedule_outlined,
              size: 18, color: ErpColors.textMuted)),
      items: const [
        DropdownMenuItem(value: "Advance", child: Text("Advance")),
        DropdownMenuItem(value: "15",      child: Text("15 Days")),
        DropdownMenuItem(value: "30",      child: Text("30 Days")),
        DropdownMenuItem(value: "45",      child: Text("45 Days")),
        DropdownMenuItem(value: "60",      child: Text("60 Days")),
      ],
      onChanged: (v) => c.paymentTerms.value = v!,
    ));
  }
}

// ── Footer bar ─────────────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  final EditCustomerController c;
  const _FooterBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: const Border(
            top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side:
                  const BorderSide(color: ErpColors.borderMid),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text("Cancel",
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
                onPressed: c.loading.value
                    ? null
                    : c.updateCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  disabledBackgroundColor:
                  ErpColors.accentBlue.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: c.loading.value
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Icon(Icons.save_outlined,
                    size: 16, color: Colors.white),
                label: const Text(
                  "Update Customer",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}
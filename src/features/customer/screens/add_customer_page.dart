import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/customer_controller.dart';



class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});
  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  late final CustomerController _c;

  @override
  void initState() {
    super.initState();
    Get.delete<CustomerController>(force: true);
    _c = Get.put(CustomerController(
      onSuccess: () => Navigator.of(context).pop(),
    ));
  }

  @override
  void dispose() {
    Get.delete<CustomerController>(force: true);
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
            Text("New Customer", style: ErpTextStyles.pageTitle),
            Text(
              "Customers  ›  Add New",
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Form(
        key: _formKey,
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
                            ctrl: _c.nameCtrl,
                            required: true,
                            prefix: Icons.person_outline,
                          ),
                          const SizedBox(height: 10),
                          _Field(
                            label: "Email Address",
                            ctrl: _c.emailCtrl,
                            keyboard: TextInputType.emailAddress,
                            prefix: Icons.email_outlined,
                          ),
                          const SizedBox(height: 10),
                          _Field(
                            label: "GSTIN",
                            ctrl: _c.gstinCtrl,
                            prefix: Icons.receipt_outlined,
                            hint: "e.g. 29ABCDE1234F1Z5",
                          ),
                          const SizedBox(height: 10),
                          _StatusDropdown(c: _c),
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
                            ctrl: _c.contactNameCtrl,
                            required: true,
                            prefix: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 10),
                          _Field(
                            label: "Phone Number *",
                            ctrl: _c.phoneCtrl,
                            required: true,
                            keyboard: TextInputType.phone,
                            prefix: Icons.phone_outlined,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Commercial ─────────────────────────
                    _SectionCard(
                      title: "COMMERCIAL",
                      icon: Icons.account_balance_outlined,
                      child: _PaymentTermsDropdown(c: _c),
                    ),

                    const SizedBox(height: 12),

                    // ── Purchase contact ───────────────────
                    _CollapsibleSection(
                      title: "PURCHASE CONTACT",
                      icon: Icons.shopping_cart_outlined,
                      child: _ContactBlock(
                        nameCtrl:   _c.purchaseNameCtrl,
                        mobileCtrl: _c.purchaseMobileCtrl,
                        emailCtrl:  _c.purchaseEmailCtrl,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Accounts contact ───────────────────
                    _CollapsibleSection(
                      title: "ACCOUNTS CONTACT",
                      icon: Icons.calculate_outlined,
                      child: _ContactBlock(
                        nameCtrl:   _c.accountNameCtrl,
                        mobileCtrl: _c.accountMobileCtrl,
                        emailCtrl:  _c.accountEmailCtrl,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Merchandiser contact ───────────────
                    _CollapsibleSection(
                      title: "MERCHANDISER CONTACT",
                      icon: Icons.store_outlined,
                      child: _ContactBlock(
                        nameCtrl:   _c.merchantNameCtrl,
                        mobileCtrl: _c.merchantMobileCtrl,
                        emailCtrl:  _c.merchantEmailCtrl,
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Footer bar ─────────────────────────────────
            _FooterBar(c: _c, formKey: _formKey),
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

// ── Collapsible optional section ───────────────────────────────
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _CollapsibleSection(
      {required this.title, required this.icon, required this.child});

  @override
  State<_CollapsibleSection> createState() =>
      _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: _expanded
                    ? const BorderRadius.vertical(
                    top: Radius.circular(8))
                    : BorderRadius.circular(8),
                border: _expanded
                    ? const Border(
                    bottom:
                    BorderSide(color: ErpColors.borderLight))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                      width: 3,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: ErpColors.borderMid,
                        borderRadius: BorderRadius.circular(2),
                      )),
                  Icon(widget.icon,
                      size: 13, color: ErpColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(widget.title,
                      style: ErpTextStyles.sectionHeader),
                  const Spacer(),
                  Text(
                    "OPTIONAL",
                    style: TextStyle(
                      fontSize: 9,
                      color: ErpColors.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: ErpColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

// ── Shared contact block ───────────────────────────────────────
class _ContactBlock extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController emailCtrl;
  const _ContactBlock(
      {required this.nameCtrl,
        required this.mobileCtrl,
        required this.emailCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(label: "Name", ctrl: nameCtrl, prefix: Icons.badge_outlined),
        const SizedBox(height: 10),
        _Field(
            label: "Mobile",
            ctrl: mobileCtrl,
            keyboard: TextInputType.phone,
            prefix: Icons.phone_outlined),
        const SizedBox(height: 10),
        _Field(
            label: "Email",
            ctrl: emailCtrl,
            keyboard: TextInputType.emailAddress,
            prefix: Icons.email_outlined),
      ],
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
  final String? hint;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
    this.keyboard = TextInputType.text,
    this.prefix,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: ErpTextStyles.fieldValue,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? "Required" : null
          : null,
      decoration: ErpDecorations.formInput(
        label,
        hint: hint,
        prefix: prefix != null
            ? Icon(prefix, size: 18, color: ErpColors.textMuted)
            : null,
      ),
    );
  }
}

// ── Status dropdown ────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final CustomerController c;
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
  final CustomerController c;
  const _PaymentTermsDropdown({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => DropdownButtonFormField<String>(
      value: c.paymentTerms.value,
      isExpanded: true,
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput("Payment Terms *",
          prefix: const Icon(Icons.schedule_outlined,
              size: 18, color: ErpColors.textMuted)),
      items: const [
        DropdownMenuItem(value: "Advance", child: Text("Advance")),
        DropdownMenuItem(value: "15",      child: Text("15 Days")),
        DropdownMenuItem(value: "30",      child: Text("30 Days")),
        DropdownMenuItem(value: "45",      child: Text("45 Days")),
        DropdownMenuItem(value: "60",      child: Text("60 Days")),
      ],
      validator: (v) =>
      (v == null || v.isEmpty) ? "Required" : null,
      onChanged: (v) => c.paymentTerms.value = v!,
    ));
  }
}

// ── Footer bar ─────────────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  final CustomerController c;
  final GlobalKey<FormState> formKey;
  const _FooterBar({required this.c, required this.formKey});

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
          // Cancel
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
                child: const Text("Cancel",
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Save
          Expanded(
            flex: 2,
            child: Obx(() => SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: c.loading.value
                    ? null
                    : () {
                  if (formKey.currentState!.validate()) {
                    c.submitCustomer();
                  }
                },
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
                    : const Icon(Icons.check,
                    size: 16, color: Colors.white),
                label: const Text(
                  "Save Customer",
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
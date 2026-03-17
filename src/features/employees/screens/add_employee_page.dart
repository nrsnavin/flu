import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';


import '../../PurchaseOrder/services/theme.dart';
import '../controllers/employee_controller.dart';
import '../models/employee.dart';


// ══════════════════════════════════════════════════════════════
//  ADD EMPLOYEE PAGE
//
//  BUGS FIXED:
//  1. employee_controller.dart called Get.off(Home()) after adding
//     — replaced with onSuccess callback → Navigator.of(context).pop(true).
//  2. 'aadhaar' key in toJson was wrong — schema field is 'aadhar'
//     (single 'a'). Fixed in model.
//  3. Get.put inside StatefulWidget without Get.delete first →
//     stale controller if page is re-opened.
// ══════════════════════════════════════════════════════════════

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  late final AddEmployeeController c;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _roleCtrl    = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  String? _selectedDept;

  static const List<String> _departments = [
    'weaving', 'warping', 'covering', 'finishing',
    'packing', 'checking', 'general', 'admin',
  ];

  @override
  void initState() {
    super.initState();
    Get.delete<AddEmployeeController>(force: true);
    c = Get.put(AddEmployeeController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    _aadhaarCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    c.addEmployee(EmployeeCreate(
      name:        _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      role:        _roleCtrl.text.trim(),
      department:  _selectedDept!,
      aadhaar:     _aadhaarCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // ── Identity ──────────────────────────────────────
            ErpSectionCard(
              title: 'EMPLOYEE IDENTITY',
              icon: Icons.person_outline_rounded,
              child: Column(children: [
                _field(
                  ctrl: _nameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. Ramesh Kumar',
                  icon: Icons.badge_outlined,
                  capitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 2) return 'At least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  ctrl: _phoneCtrl,
                  label: 'Phone Number',
                  hint: '10-digit mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 10) return 'Enter 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Aadhaar
                _field(
                  ctrl: _aadhaarCtrl,
                  label: 'Aadhaar Number',
                  hint: '12-digit Aadhaar',
                  icon: Icons.fingerprint_rounded,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 12) return 'Aadhaar must be 12 digits';
                    return null;
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Role & Dept ───────────────────────────────────
            ErpSectionCard(
              title: 'ROLE & DEPARTMENT',
              icon: Icons.work_outline_rounded,
              child: Column(children: [
                _field(
                  ctrl: _roleCtrl,
                  label: 'Role / Designation',
                  hint: 'e.g. Loom Operator',
                  icon: Icons.construction_outlined,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Department dropdown
                DropdownButtonFormField<String>(
                  value: _selectedDept,
                  isExpanded: true,
                  style: ErpTextStyles.fieldValue,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: ErpColors.textSecondary, size: 18),
                  decoration: ErpDecorations.formInput(
                    'Department',
                    prefix: const Icon(Icons.business_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                  hint: const Text('Select department',
                      style:
                      TextStyle(color: ErpColors.textMuted, fontSize: 12)),
                  items: _departments.map((d) {
                    final label = d[0].toUpperCase() + d.substring(1);
                    return DropdownMenuItem(
                      value: d,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedDept = v),
                  validator: (v) =>
                  v == null ? 'Please select a department' : null,
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────
            Obx(() => SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: c.isSaving.value ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  disabledBackgroundColor:
                  ErpColors.accentBlue.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: c.isSaving.value
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.save_outlined,
                    size: 19, color: Colors.white),
                label: Text(
                  c.isSaving.value ? 'Saving…' : 'Register Employee',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
            )),
          ]),
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
          Text('Register Employee', style: ErpTextStyles.pageTitle),
          Text('Employees  ›  New',
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

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:          ctrl,
      keyboardType:        keyboardType,
      inputFormatters:     formatters,
      textCapitalization:  capitalization,
      style:               ErpTextStyles.fieldValue,
      autovalidateMode:    AutovalidateMode.onUserInteraction,
      decoration: ErpDecorations.formInput(
        label,
        hint: hint,
        prefix: icon != null
            ? Icon(icon, size: 16, color: ErpColors.textMuted)
            : null,
      ),
      validator: validator,
    );
  }
}
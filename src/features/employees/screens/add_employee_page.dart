import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';


import '../../PurchaseOrder/services/theme.dart';
import '../controllers/employee_controller.dart';
import '../models/employee.dart';
import '../aadhaar_qr.dart';
import 'skill_questionnaire_form.dart';


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
  final _salaryCtrl  = TextEditingController(); // DAY-shift (12h) salary ₹
  final _skillData   = SkillProfileData();
  String? _selectedDept;

  // As on the Aadhaar card; its QR code can fill them.
  final _dobCtrl     = TextEditingController(); // shown DD/MM/YYYY
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String _dob = '';                               // kept YYYY-MM-DD
  String? _gender;
  // The card's QR code, scanned with consent, sent with the record; and what it said.
  String? _qr;
  (String, Color)? _qrNote;

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
    _salaryCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  /// The card's QR code: checked, and its details into the form.
  Future<void> _scanAadhaar() async {
    final typed = {
      if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phoneNumber': _phoneCtrl.text.trim(),
      if (_aadhaarCtrl.text.trim().isNotEmpty) 'aadhar': _aadhaarCtrl.text.trim(),
    };
    final out = await Navigator.of(context).push<AadhaarQrOutcome>(MaterialPageRoute(
      builder: (_) => AadhaarQrPage(personName: _nameCtrl.text.trim(), compare: typed),
    ));
    if (out == null || !out.fill || !mounted) return;
    final read = out.result.read;
    final f = read.fields;
    if (f == null) return;
    setState(() {
      final typedName = _nameCtrl.text.trim();
      if (typedName.isEmpty) _nameCtrl.text = f.name;
      if (f.dob != null) {
        _dob = f.dob!;
        _dobCtrl.text = dmy(f.dob);
      }
      if (f.gender != null) _gender = f.gender;
      if (f.address.isNotEmpty) _addressCtrl.text = f.address;
      if (f.pincode.isNotEmpty) _pincodeCtrl.text = f.pincode;
      if (read.aadhaar != null && _aadhaarCtrl.text.trim().isEmpty) _aadhaarCtrl.text = read.aadhaar!;
      _qr = read.kind == 'secure' ? out.qr : null;
      final w = signatureWords(read.signature);
      final notes = [w.title, ...matchLines(read, out.result.matches, onRecord: false).map((l) => l.text)];
      if (typedName.isNotEmpty && out.result.matches.name == 'different') notes.add('The card says "${f.name}"');
      _qrNote = (notes.join(' · '), w.color);
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dob) ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    final iso = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      _dob = iso;
      _dobCtrl.text = dmy(iso);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // Salary asked per DAY shift (12h), stored as Rs/hour for payroll.
    final shiftSalary = double.tryParse(_salaryCtrl.text.trim()) ?? 0;
    c.addEmployee(EmployeeCreate(
      name:        _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      role:        _roleCtrl.text.trim(),
      department:  _selectedDept!,
      aadhaar:     _aadhaarCtrl.text.trim(),
      hourlyRate:  shiftSalary > 0 ? shiftSalary / 12 : 0,
      skillProfile: _skillData.toJson(),
      dob:         _dob,
      gender:      _gender ?? '',
      address:     _addressCtrl.text.trim(),
      pincode:     _pincodeCtrl.text.trim(),
      aadhaarQr:   _qr,
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanAadhaar,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan Aadhaar QR', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                if (_qrNote != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_qrNote!.$1, style: TextStyle(fontSize: 11, color: _qrNote!.$2)),
                  ),
                ],
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      onTap: _pickDob,
                      style: ErpTextStyles.fieldValue,
                      decoration: ErpDecorations.formInput('Date of birth',
                          hint: 'DD/MM/YYYY',
                          prefix: Icon(Icons.cake_outlined, size: 16, color: ErpColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      isExpanded: true,
                      style: ErpTextStyles.fieldValue,
                      decoration: ErpDecorations.formInput('Gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Transgender / other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _field(
                  ctrl: _addressCtrl,
                  label: 'Address',
                  hint: 'As on the Aadhaar card',
                  icon: Icons.home_outlined,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _field(
                  ctrl: _pincodeCtrl,
                  label: 'Pin code',
                  hint: '6 digits',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    return v.trim().length == 6 ? null : 'Pin code must be 6 digits';
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
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: ErpColors.textSecondary, size: 18),
                  decoration: ErpDecorations.formInput(
                    'Department',
                    prefix: Icon(Icons.business_outlined,
                        size: 16, color: ErpColors.textMuted),
                  ),
                  hint: Text('Select department',
                      style:
                      TextStyle(color: ErpColors.textMuted, fontSize: 12)),
                  items: _departments.map((d) {
                    final label = d[0].toUpperCase() + d.substring(1);
                    return DropdownMenuItem(
                      value: d,
                      child: Text(label,
                          style: TextStyle(
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
            const SizedBox(height: 12),

            // ── Shift salary ──────────────────────────────────
            ErpSectionCard(
              title: 'SHIFT SALARY',
              icon: Icons.currency_rupee_rounded,
              child: _field(
                ctrl: _salaryCtrl,
                label: 'Shift salary (12h, Rs)',
                hint: 'e.g. 1200 — DAY and NIGHT are both 12h',
                icon: Icons.payments_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 0) return 'Enter a valid amount';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── Skill & performance questionnaire ─────────────
            SkillQuestionnaireSection(data: _skillData),
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
                  ErpColors.accentBlue.withValues(alpha: 0.5),
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
      title: Column(
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
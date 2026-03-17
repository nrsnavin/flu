import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_controller.dart';
import '../models/machine.dart';


// ══════════════════════════════════════════════════════════════
//  ADD MACHINE PAGE
//
//  BUGS FIXED FROM ORIGINAL:
//  1. Button label said "ADD EMPLOYEE" (copy-paste error) → "Add Machine"
//  2. Controller used Get.offAll(Home()) after success — replaced with
//     onSuccess callback → Navigator.of(context).pop(true).
//  3. elastics was a String field sent to the backend, but the
//     Machine schema stores elastics as [{elastic: ObjectId, head: Number}].
//     The field is removed from the create form — elastics are assigned
//     per-head during the weaving plan step, not at machine creation.
//  4. Get.put(MachineController()) inside a StatefulWidget without
//     Get.delete first → stale controller if the page is reopened.
// ══════════════════════════════════════════════════════════════

class AddMachinePage extends StatefulWidget {
  const AddMachinePage({super.key});

  @override
  State<AddMachinePage> createState() => _AddMachinePageState();
}

class _AddMachinePageState extends State<AddMachinePage> {
  late final AddMachineController c;
  final _formKey = GlobalKey<FormState>();

  final _idCtrl           = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _headsCtrl        = TextEditingController();
  final _hooksCtrl        = TextEditingController();
  final _dateCtrl         = TextEditingController();

  @override
  void initState() {
    super.initState();
    // FIX: delete stale instance before creating new
    Get.delete<AddMachineController>(force: true);
    c = Get.put(AddMachineController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _manufacturerCtrl.dispose();
    _headsCtrl.dispose();
    _hooksCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final machine = MachineCreate(
      machineCode:    _idCtrl.text.trim().toUpperCase(),
      manufacturer:   _manufacturerCtrl.text.trim(),
      noOfHeads:      int.parse(_headsCtrl.text.trim()),
      noOfHooks:      int.parse(_hooksCtrl.text.trim()),
      dateOfPurchase: _dateCtrl.text.trim().isNotEmpty
          ? _dateCtrl.text.trim()
          : null,
    );

    c.addMachine(machine);
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
            // ── Identity section ─────────────────────────────
            ErpSectionCard(
              title: 'MACHINE IDENTITY',
              icon: Icons.precision_manufacturing_outlined,
              child: Column(children: [
                _formField(
                  controller: _idCtrl,
                  label: 'Machine ID',
                  hint: 'e.g. LOOM-EL-01',
                  prefix: Icons.qr_code_2_outlined,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9\-_]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Machine ID is required';
                    }
                    if (v.trim().length < 3) {
                      return 'Must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _formField(
                  controller: _manufacturerCtrl,
                  label: 'Manufacturer',
                  hint: 'e.g. Lohia Corp, Santoni',
                  prefix: Icons.business_outlined,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Manufacturer is required'
                      : null,
                ),
                const SizedBox(height: 12),
                _formField(
                  controller: _dateCtrl,
                  label: 'Date of Purchase (optional)',
                  hint: 'e.g. 2022-03-15',
                  prefix: Icons.calendar_today_outlined,
                  readOnly: true,
                  onTap: () => _pickDate(context),
                  validator: null,
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Specifications section ────────────────────────
            ErpSectionCard(
              title: 'SPECIFICATIONS',
              icon: Icons.settings_outlined,
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: _formField(
                      controller: _headsCtrl,
                      label: 'No. of Heads',
                      hint: '8',
                      prefix: Icons.view_week_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final n = int.tryParse(v);
                        if (n == null || n <= 0) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _formField(
                      controller: _hooksCtrl,
                      label: 'No. of Hooks',
                      hint: '1200',
                      prefix: Icons.link_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final n = int.tryParse(v);
                        if (n == null || n <= 0) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 14),

            // ── Info notice ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: ErpColors.statusApprovedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ErpColors.statusApprovedBorder),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    size: 15, color: ErpColors.accentBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Elastic assignments are configured per-head during the weaving plan step, not at registration.',
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Submit button ────────────────────────────────
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
                  c.isSaving.value ? 'Registering…' : 'Register Machine',
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

  // ── AppBar ────────────────────────────────────────────────
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
          Text('Register Machine', style: ErpTextStyles.pageTitle),
          Text('Machines  ›  New',
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

  // ── Date picker ───────────────────────────────────────────
  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ErpColors.accentBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text =
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  // ── Reusable form field ───────────────────────────────────
  Widget _formField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller:         controller,
      keyboardType:       keyboardType,
      inputFormatters:    inputFormatters,
      readOnly:           readOnly,
      onTap:              onTap,
      style:              ErpTextStyles.fieldValue,
      autovalidateMode:   AutovalidateMode.onUserInteraction,
      decoration: ErpDecorations.formInput(
        label,
        hint: hint,
        prefix: prefix != null
            ? Icon(prefix, size: 16, color: ErpColors.textMuted)
            : null,
      ),
      validator: validator,
    );
  }
}
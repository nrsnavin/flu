import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../parties/models/gstin_models.dart';
import '../../parties/widgets/gstin_verify_field.dart';

// ══════════════════════════════════════════════════════════════
//  WHAT THE ADD AND EDIT SUPPLIER FORMS SHARE
//
//  The fields, laid out as the rest of the app lays out a form, and the
//  GSTIN with "Verify" beside it: one tap fills the supplier's name,
//  address and PAN from the GST registration, and marks a composition
//  dealer as one (their bills carry no input credit).
// ══════════════════════════════════════════════════════════════

const _registrationLabels = {
  'regular': 'Regular (charges GST)',
  'composition': 'Composition dealer (no GST)',
  'unregistered': 'Not registered (no GST)',
};

/// One text field of a supplier form.
class SupplierField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType keyboard;
  final IconData? icon;
  final String? hint;
  final int maxLines;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? formatters;
  final FormFieldValidator<String>? validator;

  const SupplierField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.keyboard = TextInputType.text,
    this.icon,
    this.hint,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.formatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: ErpTextStyles.fieldValue,
      minLines: 1,
      maxLines: maxLines,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
      decoration: ErpDecorations.formInput(
        label,
        hint: hint,
        prefix: icon == null ? null : Icon(icon, size: 18, color: ErpColors.textMuted),
      ),
    );
  }
}

/// GSTIN with Verify, what GST they may charge, the address and the PAN.
class SupplierGstFields extends StatelessWidget {
  final TextEditingController gstin;
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController pan;
  final RxString gstRegistration;

  /// An existing supplier: show the last check of its GSTIN.
  final bool showEarlier;

  /// Whether a GSTIN must be given for a supplier that charges GST.
  final bool requireGstin;

  const SupplierGstFields({
    super.key,
    required this.gstin,
    required this.name,
    required this.address,
    required this.pan,
    required this.gstRegistration,
    this.showEarlier = false,
    this.requireGstin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GstinVerifyField(
          kind: 'supplier',
          controller: gstin,
          label: requireGstin ? 'GSTIN *' : 'GSTIN',
          hint: '15 character GSTIN',
          showEarlier: showEarlier,
          validator: (v) {
            final g = normalGstin(v);
            // Asked for unless they are marked as not registered.
            if (g.isEmpty) return requireGstin && gstRegistration.value != 'unregistered' ? 'Required — or mark them as not registered' : null;
            return null;
          },
          targets: [
            GstinFieldTarget(label: 'Supplier name', part: 'name', controller: name),
            // One address field here: street, town, state and PIN on one line.
            GstinFieldTarget(label: 'Address', part: 'fullAddress', controller: address),
            GstinFieldTarget(label: 'PAN', part: 'pan', controller: pan),
          ],
          // Regular or composition is the registration's to say.
          facts: (fill) {
            if (gstRegistration.value == fill.gstRegistration) return const [];
            gstRegistration.value = fill.gstRegistration;
            return [fill.gstRegistration == 'composition' ? 'GST registration (composition dealer)' : 'GST registration (regular)'];
          },
        ),
        const SizedBox(height: 10),
        Obx(() => DropdownButtonFormField<String>(
              key: ValueKey('gst-registration-${gstRegistration.value}'),
              initialValue: gstRegistration.value,
              isExpanded: true,
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput('GST registration',
                  prefix: Icon(Icons.account_balance_outlined, size: 18, color: ErpColors.textMuted)),
              items: [
                for (final e in _registrationLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => gstRegistration.value = v ?? 'regular',
            )),
        const SizedBox(height: 10),
        SupplierField(
          label: 'Address',
          controller: address,
          icon: Icons.location_on_outlined,
          maxLines: 3,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 10),
        SupplierField(
          label: 'PAN',
          controller: pan,
          icon: Icons.badge_outlined,
          hint: 'AAAPS1234F',
          capitalization: TextCapitalization.characters,
          formatters: [LengthLimitingTextInputFormatter(10)],
          validator: (v) => (v == null || v.trim().isEmpty || RegExp(r'^[A-Za-z]{5}\d{4}[A-Za-z]$').hasMatch(v.trim()))
              ? null
              : 'A PAN is 5 letters, 4 digits, 1 letter',
        ),
      ],
    );
  }
}

/// Cancel and Save, pinned under the form.
class SupplierFooterBar extends StatelessWidget {
  final String saveLabel;
  final RxBool loading;
  final VoidCallback onSave;
  const SupplierFooterBar({super.key, required this.saveLabel, required this.loading, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border(top: BorderSide(color: ErpColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ErpColors.borderMid),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('Cancel', style: TextStyle(color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Obx(() => SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: loading.value ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue,
                      disabledBackgroundColor: ErpColors.accentBlue.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: loading.value
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16, color: Colors.white),
                    label: Text(saveLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                )),
          ),
        ],
      ),
    );
  }
}

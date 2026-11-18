import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../parties/widgets/gstin_verify_field.dart';

// ══════════════════════════════════════════════════════════════
//  A CUSTOMER'S GSTIN, BILLING ADDRESS AND PAN — add and edit forms
//
//  The phone's customer form had a name, a GSTIN and contacts, and no
//  address at all: a customer added here printed on its challans and
//  invoices with no address, and its e-invoice was refused for want of
//  a PIN code. These are the fields the web form has, and the ones
//  "Verify" beside the GSTIN fills from the GST registration.
// ══════════════════════════════════════════════════════════════

/// The GSTIN with "Verify" beside it, filling the customer's name,
/// billing address and PAN from the registration.
class CustomerGstinField extends StatelessWidget {
  final TextEditingController gstin;
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController pincode;
  final TextEditingController stateCode;
  final TextEditingController pan;

  /// An existing customer: show the last check of its GSTIN.
  final bool showEarlier;
  final String? hint;

  const CustomerGstinField({
    super.key,
    required this.gstin,
    required this.name,
    required this.address,
    required this.city,
    required this.pincode,
    required this.stateCode,
    required this.pan,
    this.showEarlier = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return GstinVerifyField(
      kind: 'customer',
      controller: gstin,
      hint: hint,
      showEarlier: showEarlier,
      targets: [
        GstinFieldTarget(label: 'Customer name', part: 'name', controller: name),
        GstinFieldTarget(label: 'Billing address', part: 'address', controller: address),
        GstinFieldTarget(label: 'City', part: 'city', controller: city),
        GstinFieldTarget(label: 'PIN code', part: 'pincode', controller: pincode),
        GstinFieldTarget(label: 'GST state code', part: 'stateCode', controller: stateCode),
        GstinFieldTarget(label: 'PAN', part: 'pan', controller: pan),
      ],
    );
  }
}

/// Billing address, city, PIN code, GST state code and PAN.
class CustomerAddressFields extends StatelessWidget {
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController pincode;
  final TextEditingController stateCode;
  final TextEditingController pan;

  const CustomerAddressFields({
    super.key,
    required this.address,
    required this.city,
    required this.pincode,
    required this.stateCode,
    required this.pan,
  });

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) => ErpDecorations.formInput(
        label,
        hint: hint,
        prefix: icon == null ? null : Icon(icon, size: 18, color: ErpColors.textMuted),
      );

  /// Blank is allowed; anything typed must be the whole thing.
  FormFieldValidator<String> _optional(RegExp pattern, String message) =>
      (v) => (v == null || v.trim().isEmpty || pattern.hasMatch(v.trim())) ? null : message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: address,
          style: ErpTextStyles.fieldValue,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.words,
          decoration: _decoration('Billing address', hint: 'Street, area', icon: Icons.location_on_outlined),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: city,
          style: ErpTextStyles.fieldValue,
          textCapitalization: TextCapitalization.words,
          decoration: _decoration('City', icon: Icons.location_city_outlined),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: pincode,
                style: ErpTextStyles.fieldValue,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                validator: _optional(RegExp(r'^\d{6}$'), '6 digits'),
                decoration: _decoration('PIN code'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: stateCode,
                style: ErpTextStyles.fieldValue,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                validator: _optional(RegExp(r'^\d{2}$'), '2 digits'),
                decoration: _decoration('GST state code', hint: 'from GSTIN'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: pan,
          style: ErpTextStyles.fieldValue,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [LengthLimitingTextInputFormatter(10)],
          validator: _optional(RegExp(r'^[A-Za-z]{5}\d{4}[A-Za-z]$'), 'A PAN is 5 letters, 4 digits, 1 letter'),
          decoration: _decoration('PAN', hint: 'AAAPC1234F', icon: Icons.badge_outlined),
        ),
      ],
    );
  }
}

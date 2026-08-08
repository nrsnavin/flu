import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/sample_api.dart';
import '../controllers/sample_controllers.dart' show apiMessage;

// ══════════════════════════════════════════════════════════════
//  RAISE A SAMPLE REQUEST
//
//  Everything here is written once and then never edited — anything
//  that changes afterwards is an entry in the log — so the form asks
//  only for what is true at the moment it is raised, and leaves the
//  story to the detail screen.
// ══════════════════════════════════════════════════════════════
class RaiseSamplePage extends StatefulWidget {
  const RaiseSamplePage({super.key});

  @override
  State<RaiseSamplePage> createState() => _RaiseSamplePageState();
}

class _RaiseSamplePageState extends State<RaiseSamplePage> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _customer = TextEditingController();
  final _quantity = TextEditingController();

  String _priority = 'normal';
  DateTime? _targetDate;
  bool _saving = false;

  bool get _ready =>
      _title.text.trim().isNotEmpty && _details.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _customer.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);
    try {
      final sample = await SampleApi.create(
        title: _title.text.trim(),
        details: _details.text.trim(),
        customerName: _customer.text,
        quantity: double.tryParse(_quantity.text.trim()),
        targetDate: _targetDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_targetDate!),
        priority: _priority,
      );
      if (!mounted) return;
      // Pop carrying the code, and let the list say so. A snackbar fired
      // here goes into an overlay this pop tears down before the toast
      // can render — the same thing that made the warping plan's "saved"
      // message invisible.
      Navigator.of(context).pop(sample.code);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', apiMessage(e, 'Could not raise the sample'),
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: const Text("Raise Sample Request",
            style: ErpTextStyles.pageTitle),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  ErpSectionCard(
                    title: "WHAT IS BEING ASKED FOR",
                    icon: Icons.science_outlined,
                    child: Column(
                      children: [
                        _Field(
                          label: "Title *",
                          controller: _title,
                          hint: "e.g. Navy 25mm woven, matt finish",
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          label: "The spec, as the customer gave it *",
                          controller: _details,
                          hint:
                              "Width, shade, composition, elongation, finish — whatever was said.",
                          minLines: 3,
                          maxLines: 6,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ErpSectionCard(
                    title: "FOR WHOM",
                    icon: Icons.business_outlined,
                    child: Column(
                      children: [
                        // A free-text name rather than a picker: a sample
                        // is usually for somebody who is not in the
                        // customer master yet.
                        _Field(
                          label: "Customer",
                          controller: _customer,
                          hint: "e.g. Harlow Garments (enquiry)",
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: _Field(
                              label: "Quantity (m)",
                              controller: _quantity,
                              hint: "Optional",
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _wantedBy(context)),
                        ]),
                        const SizedBox(height: 10),
                        _priorityPicker(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _wantedBy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Wanted by", style: ErpTextStyles.fieldLabel),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _targetDate ?? now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _targetDate = picked);
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Text(
              _targetDate == null
                  ? "Not set"
                  : DateFormat('dd MMM yyyy').format(_targetDate!),
              style: TextStyle(
                fontSize: 13,
                color: _targetDate == null
                    ? ErpColors.textMuted
                    : ErpColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _priorityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Priority", style: ErpTextStyles.fieldLabel),
        const SizedBox(height: 6),
        Row(
          children: ['low', 'normal', 'high'].map((p) {
            final selected = _priority == p;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  p[0].toUpperCase() + p.substring(1),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? ErpColors.accentBlue
                        : ErpColors.textSecondary,
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _priority = p),
                backgroundColor: ErpColors.bgMuted,
                selectedColor: ErpColors.accentBlue.withOpacity(0.12),
                side: BorderSide(
                    color: selected
                        ? ErpColors.accentBlue
                        : ErpColors.borderLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border(top: BorderSide(color: ErpColors.borderLight)),
      ),
      child: Row(children: [
        Expanded(
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
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _ready && !_saving ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                disabledBackgroundColor:
                    ErpColors.accentBlue.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16, color: Colors.white),
              label: Text(_saving ? "Raising…" : "Raise sample",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    this.hint = '',
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ErpTextStyles.fieldLabel),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: ErpColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: ErpColors.bgSurface,
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: ErpColors.borderLight)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: ErpColors.borderLight)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    const BorderSide(color: ErpColors.accentBlue, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

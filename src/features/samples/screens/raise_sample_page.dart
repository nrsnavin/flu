import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../Orders/models/elasticLite.dart' show CustomerLite;
import '../../Orders/screens/searchable_picker.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../customer/customer_search.dart';
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

  /// Set only when the customer was PICKED from the master. A typed
  /// name leaves this null and travels as `customerName` alone, which
  /// the route accepts — see the field's own comment below.
  String? _customerId;

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
        // Both, when there is a link: the route prefers the id and
        // snapshots the master's name off it, so the typed text is a
        // fallback rather than a competing answer.
        customerId: _customerId,
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
        title: Text("Raise Sample Request",
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
                        // ── Picked, or typed ────────────────────
                        // A picker AND a free-text field, not one or
                        // the other. A sample is often for somebody
                        // who is not in the customer master yet — a
                        // trade-fair enquiry, a prospect — which is
                        // why this was free text to begin with. But
                        // when they ARE in the master, typing the
                        // name again leaves the sample unlinked, and
                        // an unlinked sample never appears on their
                        // page however carefully it was spelled.
                        //
                        // So: pick when you can, type when you must.
                        // The route takes either.
                        _CustomerField(
                          name: _customer,
                          pickedId: _customerId,
                          onPicked: (id, name) => setState(() {
                            _customerId = id;
                            _customer.text = name;
                          }),
                          onCleared: () => setState(() {
                            _customerId = null;
                            _customer.clear();
                          }),
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
        Text("Wanted by", style: ErpTextStyles.fieldLabel),
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
            if (picked != null && mounted) {
              setState(() => _targetDate = picked);
            }
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
        Text("Priority", style: ErpTextStyles.fieldLabel),
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
                selectedColor: ErpColors.accentBlue.withValues(alpha: 0.12),
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
      decoration: BoxDecoration(
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
                side: BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text("Cancel",
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
                    ErpColors.accentBlue.withValues(alpha: 0.5),
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
  final bool enabled;

  const _Field({
    required this.label,
    required this.controller,
    this.hint = '',
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
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
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: ErpColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: ErpColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: ErpColors.bgSurface,
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: ErpColors.borderLight)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: ErpColors.borderLight)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    BorderSide(color: ErpColors.accentBlue, width: 1.5)),
            // Set explicitly: a disabled TextField uses disabledBorder,
            // and leaving it to the theme makes a filled-in field look
            // like a broken one.
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: ErpColors.borderLight)),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  WHO THE SAMPLE IS FOR
//
//  Two ways to answer, because there are genuinely two cases and
//  forcing either one alone loses something:
//
//    picked  the customer is in the master, so the sample LINKS to
//            them and shows up on their page
//    typed   a trade-fair enquiry, a prospect, somebody who does
//            not exist in the system yet — still worth recording
//
//  The picked state is shown as a chip with the link spelled out,
//  because "Harlow Garments" typed and "Harlow Garments" picked look
//  identical in a text field and behave completely differently. The
//  one that matters — whether this sample will ever appear on that
//  customer's page — is invisible otherwise.
// ══════════════════════════════════════════════════════════════
class _CustomerField extends StatelessWidget {
  final TextEditingController name;
  final String? pickedId;
  final void Function(String id, String name) onPicked;
  final VoidCallback onCleared;

  const _CustomerField({
    required this.name,
    required this.pickedId,
    required this.onPicked,
    required this.onCleared,
  });

  Future<void> _pick(BuildContext context) async {
    final sel = await showSearchablePicker<CustomerLite>(
      context: context,
      title: 'Select customer',
      label: (c) => c.name,
      onSearch: searchCustomerMaster,
      itemIcon: Icons.business_outlined,
    );
    if (sel != null) onPicked(sel.id, sel.name);
  }

  @override
  Widget build(BuildContext context) {
    final linked = pickedId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: _Field(
              label: 'Customer',
              controller: name,
              hint: 'e.g. Harlow Garments (enquiry)',
              // While linked the name belongs to the master record;
              // editing it here would produce a sample whose snapshot
              // disagreed with the customer it points at.
              enabled: !linked,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: IconButton(
              tooltip: linked ? 'Choose a different customer' : 'Pick from customers',
              onPressed: () => _pick(context),
              icon: Icon(Icons.person_search_outlined,
                  color: ErpColors.accentBlue),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        if (linked)
          Row(children: [
            Icon(Icons.link_rounded, size: 14, color: ErpColors.successGreen),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Linked — this will show on their customer page.',
                style: TextStyle(
                    fontSize: 11, color: ErpColors.successGreen),
              ),
            ),
            TextButton(
              onPressed: onCleared,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Unlink', style: TextStyle(fontSize: 11)),
            ),
          ])
        else
          Text(
            name.text.trim().isEmpty
                ? 'Pick a customer to link this sample to them, or type a '
                    'name for an enquiry.'
                : 'Typed, not linked — it will not appear on any customer '
                    'page. Use the picker to link it.',
            style: TextStyle(fontSize: 11, color: ErpColors.textSecondary),
          ),
      ],
    );
  }
}

import 'dart:io';


import '../../../core/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../../../core/lock/open_externally.dart';
import 'package:path_provider/path_provider.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_controller.dart';
import '../models/service_bill.dart';

// ══════════════════════════════════════════════════════════════
//  SERVICE & SPARE BILLS
//
//  The vendor's invoice for the labour, and a bill for each spare
//  fitted during the job. Filed against the service log they belong to,
//  so "what did this breakdown actually cost" has an answer with paper
//  behind it rather than a number somebody typed from memory.
//
//  The bill's amount is deliberately its own figure and is NOT folded
//  into the log's cost field. The log's cost is what was booked when
//  the job was recorded; the bills are what was invoiced. When they
//  disagree, that disagreement is the useful part.
// ══════════════════════════════════════════════════════════════

final _amber = ErpColors.warningAmber;

void _snack(String msg, {required bool isError}) => Get.snackbar(
      isError ? 'Error' : 'Done',
      msg,
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );

final _moneyFmt = NumberFormat('#,##,###.##', 'en_IN');
String _money(double v) => '₹${_moneyFmt.format(v)}';

/// Opens the bills for one service log. Returns true if anything was
/// added or removed, so the caller can refresh its rolled-up counts.
Future<bool> showServiceBillsSheet({
  required String machineId,
  required String machineDisplayId,
  required MachineServiceLog log,
}) async {
  final changed = await Get.bottomSheet<bool>(
    _ServiceBillsSheet(
      machineId: machineId,
      machineDisplayId: machineDisplayId,
      log: log,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  return changed == true;
}

class _ServiceBillsSheet extends StatefulWidget {
  final String machineId;
  final String machineDisplayId;
  final MachineServiceLog log;
  const _ServiceBillsSheet({
    required this.machineId,
    required this.machineDisplayId,
    required this.log,
  });

  @override
  State<_ServiceBillsSheet> createState() => _ServiceBillsSheetState();
}

class _ServiceBillsSheetState extends State<_ServiceBillsSheet> {
  late final ServiceBillsController c;
  late final String _tag;

  /// Whether anything changed, so the machine page knows to re-read its
  /// per-log counts. Set on upload and on delete, never guessed.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _tag = '${widget.machineId}:${widget.log.id}';
    Get.delete<ServiceBillsController>(tag: _tag, force: true);
    c = Get.put(
      ServiceBillsController(
        machineId: widget.machineId,
        serviceLogId: widget.log.id,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<ServiceBillsController>(tag: _tag, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: ErpColors.bgBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _header(),
        Flexible(child: Obx(_body)),
        _footer(),
      ]),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: ErpColors.navyDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service & Spare Bills',
                      style: ErpTextStyles.pageTitle),
                  Text(
                    '${widget.machineDisplayId}  ›  ${widget.log.type}  ›  '
                    '${DateFormat('dd MMM yyyy').format(widget.log.date)}',
                    style: TextStyle(
                        color: ErpColors.textOnDarkSub, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () => Get.back(result: _dirty),
            ),
          ]),
        ]),
      );

  Widget _body() {
    if (c.isLoading.value && c.bills.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue)),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: [
        if (c.errorMsg.value != null) ...[
          _Note(c.errorMsg.value!, ErpColors.errorRed, Icons.error_outline),
          const SizedBox(height: 10),
        ],

        // What the log said it cost, against what was actually invoiced.
        // The two are separate figures on purpose; where they disagree,
        // the disagreement is the point.
        _Totals(log: widget.log, invoiced: c.totalAmount.value),
        const SizedBox(height: 12),

        if (c.bills.isEmpty)
          _Note(
            'No bills filed against this log yet. Photograph the vendor '
            'invoice or attach their PDF.',
            ErpColors.textMuted,
            Icons.receipt_long_outlined,
          )
        else
          ...c.bills.map((b) => _BillCard(
                bill: b,
                busy: c.isBusy.value,
                onOpen: () => _open(b),
                onDelete: () => _delete(b),
              )),
      ],
    );
  }

  Widget _footer() => Container(
        padding: EdgeInsets.fromLTRB(
            14, 10, 14, 14 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border(top: BorderSide(color: ErpColors.borderLight)),
        ),
        child: Obx(() => Row(children: [
              Expanded(
                child: _AddButton(
                  label: 'Service bill',
                  icon: Icons.receipt_long_rounded,
                  color: ErpColors.accentBlue,
                  busy: c.isBusy.value,
                  onTap: () => _add('service_bill'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AddButton(
                  label: 'Spare bill',
                  icon: Icons.build_rounded,
                  color: _amber,
                  busy: c.isBusy.value,
                  onTap: () => _add('spare_bill'),
                ),
              ),
            ])),
      );

  // ── Actions ────────────────────────────────────────────────

  Future<void> _add(String kind) async {
    // A service bill is a piece of paper a technician hands you at the
    // machine. Photographing it is the whole reason to do this on a
    // phone, and until now it meant leaving the app, shooting, coming
    // back and hunting through the gallery. Files stay on the menu
    // because a bill often arrives as a PDF by email, and a PDF
    // cannot be photographed.
    if (!mounted) return;
    final source = await askCaptureSource(context, cameraLabel: 'Photograph the bill');
    if (source == null) return; // dismissed

    final shot = await capture(source);
    if (shot == null) return; // cancelled, or the picker would not open

    final name = shot.name;

    if (!mounted) return;
    final details = await showModalBottomSheet<_BillDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BillDetailsSheet(kind: kind, filename: name),
    );
    if (details == null) return; // backed out at the details step

    final err = await c.upload(
      kind: kind,
      bytes: shot.bytes,
      filename: name,
      amount: details.amount,
      vendor: details.vendor,
      billNo: details.billNo,
      billDate: details.billDate,
      partName: details.partName,
      notes: details.notes,
    );
    if (err != null) {
      _snack(err, isError: true);
      return;
    }
    _dirty = true;
    _snack('Bill filed', isError: false);
  }

  /// Fetch and hand to the OS. One code path for a PDF and a photo:
  /// both are files, and the phone already knows what to do with each.
  Future<void> _open(ServiceBill b) async {
    _snack('Opening ${b.label}…', isError: false);
    try {
      final bytes = await MachineApiService.billBytes(b.id);
      final dir = await getTemporaryDirectory();
      final ext = b.extension.isNotEmpty
          ? b.extension
          : (b.isPdf ? 'pdf' : 'jpg');
      final safe = b.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final file = File('${dir.path}/bill_$safe.$ext');
      await file.writeAsBytes(bytes);
      final res = await openExternally(file.path);
      if (res.type != ResultType.done) {
        _snack(res.message.isNotEmpty
            ? res.message
            : 'No app on this phone can open a ${ext.toUpperCase()}',
            isError: true);
      }
    } catch (e) {
      _snack('Could not open the bill', isError: true);
    }
  }

  Future<void> _delete(ServiceBill b) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete this bill?', style: TextStyle(fontSize: 16)),
        content: Text(
          'Removes ${b.label} and the file behind it. The service log '
          'itself is untouched.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back<bool>(result: false),
              child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
    if (ok != true) return;

    final err = await c.remove(b.id);
    if (err != null) {
      _snack(err, isError: true);
      return;
    }
    _dirty = true;
    _snack('Bill deleted', isError: false);
  }
}

// ══════════════════════════════════════════════════════════════
//  PIECES
// ══════════════════════════════════════════════════════════════

class _Totals extends StatelessWidget {
  final MachineServiceLog log;
  final double invoiced;
  const _Totals({required this.log, required this.invoiced});

  @override
  Widget build(BuildContext context) {
    final booked = log.cost;
    final gap = invoiced - booked;
    // Only worth remarking on when both figures exist. A log with no
    // cost booked is not "under-invoiced by the whole amount".
    final worthSaying = booked > 0 && invoiced > 0 && gap.abs() >= 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: _Figure('Booked on the log', booked, ErpColors.textSecondary),
          ),
          Container(width: 1, height: 34, color: ErpColors.borderLight),
          Expanded(
            child: _Figure('Invoiced on bills', invoiced, ErpColors.accentBlue),
          ),
        ]),
        if (worthSaying) ...[
          const SizedBox(height: 8),
          Text(
            gap > 0
                ? 'Bills come to ${_money(gap)} more than the log booked.'
                : 'Bills come to ${_money(-gap)} less than the log booked.',
            style: TextStyle(fontSize: 10.5, color: _amber),
          ),
        ],
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Figure(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value > 0 ? _money(value) : '—',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ErpColors.textMuted)),
      ]);
}

class _BillCard extends StatelessWidget {
  final ServiceBill bill;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _BillCard({
    required this.bill,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = bill.isSpare ? _amber : ErpColors.accentBlue;

    final facts = <String>[
      if (bill.vendor.isNotEmpty) bill.vendor,
      if (bill.partName.isNotEmpty && bill.partName != bill.label)
        bill.partName,
      if (bill.billDate != null)
        DateFormat('dd MMM yyyy').format(bill.billDate!),
      bill.sizeLabel,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
                bill.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                size: 17,
                color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${billKindLabel(bill.kind)}  ·  ${facts.join('  ·  ')}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: ErpColors.textSecondary),
                ),
              ],
            ),
          ),
          if (bill.amount > 0)
            Text(_money(bill.amount),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ErpColors.textPrimary)),
        ]),
        if (bill.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(bill.notes,
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: ErpColors.textSecondary)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ErpColors.borderMid),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: busy ? null : onOpen,
                icon: Icon(Icons.open_in_new_rounded,
                    size: 13, color: ErpColors.textSecondary),
                label: Text('Open',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.textSecondary)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ErpColors.errorRed.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: busy ? null : onDelete,
              child: Icon(Icons.delete_outline,
                  size: 15, color: ErpColors.errorRed),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onTap;
  const _AddButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withOpacity(0.4),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(icon, size: 15, color: Colors.white),
          label: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ),
      );
}

class _Note extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _Note(this.msg, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: color, fontSize: 11.5, height: 1.4)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
//  BOOKKEEPING FOR ONE BILL
//
//  Asked AFTER the file is chosen, and every field is optional. A
//  photograph of the invoice already carries the truth; making somebody
//  standing next to a stripped-down loom retype it before the picture
//  will save is how bills stop being filed at all.
// ══════════════════════════════════════════════════════════════
class _BillDetails {
  final double amount;
  final String vendor;
  final String billNo;
  final DateTime? billDate;
  final String partName;
  final String notes;

  const _BillDetails({
    required this.amount,
    required this.vendor,
    required this.billNo,
    required this.partName,
    required this.notes,
    this.billDate,
  });
}

class _BillDetailsSheet extends StatefulWidget {
  final String kind;
  final String filename;
  const _BillDetailsSheet({required this.kind, required this.filename});

  @override
  State<_BillDetailsSheet> createState() => _BillDetailsSheetState();
}

class _BillDetailsSheetState extends State<_BillDetailsSheet> {
  final _amount = TextEditingController();
  final _vendor = TextEditingController();
  final _billNo = TextEditingController();
  final _part = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _billDate;

  bool get _isSpare => widget.kind == 'spare_bill';

  @override
  void dispose() {
    _amount.dispose();
    _vendor.dispose();
    _billNo.dispose();
    _part.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: ErpColors.bgBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: ErpColors.navyDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isSpare ? 'Spare bill' : 'Service bill',
                        style: ErpTextStyles.pageTitle),
                    Text(widget.filename,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: ErpColors.textOnDarkSub, fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: ErpSectionCard(
                title: 'BOOKKEEPING — ALL OPTIONAL',
                icon: Icons.description_outlined,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        style: TextStyle(
                            fontSize: 13, color: ErpColors.textPrimary),
                        decoration:
                            ErpDecorations.formInput('Amount', hint: '0')
                                .copyWith(
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(
                              color: ErpColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _datePicker(context)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _vendor,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary),
                    decoration: ErpDecorations.formInput('Vendor',
                        hint: 'Who issued it'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _billNo,
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary),
                    decoration: ErpDecorations.formInput('Bill number',
                        hint: 'As printed on the invoice'),
                  ),
                  if (_isSpare) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _part,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                          fontSize: 13, color: ErpColors.textPrimary),
                      decoration: ErpDecorations.formInput('Part fitted',
                          hint: 'e.g. Take-up roller bearing'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary),
                    decoration: ErpDecorations.formInput('Notes',
                        hint: 'Anything the next person should know'),
                  ),
                ]),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                14, 10, 14, 14 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              border: Border(top: BorderSide(color: ErpColors.borderLight)),
            ),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).pop(_BillDetails(
                  amount: double.tryParse(_amount.text.trim()) ?? 0,
                  vendor: _vendor.text.trim(),
                  billNo: _billNo.text.trim(),
                  billDate: _billDate,
                  partName: _part.text.trim(),
                  notes: _notes.text.trim(),
                )),
                icon: const Icon(Icons.upload_rounded,
                    size: 16, color: Colors.white),
                label: const Text('Upload bill',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _datePicker(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill date', style: ErpTextStyles.fieldLabel),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _billDate ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: now,
              );
              if (picked != null) setState(() => _billDate = picked);
            },
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: ErpColors.bgSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ErpColors.borderLight),
              ),
              child: Text(
                _billDate == null
                    ? 'Not set'
                    : DateFormat('dd MMM yyyy').format(_billDate!),
                style: TextStyle(
                  fontSize: 13,
                  color: _billDate == null
                      ? ErpColors.textMuted
                      : ErpColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      );
}

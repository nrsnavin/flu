import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/capture.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/claims_controller.dart';
import '../models/claim_models.dart';
import '../services/claims_api.dart';

final _day = DateFormat('dd MMM yyyy');
final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

({Color bg, Color fg}) _tone(String status) => switch (status) {
      'pending' => (bg: ErpColors.statusPartialBg, fg: ErpColors.statusPartialText),
      'approved' => (bg: ErpColors.statusOpenBg, fg: ErpColors.statusOpenText),
      'rejected' => (bg: ErpColors.statusCancelledBg, fg: ErpColors.errorRed),
      'paid' => (bg: ErpColors.statusCompletedBg, fg: ErpColors.statusCompletedText),
      _ => (bg: ErpColors.bgMuted, fg: ErpColors.textSecondary),
    };

class ClaimsPage extends StatefulWidget {
  const ClaimsPage({super.key});

  @override
  State<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends State<ClaimsPage> {
  late final ClaimsController c;

  @override
  void initState() {
    super.initState();
    Get.delete<ClaimsController>(force: true);
    c = Get.put(ClaimsController());
  }

  @override
  void dispose() {
    Get.delete<ClaimsController>(force: true);
    super.dispose();
  }

  Future<void> _new() async {
    final sent = await Get.to<bool>(() => const NewClaimPage());
    if (sent == true) c.fetch();
  }

  Future<void> _withdraw(Claim claim) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Withdraw the ${_inr.format(claim.amount)} claim?'),
        content: const Text('It is cancelled for good. To claim it again, send a new one.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw claim')),
        ],
      ),
    );
    if (go != true) return;
    final r = await c.withdraw(claim);
    if (r.message.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.message),
        backgroundColor: r.ok ? ErpColors.solidSuccess : ErpColors.solidError,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: const Text('Expense claims'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        backgroundColor: ErpColors.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New claim'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.claims.isEmpty) return const Center(child: CircularProgressIndicator());
        if (c.errorMsg.value != null && c.claims.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(c.errorMsg.value!, style: TextStyle(color: ErpColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: c.fetch, child: const Text('Try again')),
            ]),
          );
        }
        final busy = c.withdrawing.value;
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              if (c.waiting.value > 0 || c.owed.value > 0)
                Row(children: [
                  Expanded(child: _total('Waiting for approval', c.waiting.value)),
                  const SizedBox(width: 10),
                  Expanded(child: _total('Approved, to be paid to you', c.owed.value)),
                ]),
              if (c.waiting.value > 0 || c.owed.value > 0) const SizedBox(height: 12),
              if (c.claims.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No claims yet. When you pay for something for work, claim it here with the receipt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ErpColors.textSecondary),
                  ),
                ),
              for (final claim in c.claims) ...[
                _ClaimCard(
                  claim: claim,
                  busy: busy == claim.id,
                  onWithdraw: claim.isPending ? () => _withdraw(claim) : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _total(String label, double value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 9.5, letterSpacing: 0.5, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
          const SizedBox(height: 4),
          Text(_inr.format(value),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        ]),
      );
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.busy, this.onWithdraw});

  final Claim claim;
  final bool busy;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final t = _tone(claim.status);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(claim.description,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Text(_inr.format(claim.amount),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        ]),
        const SizedBox(height: 3),
        Text(
          [
            claim.categoryName,
            if (claim.date != null) _day.format(claim.date!),
            claim.expenseNo,
            if (claim.attachments > 0) 'receipt attached',
          ].where((s) => s.isNotEmpty).join('  ·  '),
          style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted),
        ),
        if (claim.status == 'rejected' && claim.decisionNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(claim.decisionNote, style: TextStyle(fontSize: 12, color: ErpColors.errorRed)),
          ),
        if (claim.status == 'paid' && claim.paidAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Paid on ${_day.format(claim.paidAt!)}',
                style: TextStyle(fontSize: 12, color: ErpColors.statusCompletedText)),
          ),
        const SizedBox(height: 9),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(claim.statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: t.fg)),
          ),
          const Spacer(),
          if (onWithdraw != null)
            TextButton(
              onPressed: busy ? null : onWithdraw,
              child: busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Withdraw…'),
            ),
        ]),
      ]),
    );
  }
}

// ══════════════════════ NEW CLAIM ══════════════════════

class NewClaimPage extends StatefulWidget {
  const NewClaimPage({super.key});

  @override
  State<NewClaimPage> createState() => _NewClaimPageState();
}

class _NewClaimPageState extends State<NewClaimPage> {
  late final NewClaimController c;

  @override
  void initState() {
    super.initState();
    Get.delete<NewClaimController>(force: true);
    c = Get.put(NewClaimController());
  }

  @override
  void dispose() {
    Get.delete<NewClaimController>(force: true);
    super.dispose();
  }

  Future<void> _photo() async {
    final source = await askCaptureSource(context, cameraLabel: 'Photograph the receipt');
    if (source == null) return;
    final file = await capture(source);
    if (file == null) return;
    await c.usePhoto(file);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: c.date.value.isAfter(now) ? now : c.date.value,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null) c.date.value = d;
  }

  Future<void> _send() async {
    try {
      final claim = await c.send();
      if (!mounted) return;
      final note = c.photoError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(note == null
            ? '${claim.expenseNo} sent for approval'
            : '${claim.expenseNo} sent for approval, but the photo did not attach: $note'),
        backgroundColor: note == null ? ErpColors.solidSuccess : ErpColors.solidWarning,
      ));
      Get.back(result: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(claimMessage(e, 'Could not send the claim')),
        backgroundColor: ErpColors.solidError,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: const Text('New expense claim'),
      ),
      body: Obx(() {
        final photo = c.photo.value;
        final scan = c.scan.value;
        c.edits.value; // follow the text fields
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
          children: [
            OutlinedButton.icon(
              onPressed: c.reading.value ? null : _photo,
              icon: c.reading.value
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(c.reading.value
                  ? 'Reading the receipt…'
                  : photo == null
                      ? 'Photograph the receipt first'
                      : 'Receipt: ${photo.name} — tap to retake'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            if (photo != null && !photo.name.toLowerCase().endsWith('.pdf')) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(photo.bytes, height: 160, fit: BoxFit.cover),
              ),
            ],
            if (c.readNote.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (scan != null) ...[
                  Icon(Icons.auto_awesome, size: 16, color: ErpColors.accentBlue),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    c.readNote.value +
                        (scan != null && scan.categoryName.isNotEmpty && scan.categoryReason.isNotEmpty
                            ? ' Head: ${scan.categoryName} (${scan.categoryReason.toLowerCase()}).'
                            : ''),
                    style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary),
                  ),
                ),
              ]),
            ],
            if (scan?.alreadyClaimed != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ErpColors.statusPartialBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'This receipt looks already claimed as ${scan!.alreadyClaimed}. Send it only if it is a different bill.',
                  style: TextStyle(fontSize: 12.5, color: ErpColors.statusPartialText),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (c.loadError.value != null)
              Row(children: [
                Expanded(child: Text(c.loadError.value!, style: TextStyle(color: ErpColors.errorRed, fontSize: 12.5))),
                TextButton(onPressed: c.loadCategories, child: const Text('Retry')),
              ]),
            DropdownButtonFormField<String>(
              // Keyed on the value: reading the receipt can pick the head
              // after the field was built.
              key: ValueKey('head-${c.category.value}-${c.categories.length}'),
              value: c.category.value,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'What was it for? *', border: OutlineInputBorder()),
              items: [
                for (final cat in c.categories)
                  DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.dailyLimit > 0
                        ? '${cat.name}  (up to ${_inr.format(cat.dailyLimit)} a day)'
                        : cat.name),
                  ),
              ],
              onChanged: (v) => c.category.value = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Details *',
                hintText: 'e.g. Diesel for the genset, 10 L',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: c.amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Amount ₹ *', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date *', border: OutlineInputBorder()),
                    child: Text(_day.format(c.date.value)),
                  ),
                ),
              ),
            ]),
          ],
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Obx(() {
            c.edits.value;
            return FilledButton(
              onPressed: c.ready ? _send : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: c.sending.value
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send for approval'),
            );
          }),
        ),
      ),
    );
  }
}

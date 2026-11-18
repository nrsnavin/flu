import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/features.dart';
import '../../Job/screens/job_detail.dart' show JobDetailPage;
import '../../PurchaseOrder/services/theme.dart';
import '../../authentication/controllers/login_controller.dart';
import '../../authentication/services/nav_registry.dart';
import '../../samples/screens/sample_detail_page.dart' show SampleDetailPage;
import '../controllers/dispatch_controller.dart';
import '../models/dispatch_models.dart';

// ══════════════════════════════════════════════════════════════
//  WHAT IS WAITING TO LEAVE, MOST URGENT FIRST
//
//  A job reaching packing, or a finished sample, lands here and waits
//  for marketing or admin to say when the customer needs it. Until then
//  it sits at the top under "Needs a delivery urgency" — it cannot be
//  placed without that answer. After it, the queue in deadline order,
//  with anything past its deadline marked late.
//
//  The same queue as the web's Dispatch page, for the people at the
//  loading bay: one thumb marks a consignment gone.
// ══════════════════════════════════════════════════════════════

/// How urgent each slot looks: the sooner, the louder (as on the web).
({Color bg, Color fg}) _urgencyTone(String? urgency) => switch (urgency) {
      'today_morning' => (bg: ErpColors.statusCancelledBg, fg: ErpColors.errorRed),
      'today_evening' => (bg: ErpColors.statusPartialBg, fg: ErpColors.statusPartialText),
      'today' => (bg: ErpColors.statusOpenBg, fg: ErpColors.statusOpenText),
      _ => (bg: ErpColors.bgMuted, fg: ErpColors.textSecondary),
    };

class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  late final DispatchController c;

  String get _role => LoginController.find.user.value.role.toLowerCase();

  /// The server's rule (api/dispatch.js): admin or marketing say when
  /// it must leave; only admin takes one off the queue.
  bool get _canSetUrgency => _role == 'admin' || _role == 'marketing';
  bool get _canRemove => _role == 'admin';

  @override
  void initState() {
    super.initState();
    Get.delete<DispatchController>(force: true);
    c = Get.put(DispatchController());
  }

  @override
  void dispose() {
    Get.delete<DispatchController>(force: true);
    super.dispose();
  }

  void _say(DispatchOutcome r) {
    if (r.message.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r.message),
      backgroundColor: r.ok ? ErpColors.solidSuccess : ErpColors.solidError,
    ));
  }

  Future<void> _pick(DispatchItem item, UrgencyOption o) async => _say(await c.setUrgency(item, o));

  /// The job or the sample behind a line, for those who may open it.
  VoidCallback? _opener(DispatchItem i) {
    final features = NavRegistry.instance.features;
    if (i.kind == 'job' && i.jobId != null && hasFeature(features, '/jobs')) {
      return () => Get.to(() => JobDetailPage(), arguments: i.jobId);
    }
    if (i.kind == 'sample' && i.sampleId != null && hasFeature(features, '/samples')) {
      return () => Get.to(() => SampleDetailPage(sampleId: i.sampleId!));
    }
    return null;
  }

  Future<void> _dispatched(DispatchItem item) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _DispatchedSheet(item: item),
    );
    if (note == null) return; // closed without confirming
    _say(await c.markDispatched(item, note));
  }

  Future<void> _remove(DispatchItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RemoveDialog(item: item),
    );
    if (reason == null) return;
    _say(await c.remove(item, reason));
  }

  Future<void> _more(DispatchItem item) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${item.ref} · ${item.customerName}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
            ),
          ),
          if (_canSetUrgency)
            for (final o in kUrgencies.where((o) => o.value != item.urgency))
              ListTile(
                dense: true,
                leading: Icon(Icons.schedule_rounded, color: ErpColors.textSecondary),
                title: Text('Change to ${o.label}'),
                subtitle: Text(o.hint),
                onTap: () => Navigator.pop(ctx, o),
              ),
          if (_canRemove)
            ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline_rounded, color: ErpColors.errorRed),
              title: Text('Remove from queue…', style: TextStyle(color: ErpColors.errorRed)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice is UrgencyOption) return _pick(item, choice);
    if (choice == 'remove') return _remove(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: const Text('Dispatch'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: c.fetch),
        ],
      ),
      body: Column(children: [
        Obx(() => _ViewToggle(dispatched: c.showDispatched.value, onPick: (d) => c.show(dispatched: d))),
        Expanded(child: Obx(_body)),
      ]),
    );
  }

  Widget _body() {
    final dispatchedView = c.showDispatched.value;
    final items = c.items.toList();
    if (c.isLoading.value && items.isEmpty) return const Center(child: CircularProgressIndicator());
    final error = c.errorMsg.value;
    if (error != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: ErpColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: c.fetch, child: const Text('Try again')),
          ]),
        ),
      );
    }
    final busy = c.busyId.value;
    final now = DateTime.now();
    final awaiting = items.where((i) => i.awaiting).toList();
    final queued = items.where((i) => i.queued).toList();

    return RefreshIndicator(
      onRefresh: c.fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
        children: [
          // What is on screen may be behind: say so rather than hide it.
          if (error != null) _Notice(text: '$error — showing what was loaded before.'),
          if (dispatchedView) ...[
            if (items.isEmpty)
              const _Empty(
                title: 'Nothing dispatched yet',
                text: 'Items marked dispatched from the queue appear here.',
              ),
            for (final i in items) ...[
              _GoneCard(item: i, onOpen: _opener(i)),
              const SizedBox(height: 8),
            ],
          ] else ...[
            _Counts(awaiting: c.awaitingCount.value, queued: c.queuedCount.value, late: c.lateCount.value),
            const SizedBox(height: 12),
            if (awaiting.isNotEmpty) ...[
              _SectionTitle(
                icon: Icons.alarm_rounded,
                iconColor: ErpColors.warningAmber,
                title: 'Needs a delivery urgency',
                hint: _canSetUrgency ? 'When does the customer need it?' : 'Waiting for marketing or admin',
              ),
              for (final i in awaiting) ...[
                _AwaitingCard(
                  item: i,
                  now: now,
                  canSet: _canSetUrgency,
                  busy: busy != null,
                  working: busy == i.id,
                  onPick: (o) => _pick(i, o),
                  onOpen: _opener(i),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
            ],
            const _SectionTitle(title: 'Dispatch queue'),
            if (queued.isEmpty)
              _Empty(
                title: awaiting.isNotEmpty ? 'Nothing placed yet' : 'Nothing waiting to go',
                text: awaiting.isNotEmpty
                    ? 'Items join the queue once their delivery urgency is set.'
                    : 'Jobs join when they reach packing; samples when they are completed.',
              ),
            for (var n = 0; n < queued.length; n++) ...[
              _QueuedCard(
                position: n + 1,
                item: queued[n],
                now: now,
                busy: busy != null,
                working: busy == queued[n].id,
                onDispatched: () => _dispatched(queued[n]),
                onMore: (_canSetUrgency || _canRemove) ? () => _more(queued[n]) : null,
                onOpen: _opener(queued[n]),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.dispatched, required this.onPick});
  final bool dispatched;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final on = dispatched == value;
      return Expanded(
        child: InkWell(
          onTap: () => onPick(value),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: on ? ErpColors.accentBlue : Colors.transparent, width: 2.5)),
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: on ? ErpColors.accentBlue : ErpColors.textSecondary,
                )),
          ),
        ),
      );
    }

    return Container(
      color: ErpColors.bgSurface,
      child: Row(children: [tab('Queue', false), tab('Dispatched', true)]),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.awaiting, required this.queued, required this.late});
  final int awaiting;
  final int queued;
  final int late;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int n, Color? loud) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: n > 0 && loud != null ? loud : ErpColors.textPrimary,
                  )),
              const SizedBox(height: 1),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9, letterSpacing: 0.4, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        tile('Need urgency', awaiting, ErpColors.warningAmber),
        const SizedBox(width: 8),
        tile('In queue', queued, null),
        const SizedBox(width: 8),
        tile('Late', late, ErpColors.errorRed),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.hint, this.icon, this.iconColor});
  final String title;
  final String? hint;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 16, color: iconColor), const SizedBox(width: 6)],
            // Wraps on a narrow phone or with a large system font, never clips.
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
            ),
          ]),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
            ),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ErpColors.statusPartialBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.statusPartialBorder),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, color: ErpColors.statusPartialText)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      );
}

/// What it is: the reference and the customer, then the goods.
class _What extends StatelessWidget {
  const _What({required this.item, this.onOpen});
  final DispatchItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (item.title.isNotEmpty) item.title,
      if (item.quantity > 0) metres(item.quantity),
      if (item.orderNo != null) 'Order #${item.orderNo}',
    ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
        InkWell(
          onTap: onOpen,
          child: Text(item.ref.isEmpty ? '—' : item.ref,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: onOpen != null ? ErpColors.accentBlue : ErpColors.textPrimary,
              )),
        ),
        Text(item.customerName.isEmpty ? '—' : item.customerName,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ErpColors.textPrimary)),
        if (item.kind == 'sample') _Chip('Sample', ErpColors.bgMuted, ErpColors.textSecondary),
      ]),
      if (detail.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(detail, style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
        ),
    ]);
  }
}

BoxDecoration _card({Color? edge, Color? fill}) => BoxDecoration(
      color: fill ?? ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: edge ?? ErpColors.borderLight),
    );

class _AwaitingCard extends StatelessWidget {
  const _AwaitingCard({
    required this.item,
    required this.now,
    required this.canSet,
    required this.busy,
    required this.working,
    required this.onPick,
    this.onOpen,
  });

  final DispatchItem item;
  final DateTime now;
  final bool canSet;
  final bool busy;
  final bool working;
  final ValueChanged<UrgencyOption> onPick;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _card(edge: ErpColors.statusPartialBorder),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _What(item: item, onOpen: onOpen),
        if (item.readyAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('Ready ${span(now.difference(item.readyAt!))} ago',
                style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
          ),
        const SizedBox(height: 10),
        if (!canSet)
          _Chip('Awaiting urgency', ErpColors.statusPartialBg, ErpColors.statusPartialText)
        else if (working)
          const SizedBox(height: 36, child: Center(child: LinearProgressIndicator()))
        else
          // Two to a row: four slots, each with its cut-off under the name.
          LayoutBuilder(builder: (ctx, box) {
            final w = (box.maxWidth - 8) / 2;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in kUrgencies)
                SizedBox(
                  width: w,
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onPick(o),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      side: BorderSide(color: ErpColors.borderMid),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(o.label,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                      Text(o.hint, style: TextStyle(fontSize: 10.5, color: ErpColors.textMuted)),
                    ]),
                  ),
                ),
            ]);
          }),
      ]),
    );
  }
}

class _QueuedCard extends StatelessWidget {
  const _QueuedCard({
    required this.position,
    required this.item,
    required this.now,
    required this.busy,
    required this.working,
    required this.onDispatched,
    this.onMore,
    this.onOpen,
  });

  final int position;
  final DispatchItem item;
  final DateTime now;
  final bool busy;
  final bool working;
  final VoidCallback onDispatched;
  final VoidCallback? onMore;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = _urgencyTone(item.urgency);
    final due = item.dueAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 10),
      decoration: _card(
        edge: item.late ? ErpColors.statusCancelledBorder : null,
        fill: item.late ? ErpColors.statusCancelledBg.withValues(alpha: 0.35) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 26,
            child: Text('$position',
                semanticsLabel: 'Position $position',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ErpColors.textMuted)),
          ),
          Expanded(child: _What(item: item, onOpen: onOpen)),
          if (onMore != null)
            IconButton(
              tooltip: 'More',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_vert_rounded, color: ErpColors.textSecondary),
              onPressed: busy ? null : onMore,
            )
          else
            const SizedBox(width: 6),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 26, right: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (item.urgency != null) _Chip(item.urgencyLabel ?? item.urgency!, tone.bg, tone.fg),
              if (item.late && due != null)
                _Chip('Late ${span(now.difference(due))}', ErpColors.statusCancelledBg, ErpColors.errorRed),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: ErpColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    due == null ? '—' : dueText(due, now),
                    if (item.urgencySetByName.isNotEmpty) 'set by ${item.urgencySetByName}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: ErpColors.textSecondary),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onDispatched,
                style: FilledButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: working
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(working ? 'Saving…' : 'Dispatched'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _GoneCard extends StatelessWidget {
  const _GoneCard({required this.item, this.onOpen});
  final DispatchItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final by = [
      if (item.dispatchedByName.isNotEmpty) 'by ${item.dispatchedByName}',
      if (item.dispatchNote.isNotEmpty) item.dispatchNote,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _What(item: item, onOpen: onOpen),
        const SizedBox(height: 7),
        Row(children: [
          Icon(Icons.check_circle_rounded, size: 15, color: ErpColors.successGreen),
          const SizedBox(width: 5),
          Expanded(
            child: Text(item.dispatchedAt == null ? '—' : stamp(item.dispatchedAt!),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ErpColors.statusCompletedText)),
          ),
        ]),
        if (by.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(by, style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
          ),
      ]),
    );
  }
}

// ── Mark it dispatched ────────────────────────────────────────

/// Pops with the note (possibly empty) when confirmed; null when closed.
class _DispatchedSheet extends StatefulWidget {
  const _DispatchedSheet({required this.item});
  final DispatchItem item;

  @override
  State<_DispatchedSheet> createState() => _DispatchedSheetState();
}

class _DispatchedSheetState extends State<_DispatchedSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      // Above the keyboard.
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mark ${item.ref} dispatched',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            [item.customerName, if (item.title.isNotEmpty) item.title].where((s) => s.isNotEmpty).join(' — '),
            style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. DC-41, lorry TN38 AB 1234',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _note.text.trim()),
                style: FilledButton.styleFrom(backgroundColor: ErpColors.accentBlue, foregroundColor: Colors.white),
                child: const Text('Mark dispatched'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Take it off the queue ─────────────────────────────────────

/// Pops with the reason when confirmed; null when closed.
class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.item});
  final DispatchItem item;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The server's rule: a reason of at least three characters.
    final ok = _reason.text.trim().length >= 3;
    return AlertDialog(
      title: Text('Remove ${widget.item.ref} from the dispatch queue'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('It will not be dispatched from here. Recorded with the reason.'),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          autofocus: true,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Why is it coming off the queue?',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep it')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, _reason.text.trim()) : null,
          style: FilledButton.styleFrom(backgroundColor: ErpColors.solidError, foregroundColor: Colors.white),
          child: const Text('Remove'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHIFT LIST PAGE
//  File: lib/src/features/shift/screens/shift_list_page.dart
//
//  FIX: was StatelessWidget with Get.put() as class field →
//       stale controller on re-navigation.
//       Converted to StatefulWidget with Get.delete/Get.put
//       in initState().
//
//  ADDED: "⚡ Enter All" FAB → bulk production entry sheet.
//         Operator enters production + timer for every open
//         shift on one screen without navigating away.
//
//  NESTED OBX RULE: every reactive section is its own
//  StatelessWidget. The page body itself is NOT wrapped in Obx.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_list_controller.dart';
import '../models/shiftModel.dart';
import 'shift_detail.dart';

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class ShiftListPage extends StatefulWidget {
  const ShiftListPage({super.key});

  @override
  State<ShiftListPage> createState() => _ShiftListPageState();
}

class _ShiftListPageState extends State<ShiftListPage> {
  late final ShiftControllerView c;

  @override
  void initState() {
    super.initState();
    Get.delete<ShiftControllerView>(force: true);
    c = Get.put(ShiftControllerView());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: 'Open Shifts',
        subtitle: 'Pending production entry',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: ErpColors.textOnDark, size: 20),
            onPressed: c.fetchOpenShifts,
          ),
        ],
      ),
      // ── FAB: visible only when there are open shifts ──────
      floatingActionButton: _BulkFab(c: c, context: context),
      body: _Body(c: c),
    );
  }
}

// ── FAB (own Obx, not nested) ─────────────────────────────────
class _BulkFab extends StatelessWidget {
  final ShiftControllerView c;
  final BuildContext context;
  const _BulkFab({required this.c, required this.context});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value || c.shifts.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      backgroundColor: ErpColors.accentBlue,
      elevation: 4,
      icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
      label: Text(
        'Enter All  (${c.shifts.length})',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
      ),
      onPressed: () {
        c.initBulkEntries();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _BulkSheet(c: c),
        );
      },
    );
  });
}

// ── Body (own Obx, not nested) ────────────────────────────────
class _Body extends StatelessWidget {
  final ShiftControllerView c;
  const _Body({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value) {
      return const Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue));
    }
    if (c.shifts.isEmpty) {
      return const Center(child: _EmptyState());
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), // room for FAB
      itemCount: c.shifts.length,
      itemBuilder: (_, i) => _ShiftCard(shift: c.shifts[i]),
    );
  });
}

// ── Shift card ────────────────────────────────────────────────
class _ShiftCard extends StatelessWidget {
  final ShiftModel shift;
  const _ShiftCard({required this.shift});

  bool get _isNight => shift.shift.toLowerCase().contains('night');

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      await Get.to(() => ShiftDetailPage(shiftId: shift.id));
      // Refresh after returning from detail
      Get.find<ShiftControllerView>().fetchOpenShifts();
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.05),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // ── Card header ─────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            // Machine badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: ErpColors.navyDark,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                shift.machineName.isNotEmpty ? shift.machineName : '—',
                style: const TextStyle(
                    color: ErpColors.textOnDark, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Job #${shift.jobNo.isNotEmpty ? shift.jobNo : '—'}',
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12),
              ),
            ),
            // Shift badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _isNight
                    ? ErpColors.statusOpenBg
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _isNight
                      ? ErpColors.statusOpenBorder
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _isNight ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                  size: 10,
                  color: _isNight
                      ? ErpColors.statusOpenText
                      : const Color(0xFFD97706),
                ),
                const SizedBox(width: 4),
                Text(
                  shift.shift.toUpperCase(),
                  style: TextStyle(
                    color: _isNight
                        ? ErpColors.statusOpenText
                        : const Color(0xFFD97706),
                    fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                  ),
                ),
              ]),
            ),
          ]),
        ),
        // ── Card footer ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Icon(Icons.person_outline,
                size: 13, color: ErpColors.textSecondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                shift.operatorName.isNotEmpty ? shift.operatorName : '—',
                style: const TextStyle(
                    color: ErpColors.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 11, color: ErpColors.textMuted),
            const SizedBox(width: 5),
            Text(
              DateFormat('dd MMM').format(shift.date),
              style: const TextStyle(
                  color: ErpColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: ErpColors.textMuted),
          ]),
        ),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  BULK ENTRY BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _BulkSheet extends StatelessWidget {
  final ShiftControllerView c;
  const _BulkSheet({required this.c});

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.93,
    minChildSize:     0.5,
    maxChildSize:     0.97,
    expand: false,
    builder: (_, scrollCtrl) => Container(
      decoration: const BoxDecoration(
        color: ErpColors.bgBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: ErpColors.borderLight,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        // Header
        _BulkHeader(c: c),
        // Machine cards
        Expanded(
          child: Obx(() => c.bulkEntries.isEmpty
              ? const Center(
              child: Text('No open shifts to update.',
                  style: TextStyle(color: ErpColors.textSecondary)))
              : ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            itemCount: c.bulkEntries.length,
            itemBuilder: (_, i) =>
                _BulkEntryCard(entry: c.bulkEntries[i], index: i),
          ),
          ),
        ),
        // Submit bar
        _BulkSubmitBar(c: c),
      ]),
    ),
  );
}

// ── Sheet header with live total ──────────────────────────────
class _BulkHeader extends StatelessWidget {
  final ShiftControllerView c;
  const _BulkHeader({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    decoration: const BoxDecoration(
      color: ErpColors.bgBase,
      border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bolt_rounded,
                size: 13, color: ErpColors.accentBlue),
            const SizedBox(width: 4),
            const Text('Bulk Entry',
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 10),
        Obx(() => Text(
          '${c.bulkEntries.length} open shift${c.bulkEntries.length == 1 ? '' : 's'}',
          style: const TextStyle(
              color: ErpColors.textSecondary,
              fontSize: 13, fontWeight: FontWeight.w600),
        )),
        const Spacer(),
        // Live total badge
        Obx(() => c.bulkTotalMeters.value > 0
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ErpColors.successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: ErpColors.successGreen.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.straighten_rounded,
                size: 12, color: ErpColors.successGreen),
            const SizedBox(width: 4),
            Text(
              '${c.bulkTotalMeters.value} m total',
              style: const TextStyle(
                  color: ErpColors.successGreen,
                  fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ]),
        )
            : const SizedBox.shrink()),
      ]),
      const SizedBox(height: 6),
      const Text(
        'Enter production (meters) and run time for each machine. '
            'Scroll the wheels to set the run time.',
        style: TextStyle(color: ErpColors.textSecondary, fontSize: 11),
      ),
    ]),
  );
}

// ── Per-shift entry card ──────────────────────────────────────
class _BulkEntryCard extends StatefulWidget {
  final BulkEntry entry;
  final int index;
  const _BulkEntryCard({required this.entry, required this.index});

  @override
  State<_BulkEntryCard> createState() => _BulkEntryCardState();
}

class _BulkEntryCardState extends State<_BulkEntryCard> {
  bool _showFeedback = false;

  BulkEntry  get e => widget.entry;
  ShiftModel get s => e.shift;
  bool get _isNight => s.shift.toLowerCase().contains('night');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Card header ─────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1F35),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            // Machine badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.machineName.isNotEmpty ? s.machineName : 'M${widget.index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.operatorName.isNotEmpty ? s.operatorName : '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Job #${s.jobNo.isNotEmpty ? s.jobNo : '—'}  ·  '
                      '${DateFormat('dd MMM').format(s.date)}',
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10),
                ),
              ],
            )),
            // Shift type pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _isNight ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                  size: 10, color: _isNight
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFFBBF24),
                ),
                const SizedBox(width: 4),
                Text(
                  s.shift.toUpperCase(),
                  style: TextStyle(
                      color: _isNight
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFFBBF24),
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ]),
            ),
          ]),
        ),

        // ── Input area ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [

            // ── Production field (full width) ──────────────
            const _FieldLabel('Production (meters) *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: e.productionCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900,
                  color: ErpColors.textPrimary),
              decoration: _fieldDeco(
                hint: '0',
                suffix: const Text('m',
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            // Live meter count
            Obx(() {
              final prod = e.liveMeters.value;
              if (prod == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '$prod m entered',
                  style: const TextStyle(
                      color: ErpColors.successGreen,
                      fontSize: 10, fontWeight: FontWeight.w700),
                ),
              );
            }),
            const SizedBox(height: 14),
            // ── Timer — full width, drums flex to fill ────
            const _FieldLabel('Run Time'),
            const SizedBox(height: 6),
            _ScrollTimerField(controller: e.timerCtrl),

            const SizedBox(height: 10),

            // Optional feedback toggle
            GestureDetector(
              onTap: () => setState(() => _showFeedback = !_showFeedback),
              child: Row(children: [
                Icon(
                    _showFeedback ? Icons.expand_less_rounded : Icons.add_rounded,
                    size: 14, color: ErpColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _showFeedback ? 'Hide notes' : 'Add notes (optional)',
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ]),
            ),

            if (_showFeedback) ...[
              const SizedBox(height: 8),
              TextField(
                controller: e.feedbackCtrl,
                maxLines: 2,
                style: const TextStyle(
                    color: ErpColors.textPrimary, fontSize: 13),
                decoration: _fieldDeco(hint: 'Any issues or observations…'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  InputDecoration _fieldDeco({required String hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintStyle: const TextStyle(color: ErpColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: ErpColors.bgBase,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ErpColors.accentBlue, width: 2),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: ErpColors.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2));
}

// ── Sticky submit / cancel bar ────────────────────────────────
class _BulkSubmitBar extends StatelessWidget {
  final ShiftControllerView c;
  const _BulkSubmitBar({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: const Border(top: BorderSide(color: ErpColors.borderLight)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, -3)),
      ],
    ),
    child: Obx(() => Row(children: [
      // Cancel
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ErpColors.borderLight),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: c.isBulkSaving.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 12),
      // Submit all
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue,
            disabledBackgroundColor:
            ErpColors.accentBlue.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: c.isBulkSaving.value
              ? null
              : () async {
            final ok = await c.bulkSave();
            if (ok && context.mounted) Navigator.of(context).pop();
          },
          icon: c.isBulkSaving.value
              ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          label: Text(
            c.isBulkSaving.value
                ? 'Saving…'
                : 'Submit All  (${c.bulkEntries.length})',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ])),
  );
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.check_circle_outline,
          size: 52, color: ErpColors.successGreen),
      const SizedBox(height: 14),
      const Text('No open shifts',
          style: TextStyle(
              color: ErpColors.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('All shifts have been completed',
          style: TextStyle(
              color: ErpColors.textMuted, fontSize: 13)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  SCROLLABLE TIMER FIELD
//  Three drums for HH / MM / SS.
//  Each drum is a ListWheelScrollView that loops.
//  Writes "HH:MM:SS" back to the TextEditingController on
//  every scroll so BulkEntry.timerCtrl stays in sync.
// ══════════════════════════════════════════════════════════════
class _ScrollTimerField extends StatefulWidget {
  final TextEditingController controller;
  const _ScrollTimerField({required this.controller});

  @override
  State<_ScrollTimerField> createState() => _ScrollTimerFieldState();
}

class _ScrollTimerFieldState extends State<_ScrollTimerField> {
  late FixedExtentScrollController _hCtrl, _mCtrl, _sCtrl;
  int _h = 0, _m = 0, _s = 0;

  // How many items in the flat list (looping via large count)
  static const int _loopCount = 1000;

  @override
  void initState() {
    super.initState();
    // Parse initial value from the controller text "HH:MM:SS"
    final parts = widget.controller.text.split(':');
    _h = int.tryParse(parts.isNotEmpty  ? parts[0] : '0') ?? 0;
    _m = int.tryParse(parts.length > 1  ? parts[1] : '0') ?? 0;
    _s = int.tryParse(parts.length > 2  ? parts[2] : '0') ?? 0;

    // Initialise each drum at the midpoint of the large list so
    // the user can scroll both up and down without hitting a boundary.
    final midH = (_loopCount ~/ 2 ~/ 12) * 12 + _h;
    final midM = (_loopCount ~/ 2 ~/ 60) * 60 + _m;
    final midS = (_loopCount ~/ 2 ~/ 60) * 60 + _s;

    _hCtrl = FixedExtentScrollController(initialItem: midH);
    _mCtrl = FixedExtentScrollController(initialItem: midM);
    _sCtrl = FixedExtentScrollController(initialItem: midS);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    super.dispose();
  }

  void _updateController() {
    widget.controller.text =
    '${_h.toString().padLeft(2, '0')}:'
        '${_m.toString().padLeft(2, '0')}:'
        '${_s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ErpColors.borderLight),
    ),
    child: Row(
      children: [
        Expanded(child: _Drum(
          ctrl:      _hCtrl,
          mod:       12,
          label:     'HH',
          loopCount: _loopCount,
          onChanged: (v) { _h = v; _updateController(); },
        )),

        Expanded(child: _Drum(
          ctrl:      _mCtrl,
          mod:       60,
          label:     'MM',
          loopCount: _loopCount,
          onChanged: (v) { _m = v; _updateController(); },
        )),

        Expanded(child: _Drum(
          ctrl:      _sCtrl,
          mod:       60,
          label:     'SS',
          loopCount: _loopCount,
          onChanged: (v) { _s = v; _updateController(); },
        )),
      ],
    ),
  );
}

// ── Single drum column ────────────────────────────────────────
class _Drum extends StatelessWidget {
  final FixedExtentScrollController ctrl;
  final int mod;            // 24 for hours, 60 for min/sec
  final int loopCount;
  final String label;
  final void Function(int) onChanged;

  const _Drum({
    required this.ctrl,
    required this.mod,
    required this.loopCount,
    required this.label,
    required this.onChanged,
  });

  static const double _itemH   = 40.0;
  static const double _visible = 3;   // number of items shown

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Column label
        Text(label,
            style: const TextStyle(
                color: ErpColors.textMuted,
                fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 4),
        SizedBox(
          height: _itemH * _visible,
          child: Stack(children: [
            // Centre-row highlight
            Center(
              child: Container(
                height: _itemH,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: ErpColors.accentBlue.withOpacity(0.30)),
                ),
              ),
            ),
            // Fade out top and bottom items
            IgnorePointer(
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.22, 0.78, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstOut,
                child: const SizedBox.expand(),
              ),
            ),
            // The wheel
            ListWheelScrollView(
              controller: ctrl,
              itemExtent: _itemH,
              perspective: 0.002,
              diameterRatio: 1.8,
              overAndUnderCenterOpacity: 0.35,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => onChanged(i % mod),
              children: List.generate(loopCount, (i) {
                final value = i % mod;
                return Center(
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 20, fontWeight: FontWeight.w900,
                        height: 1),
                  ),
                );
              }),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Colon separator between drums ────────────────────────────
class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 18, left: 3, right: 3),
    child: Text(':',
        style: TextStyle(
            color: ErpColors.textPrimary,
            fontSize: 22, fontWeight: FontWeight.w900,
            height: 1)),
  );
}
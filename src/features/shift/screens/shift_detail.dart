import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_detail.dart';
import '../models/shift_detail_view_model.dart';

// ══════════════════════════════════════════════════════════════
//  SHIFT DETAIL PAGE
//
//  FIX: converted StatelessWidget → StatefulWidget so we can
//       register an ever() listener in initState() and call
//       Navigator.pop(context) when the save succeeds.
//
//  Previously the controller called Get.off(ShiftListPage()),
//  which: (a) required importing the list screen into the
//  controller causing a circular import, and (b) reset the
//  entire navigation stack instead of popping one level.
// ══════════════════════════════════════════════════════════════
class ShiftDetailPage extends StatefulWidget {
  final String shiftId;

  const ShiftDetailPage({super.key, required this.shiftId});

  @override
  State<ShiftDetailPage> createState() => _ShiftDetailPageState();
}

class _ShiftDetailPageState extends State<ShiftDetailPage> {
  late final ShiftDetailController controller;

  @override
  void initState() {
    super.initState();
    Get.delete<ShiftDetailController>(force: true);
    controller = Get.put(ShiftDetailController(widget.shiftId));

    // FIX: listen for save completion here where context is valid.
    // The controller only sets saveSuccess = true; all navigation
    // lives in the screen — no context required in the controller.
    ever(controller.saveSuccess, (bool success) {
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: "Shift Entry"),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }

        final shift = controller.shift.value;
        if (shift == null) {
          return const Center(
            child: Text("Shift not found",
                style: TextStyle(color: ErpColors.textSecondary)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shiftHeader(shift),
              const SizedBox(height: 14),
              ErpSectionCard(
                title: "Machine Info",
                icon: Icons.precision_manufacturing_outlined,
                child: Column(
                  children: [
                    ErpInfoRow("Machine ID", shift.machineName),
                    ErpInfoRow("Job Order", "#${shift.jobNo}"),
                    const SizedBox(height: 8),
                    if (shift.runningElastics.isNotEmpty) ...[
                      const Text("RUNNING ELASTICS",
                          style: ErpTextStyles.sectionHeader),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: shift.runningElastics
                            .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ErpColors.statusOpenBg,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: ErpColors.statusOpenBorder),
                          ),
                          child: Text(e,
                              style: const TextStyle(
                                color: ErpColors.statusOpenText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                        ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              shift.status == "open"
                  ? _entryForm(controller)
                  : _summaryCard(shift),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _shiftHeader(ShiftDetailViewModel shift) {
    final isNight = shift.shift.toLowerCase().contains('night');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ErpColors.navyMid, ErpColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isNight ? ErpColors.accentBlue : const Color(0xFFF59E0B),
            width: 4,
          ),
        ),
      ),
      child: Row(children: [
        Icon(
          isNight ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
          color: isNight ? ErpColors.accentLight : const Color(0xFFFBBF24),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              "${shift.shift.toUpperCase()} SHIFT",
              style: const TextStyle(
                color: ErpColors.textOnDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.yMMMEd().format(DateTime.parse(shift.date)),
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              shift.employeeName,
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: shift.status == "open"
                ? ErpColors.statusOpenBg
                : ErpColors.statusCompletedBg,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            shift.status.toUpperCase(),
            style: TextStyle(
              color: shift.status == "open"
                  ? ErpColors.statusOpenText
                  : ErpColors.statusCompletedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _entryForm(ShiftDetailController ctrl) {
    return ErpFormSection(
      title: "Production Entry",
      children: [
        TextField(
          controller: ctrl.productionController,
          keyboardType: TextInputType.number,
          decoration: ErpDecorations.formInput(
            "Production (meters)",
            hint: "e.g. 850",
            prefix: const Icon(Icons.straighten,
                size: 18, color: ErpColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        const _FieldLabel("Run Time"),
        const SizedBox(height: 6),
        _ScrollTimerField(controller: ctrl.timerController),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl.feedbackController,
          maxLines: 2,
          decoration: ErpDecorations.formInput(
            "Feedback / Notes",
            hint: "Any issues or observations...",
            prefix: const Icon(Icons.notes,
                size: 18, color: ErpColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        Obx(() => SizedBox(
          width: double.infinity,
          child: ErpPrimaryButton(
            label: "Submit Production",
            icon: Icons.check_circle_outline,
            isLoading: ctrl.isSaving.value,
            onPressed: () {
              final text = ctrl.productionController.text.trim();
              if (text.isEmpty || int.tryParse(text) == null) {
                Get.snackbar(
                  "Validation Error",
                  "Please enter a valid production amount",
                  backgroundColor: ErpColors.warningAmber,
                  colorText: Colors.white,
                );
                return;
              }
              ctrl.saveShift();
              // Navigation is handled by ever(controller.saveSuccess)
              // registered in initState — Navigator.pop fires there.
            },
          ),
        )),
      ],
    );
  }

  Widget _summaryCard(ShiftDetailViewModel s) {
    return ErpSectionCard(
      title: "Shift Completed",
      icon: Icons.check_circle_outline,
      accentColor: ErpColors.successGreen,
      child: Column(children: [
        ErpInfoRow("Production", "${s.production} meters"),
        ErpInfoRow("Run Time", s.timer),
        if (s.feedback.isNotEmpty) ErpInfoRow("Feedback", s.feedback),
      ]),
    );
  }
}
// ══════════════════════════════════════════════════════════════
//  SCROLLABLE TIMER FIELD
//  Three drums for HH / MM / SS.
//  Writes "HH:MM:SS" back to the TextEditingController on
//  every scroll so the controller value stays in sync.
// ══════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        color: ErpColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600),
  );
}

class _ScrollTimerField extends StatefulWidget {
  final TextEditingController controller;
  const _ScrollTimerField({required this.controller});

  @override
  State<_ScrollTimerField> createState() => _ScrollTimerFieldState();
}

class _ScrollTimerFieldState extends State<_ScrollTimerField> {
  late FixedExtentScrollController _hCtrl, _mCtrl, _sCtrl;
  int _h = 0, _m = 0, _s = 0;

  // Large count gives the feeling of an infinite scroll in both
  // directions without hitting a hard boundary.
  static const int _loopCount = 1000;

  @override
  void initState() {
    super.initState();
    // Seed from the controller's current text ("HH:MM:SS").
    final parts = widget.controller.text.split(':');
    _h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    _m = int.tryParse(parts.length > 1  ? parts[1] : '0') ?? 0;
    _s = int.tryParse(parts.length > 2  ? parts[2] : '0') ?? 0;

    // Place each drum at the midpoint of its list so the user can
    // scroll freely in both directions without a hard stop.
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

  void _sync() {
    widget.controller.text =
    '${_h.toString().padLeft(2, '0')}:'
        '${_m.toString().padLeft(2, '0')}:'
        '${_s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ErpColors.borderLight),
      boxShadow: [
        BoxShadow(
          color: ErpColors.navyDark.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Drum(
          ctrl: _hCtrl, mod: 12, label: 'HH',
          loopCount: _loopCount,
          onChanged: (v) { _h = v; _sync(); },
        ),
        const _Sep(),
        _Drum(
          ctrl: _mCtrl, mod: 60, label: 'MM',
          loopCount: _loopCount,
          onChanged: (v) { _m = v; _sync(); },
        ),
        const _Sep(),
        _Drum(
          ctrl: _sCtrl, mod: 60, label: 'SS',
          loopCount: _loopCount,
          onChanged: (v) { _s = v; _sync(); },
        ),
      ],
    ),
  );
}

// ── Single drum column ────────────────────────────────────────
class _Drum extends StatelessWidget {
  final FixedExtentScrollController ctrl;
  final int mod, loopCount;
  final String label;
  final void Function(int) onChanged;

  const _Drum({
    required this.ctrl,
    required this.mod,
    required this.loopCount,
    required this.label,
    required this.onChanged,
  });

  static const double _itemH   = 44.0;
  static const double _visible = 3.0;   // rows visible at once

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Column label (HH / MM / SS)
        Text(
          label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 54,
          height: _itemH * _visible,
          child: Stack(children: [
            // Highlight band behind the centre row
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
            // Top/bottom fade mask
            IgnorePointer(
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white,
                  ],
                  stops: [0.0, 0.22, 0.78, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstOut,
                child: const SizedBox.expand(),
              ),
            ),
            // Wheel
            ListWheelScrollView(
              controller: ctrl,
              itemExtent: _itemH,
              perspective: 0.002,
              diameterRatio: 1.8,
              overAndUnderCenterOpacity: 0.35,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => onChanged(i % mod),
              children: List.generate(
                loopCount,
                    (i) => Center(
                  child: Text(
                    (i % mod).toString().padLeft(2, '0'),
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Colon separator ───────────────────────────────────────────
class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 20, left: 3, right: 3),
    child: Text(
      ':',
      style: TextStyle(
          color: ErpColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1),
    ),
  );
}
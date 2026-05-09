import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/erp_theme.dart';
import '../controllers/shift_production_controller.dart';

class ShiftProductionPage extends StatelessWidget {
  const ShiftProductionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ShiftProductionController(), tag: 'shift-prod');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }
        if (c.errorMsg.value != null) {
          return _Empty(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load shifts',
            subtitle: c.errorMsg.value!,
            cta: 'Retry',
            onTap: c.fetchOpen,
          );
        }
        if (c.shifts.isEmpty) {
          return _Empty(
            icon: Icons.event_busy_outlined,
            title: 'No open shifts',
            subtitle:
                'Your supervisor hasn\'t scheduled or assigned a shift to you yet.',
            cta: 'Refresh',
            onTap: c.fetchOpen,
          );
        }
        return RefreshIndicator(
          onRefresh: c.fetchOpen,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: c.shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ShiftCard(c: c, shift: c.shifts[i]),
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Enter Shift Production',
            style: ErpTextStyles.pageTitle),
      );
}

class _ShiftCard extends StatelessWidget {
  final ShiftProductionController c;
  final Map<String, dynamic> shift;
  const _ShiftCard({required this.c, required this.shift});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final raw = shift['date']?.toString();
    String when = '—';
    if (raw != null) {
      try { when = fmt.format(DateTime.parse(raw).toLocal()); } catch (_) {}
    }
    final shiftLabel = shift['shift']?.toString() ?? '—';
    final machine    = (shift['machine'] is Map)
        ? (shift['machine']['ID']?.toString() ?? '—')
        : '—';
    final orderRunning = (shift['machine'] is Map &&
            shift['machine']['orderRunning'] is Map)
        ? (shift['machine']['orderRunning']['orderNo']?.toString() ?? '')
        : '';

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ErpColors.statusOpenBg,
                  border: Border.all(color: ErpColors.statusOpenBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OPEN',
                    style: TextStyle(
                        color: ErpColors.statusOpenText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Text(shiftLabel.toUpperCase(),
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  color: ErpColors.textMuted, size: 20),
            ]),
            const SizedBox(height: 8),
            _kv(Icons.calendar_today_outlined, 'Date', when),
            _kv(Icons.precision_manufacturing_outlined, 'Machine', machine),
            if (orderRunning.isNotEmpty)
              _kv(Icons.receipt_long_outlined, 'Order #', orderRunning),
          ],
        ),
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, size: 12, color: ErpColors.textMuted),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 11)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  void _openSheet(BuildContext ctx) {
    c.selectShift(shift);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EnterProductionSheet(c: c),
      ),
    );
  }
}

class _EnterProductionSheet extends StatelessWidget {
  final ShiftProductionController c;
  const _EnterProductionSheet({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: ErpColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Close Shift',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'Enter the production count for this shift. Saving closes the shift.',
            style: TextStyle(
                color: ErpColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: c.productionCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: ErpDecorations.formInput(
              'Production *',
              hint: 'e.g. 320',
              suffix: const Padding(
                padding: EdgeInsets.only(right: 12, top: 14),
                child: Text('m',
                    style: TextStyle(
                        color: ErpColors.textMuted, fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: c.timerCtrl,
            decoration: ErpDecorations.formInput(
              'Timer',
              hint: 'e.g. 7h 30m or 27000 (sec)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: c.feedbackCtrl,
            maxLines: 2,
            decoration: ErpDecorations.formInput(
              'Feedback (optional)',
              hint: 'Anything to flag for your supervisor',
            ),
          ),
          const SizedBox(height: 20),
          Obx(() => SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    disabledBackgroundColor:
                        ErpColors.accentBlue.withOpacity(0.55),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: c.isSubmitting.value
                      ? null
                      : () async {
                          final ok = await c.submit();
                          if (ok && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                  icon: c.isSubmitting.value
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18),
                  label: Text(
                    c.isSubmitting.value ? 'Saving…' : 'Close Shift',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, cta;
  final VoidCallback onTap;
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ErpColors.borderLight),
              ),
              child: Icon(icon, color: ErpColors.textMuted, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.accentBlue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(cta,
                  style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/notify_settings_controller.dart';

// ══════════════════════════════════════════════════════════════
//  RECIPIENT EVENTS SHEET
//
//  Bottom sheet listing every known WhatsApp event with a switch
//  per event, scoped to one recipient. Toggling a switch fires a
//  PUT /settings with the per-event recipients[] re-computed.
//
//  Source-of-truth note: the backend's events.<ev>.recipients[] is
//  what governs delivery; an empty list falls through to the global
//  list. The controller's setEventSubscription handles materializing
//  the global list when needed so flipping one recipient off doesn't
//  accidentally unsubscribe everyone else.
// ══════════════════════════════════════════════════════════════

class RecipientEventsSheet extends StatelessWidget {
  final String number;
  const RecipientEventsSheet({super.key, required this.number});

  static Future<void> show(BuildContext context, String number) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => RecipientEventsSheet(number: number),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = NotifySettingsController.instance;
    final mediaH = MediaQuery.of(context).size.height;
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: ErpColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone,
                      color: ErpColors.accentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notifications for',
                          style: TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 12)),
                        Text(number,
                          style: const TextStyle(
                              color: ErpColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.info_outline,
                      size: 16, color: ErpColors.textSecondary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Toggle which WhatsApp events this number receives. '
                      'Other recipients keep their current subscriptions.',
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final names = ctrl.knownEvents;
                if (names.isEmpty) {
                  return const Center(child: Text('No events known yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  itemCount: names.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: ErpColors.borderLight),
                  itemBuilder: (_, i) {
                    final ev = names[i];
                    final isOn = ctrl.isSubscribed(number, ev);
                    final tier = (ctrl.events[ev]?['tier'] ?? '').toString();
                    final overridden = ctrl.eventHasExplicitOverride(ev);
                    return SwitchListTile.adaptive(
                      title: Text(_humanize(ev),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ErpColors.textPrimary)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            _Pill(text: tier.isEmpty ? 'realtime' : tier),
                            const SizedBox(width: 6),
                            if (overridden)
                              const _Pill(
                                  text: 'custom recipients',
                                  color: ErpColors.warningAmber),
                          ],
                        ),
                      ),
                      value: isOn,
                      activeColor: ErpColors.accentBlue,
                      onChanged: ctrl.saving.value
                          ? null
                          : (v) async {
                              final ok = await ctrl.setEventSubscription(
                                  number, ev, v);
                              if (!ok && context.mounted) {
                                Get.snackbar(
                                  'Could not update',
                                  ctrl.lastError.value,
                                  backgroundColor: ErpColors.errorRed,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              }
                            },
                    );
                  },
                );
              }),
            ),
            Obx(() => ctrl.saving.value
                ? const LinearProgressIndicator()
                : SizedBox(height: mediaH > 0 ? 4 : 0)),
          ],
        ),
      ),
    );
  }

  // Turn camelCase event names into friendly labels.
  static String _humanize(String camel) {
    final spaced = camel
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
            (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'(\d+)$'),
            (m) => ' ${m[1]}');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, this.color = ErpColors.accentBlue});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

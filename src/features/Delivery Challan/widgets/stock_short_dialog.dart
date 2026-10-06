import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';

/// Reason prompt shown when the backend refuses a challan with
/// `code: "DC_STOCK_SHORT"`: it ships more of an elastic than the stock
/// shows on hand. Returns the trimmed reason (at least
/// [minReasonLength] characters) when the user chooses to send it
/// anyway, or `null` when they cancel.
///
/// [shortfalls] is `details.shortfalls` from the 409:
/// `[{ name, shipping, onHand, short }]`.
Future<String?> showStockShortDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> shortfalls,
  int minReasonLength = 8,
}) async {
  final reasonCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String fmt(dynamic raw) {
    final v = (raw as num?)?.toDouble() ?? 0;
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  try {
    return await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: ErpColors.warningAmber, size: 22),
              const SizedBox(width: 8),
              const Text('Not enough in stock',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This challan ships more than the stock shows on hand.',
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 12),
                    ),
                    for (final s in shortfalls) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: ErpColors.warningAmber
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['name']?.toString() ?? 'Elastic',
                                style: TextStyle(
                                    color: ErpColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                              'Shipping ${fmt(s['shipping'])} · '
                              'In stock ${fmt(s['onHand'])} · '
                              'Short ${fmt(s['short'])}',
                              style: TextStyle(
                                  color: ErpColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Sending it anyway takes out what is in stock (it '
                      'does not go below zero) and keeps your reason on '
                      'the challan.',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: ErpDecorations.formInput(
                        'Reason *',
                        hint: 'e.g. Packed this morning, packing entry not made yet',
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < minReasonLength) {
                          return 'Reason must be at least $minReasonLength characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          actions: [
            TextButton(
              // Navigator.pop on the dialog's own context: Get.back would
              // pop a snackbar instead if one is still on screen.
              onPressed: () => Navigator.of(dialogCtx).pop(null),
              child: Text('Cancel',
                  style: TextStyle(color: ErpColors.textSecondary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.solidError,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(dialogCtx).pop(reasonCtrl.text.trim());
              },
              icon: const Icon(Icons.local_shipping_outlined, size: 16),
              label: const Text('Send anyway',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  } finally {
    // Dispose after the pop animation; the field can rebuild one last
    // frame while the route animates out.
    Future.delayed(const Duration(milliseconds: 400), reasonCtrl.dispose);
  }
}

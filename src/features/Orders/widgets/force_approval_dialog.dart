import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';

/// Alert + reason prompt shown when the backend rejects an order
/// approval with `code: "INSUFFICIENT_STOCK"`. Returns the trimmed
/// reason (length >= 8) when the admin confirms, or `null` when
/// they cancel.
///
/// The shortfall map is the structured payload the backend returns
/// alongside the 400; render it inline so the admin can see exactly
/// what they're overriding.
Future<String?> showForceApprovalDialog({
  required BuildContext context,
  required Map<String, dynamic> shortfall,
  required String originalMessage,
}) async {
  final reasonCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final materialName = shortfall['materialName']?.toString() ?? 'a material';
  final available = (shortfall['available'] as num?)?.toDouble() ?? 0;
  final required = (shortfall['required'] as num?)?.toDouble() ?? 0;
  final short = (shortfall['short'] as num?)?.toDouble() ?? (required - available);

  String fmt(double v) {
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
              SizedBox(width: 8),
              Text('Insufficient stock',
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
                      originalMessage.isNotEmpty
                          ? originalMessage
                          : 'Raw-material stock is short of the order requirement.',
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: ErpColors.warningAmber.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(materialName,
                              style: TextStyle(
                                  color: ErpColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Need ${fmt(required)} kg · '
                            'Available ${fmt(available)} kg · '
                            'Short ${fmt(short)} kg',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Forcing approval will deduct what is available '
                      '(remaining clamped at 0) and record the override '
                      'in the order audit trail. Provide a reason so the '
                      'next reviewer can understand the call.',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: ErpDecorations.formInput(
                        'Reason *',
                        hint:
                            'e.g. New stock arriving tomorrow morning',
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 8) {
                          return 'Reason must be at least 8 characters';
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
              // Navigator.pop on the dialog's own context — Get.back
              // pops the topmost GetX overlay, which is the snackbar
              // (not this dialog) whenever an error toast from the
              // failed approve is still on screen.
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
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text('Force Approve',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  } finally {
    // Defer disposal past the dialog's pop animation — the
    // TextFormField can rebuild one final frame while the route is
    // animating out, and a synchronous dispose here would throw
    // "used after being disposed".
    Future.delayed(const Duration(milliseconds: 400), reasonCtrl.dispose);
  }
}

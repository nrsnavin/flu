import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/PurchaseOrder/services/theme.dart';

// Shared confirm-with-reason dialog used by edit/delete flows that write an
// audit fingerprint. Returns the trimmed reason, or null if cancelled.
Future<String?> showReasonDialog({
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) {
  final ctrl = TextEditingController();
  return Get.dialog<String>(
    StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null)
              Text(message, style: const TextStyle(color: ErpColors.textSecondary, fontSize: 12)),
            if (message != null) const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setLocal(() {}),
              decoration: InputDecoration(
                labelText: 'Reason *',
                hintText: 'Why is this being changed? (recorded in the audit log)',
                hintStyle: const TextStyle(fontSize: 11, color: ErpColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: null), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: danger ? ErpColors.errorRed : ErpColors.accentBlue, elevation: 0),
            onPressed: ctrl.text.trim().length < 3 ? null : () => Get.back(result: ctrl.text.trim()),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

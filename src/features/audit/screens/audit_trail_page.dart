import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/audit_controller.dart';

// ══════════════════════════════════════════════════════════════
//  AUDIT TRAIL PAGE
//  Read-only plant-wide fingerprint feed. Mirrors the web Audit Trail.
// ══════════════════════════════════════════════════════════════
class AuditTrailPage extends StatelessWidget {
  const AuditTrailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AuditController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Audit Trail',
        subtitle: 'Recent activity across orders, jobs, POs & DCs',
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.entries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 8),
                  Text(ctrl.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  ErpPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: ctrl.fetch,
                  ),
                ],
              ),
            ),
          );
        }
        if (ctrl.entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 48, color: ErpColors.textMuted),
                SizedBox(height: 10),
                Text('No audit activity yet',
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: ctrl.entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AuditCard(data: ctrl.entries[i]),
          ),
        );
      }),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AuditCard({required this.data});

  String get _entityLabel {
    final type = (data['entityType'] as String?) ?? '';
    final no = data['entityNo'];
    String pretty;
    switch (type) {
      case 'Order':
        pretty = 'Order';
        break;
      case 'JobOrder':
        pretty = 'Job';
        break;
      case 'PurchaseOrder':
        pretty = 'PO';
        break;
      case 'DeliveryChallan':
        pretty = 'DC';
        break;
      default:
        pretty = type;
    }
    return no == null ? pretty : '$pretty #$no';
  }

  String _when() {
    final at = data['at'] as String?;
    if (at == null) return '';
    try {
      return DateFormat('dd MMM, hh:mm a').format(DateTime.parse(at).toLocal());
    } catch (_) {
      return at;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = data['actor'] as Map<String, dynamic>?;
    final actorName = actor?['name'] as String? ?? 'System';
    final role = actor?['role'] as String?;
    final reason = data['reason'] as String?;
    final shortId = data['shortId'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (data['label'] as String?) ?? 'Activity',
                  style: TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(_when(),
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ErpColors.statusOpenBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ErpColors.statusOpenBorder),
                ),
                child: Text(_entityLabel,
                    style: TextStyle(
                        color: ErpColors.statusOpenText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  role != null && role.isNotEmpty
                      ? '$actorName · $role'
                      : actorName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          if (reason != null && reason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reason: ${reason.trim()}',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
          if (shortId != null && shortId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('#$shortId',
                style: TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ],
        ],
      ),
    );
  }
}

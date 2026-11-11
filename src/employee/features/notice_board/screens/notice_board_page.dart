import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/notice_board_controller.dart';

class NoticeBoardPage extends StatelessWidget {
  const NoticeBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpNoticeBoardController(), tag: 'notice-board');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Notice Board', style: ErpTextStyles.pageTitle),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _Error(msg: c.errorMsg.value!, onRetry: c.fetch);
        }
        if (c.notices.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Icon(Icons.campaign_outlined,
                  size: 44, color: ErpColors.textMuted),
              SizedBox(height: 10),
              Center(
                child: Text('No active notices.',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 13)),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: c.notices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _NoticeCard(n: c.notices[i]),
          ),
        );
      }),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> n;
  const _NoticeCard({required this.n});
  @override
  Widget build(BuildContext context) {
    final title    = SafeJson.asString(n['title'], '—');
    final body     = SafeJson.asString(n['body']);
    final type     = SafeJson.asString(n['type'], 'info').toLowerCase();
    final audience = SafeJson.asString(n['audience'], 'all').toLowerCase();
    final dept     = SafeJson.asString(n['department']);
    final pinned   = SafeJson.asBool(n['isPinned']);
    final dt       = SafeJson.asLocalDateTime(n['createdAt']);
    final when     = dt == null ? '' : DateFormat('dd MMM yyyy').format(dt);
    final color = _typeColor(type);
    final icon  = _typeIcon(type);

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (pinned) ...[
                      const Icon(Icons.push_pin,
                          size: 12, color: ErpColors.warningAmber),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    _Chip(label: type.toUpperCase(), color: color),
                    const SizedBox(width: 4),
                    if (audience == 'department' && dept.isNotEmpty)
                      _Chip(
                          label: dept.toUpperCase(),
                          color: ErpColors.accentBlue),
                  ]),
                ],
              ),
            ),
            if (when.isNotEmpty)
              Text(when,
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(body,
                style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 13,
                    height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800)),
      );
}

Color _typeColor(String t) {
  switch (t) {
    case 'safety':      return ErpColors.errorRed;
    case 'warning':     return ErpColors.warningAmber;
    case 'policy':      return ErpColors.accentBlue;
    case 'celebration': return ErpColors.successGreen;
    default:            return ErpColors.accentBlue;
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'safety':      return Icons.health_and_safety_outlined;
    case 'warning':     return Icons.warning_amber_outlined;
    case 'policy':      return Icons.policy_outlined;
    case 'celebration': return Icons.celebration_outlined;
    default:            return Icons.campaign_outlined;
  }
}

class _Error extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _Error({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: ErpColors.textMuted, size: 36),
              const SizedBox(height: 10),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

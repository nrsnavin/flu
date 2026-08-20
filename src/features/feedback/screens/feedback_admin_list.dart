import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/feedback_admin_controller.dart';

// ══════════════════════════════════════════════════════════════
//  FEEDBACK ADMIN LIST PAGE
//  Admins view all employee feedback (complaints + suggestions),
//  filter by status / type, and open an item to reply.
// ══════════════════════════════════════════════════════════════
class FeedbackAdminListPage extends StatelessWidget {
  const FeedbackAdminListPage({super.key});

  static const _statuses = [
    "all", "open", "in_review", "resolved", "rejected", "closed",
  ];
  static const _types = ["all", "complaint", "suggestion"];

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(FeedbackAdminController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Employee Feedback',
        subtitle: 'Complaints & suggestions',
      ),
      body: Column(
        children: [
          _Filters(
            statuses: _statuses,
            types: _types,
            ctrl: ctrl,
          ),
          Expanded(
            child: Obx(() {
              if (ctrl.loading.value && ctrl.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ctrl.errorMsg.value != null && ctrl.items.isEmpty) {
                return _ErrorState(message: ctrl.errorMsg.value!, onRetry: ctrl.fetch);
              }
              if (ctrl.items.isEmpty) {
                return const _EmptyState();
              }
              return RefreshIndicator(
                onRefresh: ctrl.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: ctrl.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final fb = ctrl.items[i];
                    return _FeedbackCard(
                      data: fb,
                      onTap: () => Get.to(() => FeedbackDetailPage(feedback: fb))
                          ?.then((_) => ctrl.fetch()),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────
class _Filters extends StatelessWidget {
  final List<String> statuses;
  final List<String> types;
  final FeedbackAdminController ctrl;
  const _Filters({required this.statuses, required this.types, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Obx(() => _Dropdown(
              label: 'Status',
              value: ctrl.status.value,
              options: statuses,
              onChanged: (v) => ctrl.setStatus(v),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Obx(() => _Dropdown(
              label: 'Type',
              value: ctrl.type.value,
              options: types,
              onChanged: (v) => ctrl.setType(v),
            )),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: TextStyle(
            color: ErpColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          hint: Text(label, style: ErpTextStyles.fieldLabel),
          items: options
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_capitalize(s)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s.replaceAll('_', ' ').split(' ').map((w) =>
      w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

// ── Single feedback card ──────────────────────────────────────
class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _FeedbackCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type     = data['type']     as String? ?? 'complaint';
    final category = data['category'] as String? ?? 'other';
    final status   = data['status']   as String? ?? 'open';
    final subject  = data['subject']  as String? ?? '';
    final body     = data['body']     as String? ?? '';
    final isAnon   = data['isAnonymous'] == true;
    final emp      = data['employee'] as Map?;
    final empName  = isAnon
        ? 'Anonymous'
        : (emp?['name'] as String? ?? 'Unknown employee');
    final dept     = isAnon ? '' : (emp?['department'] as String? ?? '');
    final createdAt = data['createdAt'] as String?;

    String dateLabel = '';
    if (createdAt != null) {
      try {
        dateLabel = DateFormat('dd MMM, hh:mm a').format(DateTime.parse(createdAt).toLocal());
      } catch (_) {}
    }

    final typeColor = type == 'complaint' ? ErpColors.errorRed : ErpColors.accentBlue;

    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ErpColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      border: Border.all(color: ErpColors.borderLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(subject, style: ErpTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: ErpColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isAnon ? Icons.visibility_off_outlined : Icons.person_outline,
                    size: 14,
                    color: ErpColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dept.isEmpty ? empName : '$empName · $dept',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (dateLabel.isNotEmpty)
                    Text(dateLabel,
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status chip with semantic colouring ───────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, border, text;
    switch (status) {
      case 'resolved':
        bg = ErpColors.statusCompletedBg;
        border = ErpColors.statusCompletedBorder;
        text = ErpColors.statusCompletedText;
        break;
      case 'in_review':
        bg = ErpColors.statusPartialBg;
        border = ErpColors.statusPartialBorder;
        text = ErpColors.statusPartialText;
        break;
      case 'rejected':
        bg = ErpColors.statusCancelledBg;
        border = ErpColors.statusCancelledBorder;
        text = ErpColors.statusCancelledText;
        break;
      case 'closed':
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF64748B);
        break;
      default: // open
        bg = ErpColors.statusOpenBg;
        border = ErpColors.statusOpenBorder;
        text = ErpColors.statusOpenText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _capitalize(status),
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: ErpColors.textMuted),
          SizedBox(height: 10),
          Text('No feedback found',
              style: TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: ErpColors.errorRed),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ErpPrimaryButton(label: 'Retry', icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FEEDBACK DETAIL / RESPOND PAGE
// ══════════════════════════════════════════════════════════════
class FeedbackDetailPage extends StatelessWidget {
  final Map<String, dynamic> feedback;
  const FeedbackDetailPage({super.key, required this.feedback});

  static const _statuses = ["open", "in_review", "resolved", "rejected", "closed"];

  @override
  Widget build(BuildContext context) {
    final id     = feedback['_id'] as String? ?? '';
    final tag    = 'fb-$id';
    final ctrl = Get.put(
      FeedbackRespondController(
        feedbackId: id,
        initialStatus: feedback['status'] as String? ?? 'open',
        initialResponse: feedback['response'] as String? ?? '',
      ),
      tag: tag,
    );

    final emp = feedback['employee'] as Map?;
    final isAnon = feedback['isAnonymous'] == true;
    final empName = isAnon ? 'Anonymous' : (emp?['name'] as String? ?? '—');
    final dept    = isAnon ? '—' : (emp?['department'] as String? ?? '—');

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: feedback['subject'] as String? ?? 'Feedback',
        subtitle: (feedback['type'] as String? ?? '').toUpperCase(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ErpSectionCard(
            title: 'DETAILS',
            icon: Icons.description_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ErpInfoRow('Employee', empName),
                ErpInfoRow('Department', dept),
                ErpInfoRow('Type', feedback['type']),
                ErpInfoRow('Category', feedback['category']),
                ErpInfoRow('Status', feedback['status']),
                const SizedBox(height: 8),
                Text('Message', style: ErpTextStyles.fieldLabel),
                const SizedBox(height: 4),
                Text(
                  feedback['body'] as String? ?? '',
                  style: TextStyle(
                      color: ErpColors.textPrimary, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ErpSectionCard(
            title: 'ADMIN RESPONSE',
            icon: Icons.reply_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl.responseCtrl,
                  maxLines: 5,
                  decoration: ErpDecorations.formInput(
                    'Response',
                    hint: 'Reply to the employee',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Set status', style: ErpTextStyles.fieldLabel),
                const SizedBox(height: 6),
                Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statuses.map((s) {
                        final selected = ctrl.status.value == s;
                        return ChoiceChip(
                          label: Text(_capitalize(s)),
                          selected: selected,
                          selectedColor: ErpColors.accentBlue.withOpacity(0.15),
                          backgroundColor: ErpColors.bgMuted,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? ErpColors.accentBlue
                                : ErpColors.textSecondary,
                          ),
                          side: BorderSide(
                            color: selected
                                ? ErpColors.accentBlue
                                : ErpColors.borderLight,
                          ),
                          onSelected: (_) => ctrl.status.value = s,
                        );
                      }).toList(),
                    )),
                const SizedBox(height: 16),
                Obx(() => ErpPrimaryButton(
                      label: 'Save Response',
                      icon: Icons.send_rounded,
                      isLoading: ctrl.loading.value,
                      onPressed: () async {
                        await ctrl.submit();
                        if (!ctrl.loading.value) Get.back();
                      },
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

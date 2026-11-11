import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/feedback_controller.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpFeedbackController(), tag: 'feedback');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title:
            const Text('Complaints & Suggestions', style: ErpTextStyles.pageTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        onPressed: () => _openSheet(context, c),
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text('Submit',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _Error(msg: c.errorMsg.value!, onRetry: c.fetch);
        }
        if (c.items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Icon(Icons.forum_outlined,
                  size: 44, color: ErpColors.textMuted),
              SizedBox(height: 10),
              Center(
                child: Text(
                    'No complaints or suggestions submitted yet.',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 13)),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: c.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _FeedbackCard(c: c, item: c.items[i]),
          ),
        );
      }),
    );
  }

  void _openSheet(BuildContext ctx, EmpFeedbackController c) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SubmitSheet(c: c),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final EmpFeedbackController c;
  final Map<String, dynamic> item;
  const _FeedbackCard({required this.c, required this.item});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final dt = SafeJson.asLocalDateTime(item['createdAt']);
    final when = dt == null ? '—' : fmt.format(dt);
    final type     = SafeJson.asString(item['type'], '—').toLowerCase();
    final category = SafeJson.asString(item['category']);
    final subject  = SafeJson.asString(item['subject'], '—');
    final body     = SafeJson.asString(item['body']);
    final status   = SafeJson.asString(item['status'], 'open').toLowerCase();
    final response = SafeJson.asString(item['response']);
    final id       = SafeJson.asString(item['_id']);

    final typeColor = type == 'complaint'
        ? ErpColors.errorRed
        : ErpColors.accentBlue;

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(type.toUpperCase(),
                  style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 6),
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(category.toUpperCase(),
                    style: const TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            const Spacer(),
            _StatusChip(status),
          ]),
          const SizedBox(height: 8),
          Text(subject,
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ],
          if (response.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ErpColors.statusOpenBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ErpColors.statusOpenBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent,
                      size: 14, color: ErpColors.accentBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(response,
                        style: const TextStyle(
                            color: ErpColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule, size: 12, color: ErpColors.textMuted),
            const SizedBox(width: 4),
            Text(when,
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 11)),
            const Spacer(),
            if (status == 'open')
              TextButton.icon(
                onPressed: () => c.withdraw(id),
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: ErpColors.errorRed),
                label: const Text('Withdraw',
                    style: TextStyle(
                        color: ErpColors.errorRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
          ]),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'in_review': color = ErpColors.warningAmber; break;
      case 'resolved':  color = ErpColors.successGreen; break;
      case 'rejected':  color = ErpColors.errorRed;     break;
      case 'closed':    color = ErpColors.textMuted;    break;
      default:          color = ErpColors.accentBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase().replaceAll('_', ' '),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _SubmitSheet extends StatefulWidget {
  final EmpFeedbackController c;
  const _SubmitSheet({required this.c});
  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  String _type     = 'complaint';
  String _category = 'other';
  bool   _anonymous = false;
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: SingleChildScrollView(
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
            const Text('Submit Feedback',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 14),

            // Type toggle
            Row(children: [
              Expanded(
                child: _TypeToggle(
                  label: 'Complaint',
                  active: _type == 'complaint',
                  color: ErpColors.errorRed,
                  onTap: () => setState(() => _type = 'complaint'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeToggle(
                  label: 'Suggestion',
                  active: _type == 'suggestion',
                  color: ErpColors.accentBlue,
                  onTap: () => setState(() => _type = 'suggestion'),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: ErpDecorations.formInput('Category *'),
              items: const [
                DropdownMenuItem(value: 'machine',     child: Text('Machine')),
                DropdownMenuItem(value: 'safety',      child: Text('Safety')),
                DropdownMenuItem(value: 'management',  child: Text('Management')),
                DropdownMenuItem(value: 'facilities',  child: Text('Facilities')),
                DropdownMenuItem(value: 'payroll',     child: Text('Payroll')),
                DropdownMenuItem(value: 'other',       child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _subjectCtrl,
              decoration: ErpDecorations.formInput(
                'Subject *',
                hint: 'Short summary',
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: ErpDecorations.formInput(
                'Details *',
                hint: 'Explain what happened or what you propose',
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
              title: const Text('Submit anonymously',
                  style: TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Admins won\'t see your name in the list.',
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
            ),
            const SizedBox(height: 8),

            Obx(() => SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: c.isSubmitting.value
                        ? null
                        : () async {
                            final ok = await c.submit(
                              type: _type,
                              category: _category,
                              subject: _subjectCtrl.text,
                              body: _bodyCtrl.text,
                              isAnonymous: _anonymous,
                            );
                            if (ok && Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                    icon: c.isSubmitting.value
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                    label: Text(
                      c.isSubmitting.value ? 'Sending…' : 'Submit',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TypeToggle({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.12)
                : ErpColors.bgMuted,
            border: Border.all(
                color: active ? color : ErpColors.borderLight,
                width: active ? 1.5 : 1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: active ? color : ErpColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
      );
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

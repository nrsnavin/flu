import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/briefing_controller.dart';

/// Wide, attention-anchored card rendered above the suggestion
/// carousel. Shows the morning briefing summary (or a placeholder
/// while it's generating) and opens the full text on tap.
///
/// Currently sourced from a client-side mock generator; the widget
/// API stays the same once `/api/v2/advisor/briefing` lands.
class MorningBriefingCard extends StatelessWidget {
  const MorningBriefingCard({super.key});

  void _openSheet() {
    Get.bottomSheet(
      const MorningBriefingSheet(),
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BriefingController.instance;
    return Obx(() {
      final hasText = c.summary.value.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: hasText ? _openSheet : c.regenerate,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ErpColors.borderLight),
                gradient: LinearGradient(
                  colors: [
                    ErpColors.accentBlue.withOpacity(0.08),
                    ErpColors.bgSurface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: ErpColors.accentBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Morning briefing',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: ErpColors.textPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (c.isMock.value) const _MockBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (c.loading.value)
                          const _ThinkingRow()
                        else if (hasText)
                          Text(
                            _stripMarkdown(c.summary.value),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: ErpColors.textSecondary,
                              height: 1.35,
                            ),
                          )
                        else
                          Text(
                            'Tap to generate today\'s 2-line summary',
                            style: TextStyle(
                              fontSize: 12,
                              color: ErpColors.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: ErpColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  String _stripMarkdown(String s) => s.replaceAll('**', '');
}

class _MockBadge extends StatelessWidget {
  const _MockBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: ErpColors.warningAmber.withOpacity(0.14),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'MOCK',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: ErpColors.warningAmber,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 12, height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: ErpColors.accentBlue),
        ),
        SizedBox(width: 8),
        Text(
          'Thinking…',
          style: TextStyle(
            fontSize: 12,
            color: ErpColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class MorningBriefingSheet extends StatelessWidget {
  const MorningBriefingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BriefingController.instance;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: ErpColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: ErpColors.accentBlue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Morning briefing',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary,
                    ),
                  ),
                ),
                Obx(() => c.isMock.value
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ErpColors.warningAmber.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MOCK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.warningAmber,
                            letterSpacing: 0.8,
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
          Obx(() => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  c.lastRunAt.value == null
                      ? 'Not yet generated'
                      : 'Generated ${_relative(c.lastRunAt.value!)}',
                  style: TextStyle(
                      fontSize: 10, color: ErpColors.textMuted),
                ),
              )),
          Divider(height: 1, color: ErpColors.borderLight),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Obx(() {
                if (c.loading.value) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: ErpColors.accentBlue),
                      ),
                    ),
                  );
                }
                if (c.summary.value.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Tap "Regenerate" to produce today\'s briefing.',
                        style: TextStyle(
                            color: ErpColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  );
                }
                return _RichBriefing(text: c.summary.value);
              }),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, MediaQuery.of(context).padding.bottom + 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: c.regenerate,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Regenerate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Renders the briefing text, picking up `**bold**` segments so the
/// generated narrative can emphasise the top priority phrase. Kept
/// inline rather than pulling in a markdown package for one feature.
class _RichBriefing extends StatelessWidget {
  final String text;
  const _RichBriefing({required this.text});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: TextStyle(
            fontWeight: FontWeight.w800,
            color: ErpColors.textPrimary),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: ErpColors.textSecondary,
        ),
        children: spans,
      ),
    );
  }
}

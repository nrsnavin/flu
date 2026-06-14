import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../authentication/services/nav_registry.dart';
import '../screens/advisor_settings_page.dart';
import '../services/ai_advisor.dart';

/// Horizontal strip of AI-generated action suggestions rendered above
/// the KPI grid on the dashboard. Tapping a card opens the linked
/// module via `NavRegistry` so recents update consistently.
///
/// Renders nothing while loading the first time or when there are no
/// suggestions — the dashboard layout collapses cleanly.
class AISuggestionsStrip extends StatelessWidget {
  const AISuggestionsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final advisor = AIAdvisor.instance;
    return Obx(() {
      final items = advisor.suggestions.toList();
      // Always render the header so the admin knows the advisor is
      // there even when there's nothing to flag. The body switches
      // between the carousel, a loading shimmer, an "offline" hint,
      // and an "all clear" empty state.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(advisor: advisor),
          if (items.isNotEmpty)
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _SuggestionCard(s: items[i]),
              ),
            )
          else if (advisor.loading.value && advisor.lastFetchAt.value == null)
            const _StripLoading()
          else if (advisor.isOffline)
            _StripMessage(
              icon: Icons.cloud_off_rounded,
              tone: ErpColors.warningAmber,
              title: 'Advisor offline',
              subtitle: 'Could not reach most endpoints — tap refresh to retry',
            )
          else
            _StripMessage(
              icon: advisor.lastFailureCount.value > 0
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              tone: advisor.lastFailureCount.value > 0
                  ? ErpColors.warningAmber
                  : ErpColors.successGreen,
              title: advisor.lastFailureCount.value > 0
                  ? 'Partial picture'
                  : 'All clear',
              subtitle: advisor.lastFailureCount.value > 0
                  ? '${advisor.reachableRules}/${advisor.totalRules} '
                    'signals reachable · tap for details'
                  : '${advisor.totalRules} signals checked · '
                    'tap for details',
              onTap: () => _Header(advisor: advisor)._openDiagnostics(),
            ),
        ],
      );
    });
  }
}

class _Header extends StatelessWidget {
  final AIAdvisor advisor;
  const _Header({required this.advisor});

  void _openDiagnostics() {
    Get.bottomSheet(
      _DiagnosticsSheet(advisor: advisor),
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Row(
        children: [
          InkWell(
            onTap: _openDiagnostics,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ErpColors.accentBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('SUGGESTED ACTIONS',
              style: ErpTextStyles.sectionHeader),
          const SizedBox(width: 6),
          InkWell(
            onTap: _openDiagnostics,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.info_outline_rounded,
                  size: 14, color: ErpColors.textSecondary),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: advisor.refreshNow,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.refresh_rounded,
                  size: 16, color: ErpColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSheet extends StatelessWidget {
  final AIAdvisor advisor;
  const _DiagnosticsSheet({required this.advisor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('Advisor diagnostics',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary,
                    )),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Each row is one signal the advisor checks. '
              'A reached endpoint that returns zero is a genuine '
              '"nothing to flag".',
              style: TextStyle(
                  fontSize: 11, color: ErpColors.textSecondary),
            ),
          ),
          const Divider(height: 1, color: ErpColors.borderLight),
          Flexible(
            child: Obx(() {
              final rows = advisor.endpointDiagnostics.toList();
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No diagnostic data yet — refresh first.',
                        style: TextStyle(
                            color: ErpColors.textSecondary, fontSize: 12)),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: ErpColors.borderLight),
                itemBuilder: (_, i) => _DiagRow(d: rows[i]),
              );
            }),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          advisor.refreshNow();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh now'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.back();
                          Get.to(() => const AdvisorSettingsPage());
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Preferences'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
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
}

class _DiagRow extends StatelessWidget {
  final EndpointDiagnostic d;
  const _DiagRow({required this.d});

  @override
  Widget build(BuildContext context) {
    final ok    = d.reached;
    final tone  = !ok
        ? ErpColors.errorRed
        : (d.count != null && d.count! > 0)
            ? ErpColors.warningAmber
            : ErpColors.successGreen;
    final icon  = !ok
        ? Icons.cloud_off_rounded
        : (d.count != null && d.count! > 0)
            ? Icons.notifications_active_outlined
            : Icons.check_circle_outline_rounded;
    final trailing = !ok
        ? 'UNREACHED'
        : (d.count == null ? '—' : '${d.count}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: tone, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(d.path,
                    style: const TextStyle(
                      fontSize: 10,
                      color: ErpColors.textMuted,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                color: tone,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripLoading extends StatelessWidget {
  const _StripLoading();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: ErpColors.accentBlue),
      ),
    );
  }
}

class _StripMessage extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _StripMessage({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tone, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ErpColors.textSecondary,
                        )),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: ErpColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final AISuggestion s;
  const _SuggestionCard({required this.s});

  Color get _accent {
    switch (s.priority) {
      case AISuggestionPriority.high:
        return ErpColors.errorRed;
      case AISuggestionPriority.med:
        return ErpColors.warningAmber;
      case AISuggestionPriority.low:
        return ErpColors.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Material(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => NavRegistry.instance.open(s.moduleId),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: ErpColors.borderLight),
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  _accent.withOpacity(0.05),
                  ErpColors.bgSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(s.icon, color: _accent, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        s.priority.name.toUpperCase(),
                        style: TextStyle(
                          color: _accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    s.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ErpColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                if (s.inlineAction != null)
                  _InlineActionBar(action: s.inlineAction!, tone: _accent)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: _accent),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The inline button surfaces a one-tap shortcut at the bottom of a
/// card. Carries its own loading state so a slow draft fetch doesn't
/// leave the admin tapping twice.
class _InlineActionBar extends StatefulWidget {
  final AdvisorInlineAction action;
  final Color tone;
  const _InlineActionBar({required this.action, required this.tone});

  @override
  State<_InlineActionBar> createState() => _InlineActionBarState();
}

class _InlineActionBarState extends State<_InlineActionBar> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.action.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _busy ? null : _run,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: tone),
                  )
                else
                  Icon(widget.action.icon, size: 14, color: tone),
                const SizedBox(width: 6),
                Text(
                  widget.action.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

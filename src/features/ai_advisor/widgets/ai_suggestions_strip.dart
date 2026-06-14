import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../authentication/services/nav_registry.dart';
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
                    'signals reachable — '
                    '${advisor.lastFailureCount.value} endpoint'
                    '${advisor.lastFailureCount.value == 1 ? '' : 's'} '
                    'unreachable'
                  : '${advisor.totalRules} signals checked — '
                    'nothing to flag right now',
            ),
        ],
      );
    });
  }
}

class _Header extends StatelessWidget {
  final AIAdvisor advisor;
  const _Header({required this.advisor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Row(
        children: [
          Container(
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
          const SizedBox(width: 8),
          const Text('SUGGESTED ACTIONS',
              style: ErpTextStyles.sectionHeader),
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

  const _StripMessage({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
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
        ],
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

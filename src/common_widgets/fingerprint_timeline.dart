import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import '../features/PurchaseOrder/services/theme.dart';

// ════════════════════════════════════════════════════════════════
//  FINGERPRINT TIMELINE
//
//  A reusable section that renders the audit-trail
//  ("fingerprints") attached to an Order or a JobOrder.
//
//  The backend (utils/fingerprint.js) emits one fingerprint per
//  meaningful state transition, each containing:
//    code     – machine identifier (e.g. ORDER_APPROVED)
//    label    – human label
//    shortId  – first 10 chars of SHA-256, ideal for chips
//    hash     – full SHA-256 hash (tap-to-copy)
//    at       – ISO timestamp
//    actor    – { id, name, role, email? } — who performed the action
//    meta     – arbitrary JSON (qty deducted, prev/next status …)
//
//  The list is consumed verbatim from the API response (already
//  sorted newest-first by the backend).
// ════════════════════════════════════════════════════════════════

class FingerprintTimeline extends StatelessWidget {
  final List<dynamic> fingerprints;

  /// Optional label (defaults to "AUDIT TRAIL · FINGERPRINTS").
  final String title;

  const FingerprintTimeline({
    super.key,
    required this.fingerprints,
    this.title = "AUDIT TRAIL · FINGERPRINTS",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: ErpColors.navyDark.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(color: ErpColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded,
                    size: 18, color: ErpColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: ErpColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${fingerprints.length}",
                    style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          if (fingerprints.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "No actions recorded yet.",
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 12),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: List.generate(fingerprints.length, (i) {
                  final fp = fingerprints[i] as Map<String, dynamic>;
                  final isLast = i == fingerprints.length - 1;
                  return _FingerprintRow(
                    fingerprint: fp,
                    isLast: isLast,
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Single row in the timeline ─────────────────────────────────
class _FingerprintRow extends StatelessWidget {
  final Map<String, dynamic> fingerprint;
  final bool isLast;

  const _FingerprintRow({
    required this.fingerprint,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final code    = fingerprint['code']?.toString()    ?? '';
    final label   = fingerprint['label']?.toString()   ?? code;
    final shortId = fingerprint['shortId']?.toString() ?? '';
    final hash    = fingerprint['hash']?.toString()    ?? '';
    final at      = _parseDate(fingerprint['at']);
    final meta    = (fingerprint['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final actor   = _coerceActor(fingerprint['actor']);

    final accent  = _colorFor(code);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rail (dot + line) ──────────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check,
                      size: 9, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: ErpColors.borderLight,
                    ),
                  ),
              ],
            ),
          ),

          // ── Card ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Container(
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                padding:
                const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: label + shortId chip ────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: hash));
                            Get.snackbar(
                              "Fingerprint copied",
                              hash,
                              backgroundColor: ErpColors.accentBlue,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              duration:
                              const Duration(seconds: 2),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: accent.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fingerprint_rounded,
                                    size: 10, color: accent),
                                const SizedBox(width: 3),
                                Text(
                                  shortId.isEmpty ? "—" : shortId,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // ── Code (machine identifier) ────────────────
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: accent,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ── Actor row ────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 18, height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ErpColors.accentBlue
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              size: 11,
                              color: ErpColors.accentBlue),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 11,
                                color: ErpColors.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: actor['name'] ?? 'System',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                if ((actor['role'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  TextSpan(
                                    text:
                                    "  ·  ${actor['role']}".toUpperCase(),
                                    style: const TextStyle(
                                      color:
                                      ErpColors.textSecondary,
                                      fontSize: 9.5,
                                      fontWeight:
                                      FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(at),
                          style: const TextStyle(
                            fontSize: 10,
                            color: ErpColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if ((actor['email'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 24, top: 1),
                        child: Text(
                          actor['email'].toString(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: ErpColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // ── Meta details (compact) ───────────────────
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                            8, 6, 8, 6),
                        decoration: BoxDecoration(
                          color: ErpColors.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: ErpColors.borderLight),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: meta.entries
                              .where((e) => e.value != null)
                              .map((e) => _MetaPill(
                            keyName: e.key,
                            value: e.value,
                          ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _formatTime(DateTime? at) {
    if (at == null) return '—';
    final fmt = DateFormat('dd MMM yy · HH:mm');
    return fmt.format(at);
  }

  /// Backend writes actor either as a string ("system") or an object
  /// {id,name,role,email}. Normalise to a Map for the UI.
  static Map<String, dynamic> _coerceActor(dynamic raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String) {
      return {'id': raw, 'name': raw, 'role': 'system'};
    }
    return {'id': 'system', 'name': 'System', 'role': 'system'};
  }

  /// Colour-code the dot/chip by action type for visual grouping.
  static Color _colorFor(String code) {
    switch (code) {
      case 'ORDER_CREATED':
      case 'JOB_CREATED':
        return ErpColors.accentBlue;
      case 'ORDER_APPROVED':
        return ErpColors.successGreen;
      case 'RAW_MATERIAL_DEDUCTED':
        return const Color(0xFF7C3AED);
      case 'ORDER_PRODUCTION_STARTED':
      case 'JOB_STAGE_UPDATED':
        return ErpColors.warningAmber;
      case 'ORDER_COMPLETED':
      case 'JOB_COMPLETED':
        return ErpColors.successGreen;
      case 'ORDER_CANCELLED':
      case 'JOB_CANCELLED':
        return ErpColors.errorRed;
      default:
        return ErpColors.textSecondary;
    }
  }
}

// ── A small key:value pill for the meta block ──────────────────
class _MetaPill extends StatelessWidget {
  final String keyName;
  final dynamic value;
  const _MetaPill({required this.keyName, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${_humanise(keyName)}:",
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: ErpColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            _stringify(value),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: ErpColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _humanise(String k) {
    final spaced =
    k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}').trim();
    return spaced.isEmpty
        ? k
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  String _stringify(dynamic v) {
    if (v is num) {
      return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    if (v is bool) return v ? 'yes' : 'no';
    return v?.toString() ?? '—';
  }
}

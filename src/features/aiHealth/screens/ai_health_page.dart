import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  IS THE AI ACTUALLY WORKING
//
//  Nine AI surfaces shipped with no way to answer that. The planner
//  catches its own model failure into a console.warn, so a rationale
//  that broke a month ago is indistinguishable from one that works —
//  and nobody would know until somebody happened to look.
//
//  /health/ai answers four things the app could not otherwise say:
//    configured   — is there an API key at all
//    models       — which strings are in use, and which are UNPINNED
//                   aliases that can move under you without a deploy
//    prompts      — the version of each prompt in this build
//    surfaces     — per-surface accept / useful rates from the ledger
//
//  ── This screen crashed, and it was my mistake ─────────────────
//  The first version read `models` as a List. The route returns an
//  OBJECT keyed text/vision, and casting a Map to a List throws
//  immediately — so the page died on open for everyone. The lesson is
//  not "add a try/catch": it is that the shape has to be read from
//  the route, and every access here now matches app.js exactly:
//
//    models   : { text: {id, pinned}, vision: {id, pinned} }
//    prompts  : { <name>: <version>, … }
//    surfaces : [ { surface, total, decided, pending, accepted,
//                   edited, rejected, failed, acceptRate,
//                   usefulRate, avgLatencyMs, tokens{…} }, … ]
//
//  It is still read defensively — a diagnostics payload grows a field
//  whenever somebody adds a check, and it is the last screen that
//  should break because of it — but defensively now means tolerating
//  a MISSING field, not guessing at the type of a present one.
//
//  ── Admin-only, and it says so ─────────────────────────────────
//  The route is isAdmin('admin') AND gated on the /ai-health feature
//  key, which is revocable on the Users screen. A 403 here is a
//  normal state to explain, not an error to dump.
// ══════════════════════════════════════════════════════════════

class AiHealthController extends GetxController {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/health');

  final data = Rxn<Map<String, dynamic>>();
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final days = 30.obs;

  static const windows = [7, 30, 90];

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  void setDays(int d) {
    if (d == days.value) return;
    days.value = d;
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/ai', queryParameters: {'days': days.value});
      data.value = Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      errorMsg.value = (code == 403 || code == 401)
          ? 'AI health is available to administrators only.'
          : (e.response?.data is Map && e.response?.data['message'] != null
              ? e.response!.data['message'].toString()
              : 'Could not load AI health');
    } catch (_) {
      errorMsg.value = 'Could not load AI health';
    } finally {
      isLoading.value = false;
    }
  }
}

/// Read a nested map without asserting anything about what is inside.
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<dynamic> _list(dynamic v) => v is List ? v : const [];

class AiHealthPage extends StatefulWidget {
  const AiHealthPage({super.key});

  @override
  State<AiHealthPage> createState() => _AiHealthPageState();
}

class _AiHealthPageState extends State<AiHealthPage> {
  late final AiHealthController c;

  @override
  void initState() {
    super.initState();
    Get.delete<AiHealthController>(force: true);
    c = Get.put(AiHealthController());
  }

  @override
  void dispose() {
    Get.delete<AiHealthController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('AI Health'),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.data.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null) {
          return _centred(c.errorMsg.value!, onRetry: c.fetch);
        }
        final d = c.data.value;
        if (d == null) return const SizedBox.shrink();

        final configured = d['configured'] == true;
        final models = _map(d['models']);
        final prompts = _map(d['prompts']);
        final surfaces = _list(d['surfaces']);
        final degraded = d['status'] == 'degraded';

        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _windowPicker(),
              const SizedBox(height: 10),

              if (degraded) ...[
                _banner(
                  'The ledger could not be read',
                  // The route degrades on purpose rather than 500ing —
                  // telemetry breaking must not take the health check
                  // with it. Saying so is the whole point: without
                  // this, "no surfaces" would read as "the AI is idle".
                  '${d['ledgerError'] ?? 'No reason given'}\n\n'
                  'The key and model rows below are still accurate. The '
                  'acceptance rates are not — they are missing, not zero.',
                ),
                const SizedBox(height: 10),
              ],

              _card('Configured', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      configured ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: configured
                          ? ErpColors.successGreen
                          : ErpColors.errorRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        configured
                            ? 'An API key is present. The AI surfaces can run.'
                            : 'No API key on this server — every AI surface '
                                'is silently doing nothing.',
                        style: const TextStyle(
                            fontSize: 13, color: ErpColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 10),

              _card('Models', [
                if (models.isEmpty)
                  _quiet('No models reported.')
                else
                  for (final e in models.entries)
                    _modelRow(e.key, _map(e.value)),
              ]),
              const SizedBox(height: 10),

              _card('Prompt versions', [
                if (prompts.isEmpty)
                  _quiet('No prompts reported.')
                else
                  // Worth having on a phone for one reason: when output
                  // changes, the first question is whether the prompt
                  // moved or the model did. These two cards answer it.
                  for (final e in prompts.entries)
                    _kv(e.key, e.value?.toString() ?? '—'),
              ]),
              const SizedBox(height: 10),

              _card('Surfaces · last ${d['windowDays'] ?? c.days.value} days', [
                if (surfaces.isEmpty)
                  _quiet(degraded
                      ? 'Not available — the ledger query failed above.'
                      : 'No suggestions recorded in this window. That is not '
                          'the same as the AI working: it means nothing has '
                          'been asked of it, or nothing was written down.')
                else
                  for (final s in surfaces) _surfaceRow(_map(s)),
              ]),
            ],
          ),
        );
      }),
    );
  }

  Widget _windowPicker() => Obx(() => Row(
        children: [
          const Text('Window',
              style: TextStyle(fontSize: 12, color: ErpColors.textMuted)),
          const SizedBox(width: 10),
          for (final w in AiHealthController.windows)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('${w}d', style: const TextStyle(fontSize: 12)),
                selected: c.days.value == w,
                onSelected: (_) => c.setDays(w),
              ),
            ),
          const Spacer(),
          if (c.isLoading.value)
            const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ));

  /// An unpinned alias can move to a new model without a deploy, which
  /// is how output changes with nothing in the changelog.
  Widget _modelRow(String use, Map<String, dynamic> m) {
    final pinned = m['pinned'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['id']?.toString() ?? '—',
                    style: const TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary)),
                Text(use,
                    style: const TextStyle(
                        fontSize: 11, color: ErpColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            pinned ? 'pinned' : 'alias — can move',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pinned ? ErpColors.textMuted : ErpColors.warningAmber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceRow(Map<String, dynamic> s) {
    // acceptRate and usefulRate come from the SERVER, over `decided`
    // — not over `total`. Recomputing them here against total would
    // count everything still pending as a rejection and report a
    // healthy surface as failing.
    final accept = (s['acceptRate'] as num?)?.toInt();
    final useful = (s['usefulRate'] as num?)?.toInt();
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final pending = (s['pending'] as num?)?.toInt() ?? 0;
    final failed = (s['failed'] as num?)?.toInt() ?? 0;
    final latency = (s['avgLatencyMs'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s['surface']?.toString() ?? '—',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ErpColors.textPrimary)),
              ),
              Text(
                // A rate from nothing is not 0% — it is unknown, and
                // printing 0% would read as "the AI is being rejected".
                accept == null ? 'no verdicts yet' : '$accept% accepted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accept == null
                      ? ErpColors.textMuted
                      : (accept >= 50
                          ? ErpColors.successGreen
                          : ErpColors.warningAmber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              '$total suggested',
              // "Useful" is accepted OR edited — the suggestion was
              // worth having even if it needed a touch. A surface at
              // 20% accepted and 90% useful is working; reading only
              // the first number would get it switched off.
              if (useful != null) '$useful% useful',
              if (pending > 0) '$pending awaiting a verdict',
              if (failed > 0) '$failed failed',
              if (latency != null) '${latency}ms avg',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 11, color: ErpColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: ErpColors.textSecondary)),
            ),
            Text(v,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ErpColors.textPrimary)),
          ],
        ),
      );

  Widget _quiet(String s) => Text(s,
      style: const TextStyle(fontSize: 13, color: ErpColors.textSecondary));

  Widget _banner(String title, String body) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.statusPartialBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.statusPartialBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ErpColors.statusPartialText)),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
          ],
        ),
      );

  Widget _centred(String text, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ErpColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}

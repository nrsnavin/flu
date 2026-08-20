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
//  /health/ai answers three things the app could not otherwise say:
//    configured  — is there an API key at all
//    models      — which strings are in use, and which are UNPINNED
//                  aliases that can move under you without a deploy
//    surfaces    — per-surface accept / edit / reject rates from the
//                  suggestion ledger
//
//  ── Read defensively, on purpose ───────────────────────────────
//  This is a diagnostics payload: it grows a field whenever somebody
//  adds a check, and it is the last screen that should break because
//  of it. So it renders whatever shape arrives rather than binding to
//  a model that would need editing in lockstep with the server.
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

  @override
  void onInit() {
    super.onInit();
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ErpColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: c.fetch, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        final d = c.data.value;
        if (d == null) return const SizedBox.shrink();

        final configured = d['configured'] == true;
        final models = (d['models'] as List? ?? const []);
        final surfaces = (d['surfaces'] as List? ?? const []);

        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _card('Configured', [
                Row(
                  children: [
                    Icon(
                      configured ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: configured
                          ? ErpColors.statusOpenText
                          : ErpColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        configured
                            ? 'An API key is present. The AI surfaces can run.'
                            : 'No API key on this server — every AI surface is '
                              'silently doing nothing.',
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
                  const Text('No models reported.',
                      style: TextStyle(
                          fontSize: 13, color: ErpColors.textSecondary))
                else
                  for (final m in models) _modelRow(Map<String, dynamic>.from(m as Map)),
              ]),
              const SizedBox(height: 10),
              _card('Surfaces', [
                if (surfaces.isEmpty)
                  const Text(
                    'No suggestions recorded in this window. That is not the '
                    'same as the AI working — it means nothing has been asked '
                    'of it, or nothing was written down.',
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textSecondary),
                  )
                else
                  for (final s in surfaces)
                    _surfaceRow(Map<String, dynamic>.from(s as Map)),
              ]),
            ],
          ),
        );
      }),
    );
  }

  Widget _modelRow(Map<String, dynamic> m) {
    // An unpinned alias can move to a new model without a deploy, which
    // is how output changes with nothing in the changelog.
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
                Text(m['model']?.toString() ?? m['name']?.toString() ?? '—',
                    style: const TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary)),
                if (m['use'] != null)
                  Text(m['use'].toString(),
                      style: const TextStyle(
                          fontSize: 11, color: ErpColors.textMuted)),
              ],
            ),
          ),
          Text(
            pinned ? 'pinned' : 'alias — can move',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pinned ? ErpColors.textMuted : ErpColors.accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceRow(Map<String, dynamic> s) {
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final accepted = (s['accepted'] as num?)?.toInt() ?? 0;
    final rate = total == 0 ? null : (accepted / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(s['surface']?.toString() ?? '—',
                style: const TextStyle(
                    fontSize: 13, color: ErpColors.textPrimary)),
          ),
          Text(
            // A rate from nothing is not 0% — it is unknown, and
            // printing 0% would read as "the AI is being rejected".
            rate == null ? 'no data' : '$rate% accepted  ($total)',
            style: const TextStyle(
                fontSize: 12, color: ErpColors.textSecondary),
          ),
        ],
      ),
    );
  }

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

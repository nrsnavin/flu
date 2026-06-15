import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import 'ai_advisor.dart';

/// Holds the current "morning briefing" — a 2–3 sentence narrative
/// summary of the top advisor suggestions.
///
/// Calls `POST /api/v2/advisor/briefing` to get a ChatGPT-written
/// summary; falls back to a deterministic local generator (with the
/// MOCK badge surfaced in the UI) whenever the server is unreachable
/// or the key is missing. The widget surface never crashes regardless
/// of which path runs.
class BriefingController extends GetxController {
  static BriefingController get instance =>
      Get.isRegistered<BriefingController>()
          ? Get.find<BriefingController>()
          : Get.put(BriefingController(), permanent: true);

  final summary   = ''.obs;
  final loading   = false.obs;
  final isMock    = true.obs;   // flipped to false when the backend says viaLlm
  final lastRunAt = Rxn<DateTime>();

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/advisor',
  );

  /// Hits the LLM endpoint and caches the result. Re-entry-guarded
  /// by `loading` so a double-tap doesn't fire two calls. The
  /// fall-back path keeps the UX intact when anything below us
  /// breaks (no key, 502, network).
  Future<void> regenerate() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final cards = AIAdvisor.instance.suggestions.toList();
      final payload = cards
          .map((c) => {
                'id':       c.id,
                'title':    c.title,
                'subtitle': c.subtitle,
                'priority': c.priority.name,
              })
          .toList();

      try {
        final res = await _dio.post('/briefing', data: {'cards': payload});
        final body = res.data is Map ? res.data : const {};
        final s = (body['summary'] as String?)?.trim() ?? '';
        if (s.isEmpty) {
          summary.value = _generateMock(cards);
          isMock.value  = true;
        } else {
          summary.value = s;
          isMock.value  = body['viaLlm'] != true;
        }
      } on DioException catch (_) {
        // Missing key (503), upstream OpenAI error (502), timeout —
        // all land here. The MOCK badge surfaces the degraded state.
        summary.value = _generateMock(cards);
        isMock.value  = true;
      } catch (_) {
        summary.value = _generateMock(cards);
        isMock.value  = true;
      }

      lastRunAt.value = DateTime.now();
    } finally {
      loading.value = false;
    }
  }

  /// Auto-regen gate. The strip refreshes every 10 minutes (D1);
  /// re-firing the briefing every time would burn ~144 calls/day.
  /// Manual taps on "Regenerate" bypass this check.
  bool shouldAutoRegenerate() {
    if (summary.value.isEmpty) return true;
    final last = lastRunAt.value;
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(hours: 1);
  }

  /// Deterministic narrative used when the LLM path is unavailable.
  /// Kept here (not deleted) so the strip degrades gracefully —
  /// the admin never sees an empty briefing.
  String _generateMock(List<AISuggestion> cards) {
    if (cards.isEmpty) {
      return "Nothing flagged on the floor right now. "
             "Worth using the quiet window to catch up on this month's "
             "PO reconciliations.";
    }
    final high = cards
        .where((c) => c.priority == AISuggestionPriority.high)
        .toList();
    final med = cards
        .where((c) => c.priority == AISuggestionPriority.med)
        .toList();
    final top = (high.isNotEmpty ? high : med).take(3).toList();

    final sb = StringBuffer();
    if (top.isNotEmpty) {
      sb.write('Today\'s priority is **${top.first.title.toLowerCase()}** — ');
      sb.write('${top.first.subtitle.toLowerCase()}. ');
    }
    if (top.length >= 2) {
      sb.write('After that, look at ${top[1].title.toLowerCase()}');
      if (top.length >= 3) {
        sb.write(' and ${top[2].title.toLowerCase()}.');
      } else {
        sb.write('.');
      }
    }
    if (high.isEmpty && med.isNotEmpty) {
      sb.write(' No emergencies, but the medium-priority items '
               'are worth handling before they escalate.');
    }
    if (cards.length > top.length) {
      sb.write(' ${cards.length - top.length} more lower-priority items '
               'are in the strip.');
    }
    return sb.toString();
  }
}

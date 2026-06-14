import 'package:get/get.dart';

import 'ai_advisor.dart';

/// Holds the current "morning briefing" — a 2–3 sentence narrative
/// summary of the top advisor suggestions. v1 is a mockup: it
/// generates plausible text on the client from the live suggestion
/// list, so the team can validate the UX before we wire the actual
/// `/api/v2/advisor/briefing` Claude endpoint behind it.
///
/// Swap point: replace the body of `_generate` with a Dio POST
/// once the backend route exists. The widget surface doesn't
/// change.
class BriefingController extends GetxController {
  static BriefingController get instance =>
      Get.isRegistered<BriefingController>()
          ? Get.find<BriefingController>()
          : Get.put(BriefingController(), permanent: true);

  final summary  = ''.obs;
  final loading  = false.obs;
  final isMock   = true.obs;   // flips to false once the real LLM lands
  final lastRunAt = Rxn<DateTime>();

  Future<void> regenerate() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final cards = AIAdvisor.instance.suggestions.toList();
      // Tiny mock "thinking" delay so the loading state is visible
      // — gives us a feel for how the real call will look.
      await Future.delayed(const Duration(milliseconds: 350));
      summary.value = _generate(cards);
      lastRunAt.value = DateTime.now();
    } finally {
      loading.value = false;
    }
  }

  String _generate(List<AISuggestion> cards) {
    if (cards.isEmpty) {
      return "Nothing flagged on the floor right now. "
             "Worth using the quiet window to catch up on this month's "
             "PO reconciliations.";
    }
    final high = cards.where(
        (c) => c.priority == AISuggestionPriority.high).toList();
    final med = cards.where(
        (c) => c.priority == AISuggestionPriority.med).toList();
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

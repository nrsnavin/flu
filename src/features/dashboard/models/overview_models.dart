// ══════════════════════════════════════════════════════════════
//  WHAT IS WAITING FOR A DECISION
//
//  The server's own list for the signed-in role (GET /dashboard/overview
//  — services/dashboardOverview.js): orders late or at risk, overdue
//  invoices, bills due, expenses and advances to approve, leave to
//  decide, invoices without an IRN, late supplier deliveries — each a
//  count, how urgent, and its first few lines. Only what has a count.
// ══════════════════════════════════════════════════════════════

class AttentionLine {
  const AttentionLine({required this.title, this.detail = ''});

  final String title, detail;

  factory AttentionLine.fromJson(Map<String, dynamic> j) =>
      AttentionLine(title: '${j['title'] ?? ''}', detail: '${j['detail'] ?? ''}');
}

class AttentionItem {
  const AttentionItem({
    required this.key,
    required this.label,
    required this.count,
    this.tone = 'warning',
    this.summary = '',
    this.lines = const [],
  });

  final String key, label;
  final int count;

  /// danger or warning.
  final String tone;
  final String summary;
  final List<AttentionLine> lines;

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        count: (j['count'] as num?)?.toInt() ?? 0,
        tone: '${j['tone'] ?? 'warning'}',
        summary: '${j['summary'] ?? ''}',
        lines: (j['items'] is List ? j['items'] as List : const [])
            .whereType<Map>()
            .map((e) => AttentionLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Every item of an overview, or none when the role has no overview.
  static List<AttentionItem> listFrom(Object? data) {
    if (data is! Map || data['attention'] is! List) return const [];
    return (data['attention'] as List)
        .whereType<Map>()
        .map((e) => AttentionItem.fromJson(Map<String, dynamic>.from(e)))
        .where((a) => a.count > 0 && a.key.isNotEmpty)
        .toList();
  }
}

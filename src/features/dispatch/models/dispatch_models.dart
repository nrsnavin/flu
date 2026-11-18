// ══════════════════════════════════════════════════════════════
//  THE DISPATCH QUEUE — what is packed and waiting to leave
//
//  Mirrors prod/models/DispatchItem.js and prod/api/dispatch.js (and
//  the web's features/dispatch). A job reaching packing, or a finished
//  sample, lands here and waits for marketing or admin to say when the
//  customer needs it; then it sits in deadline order until somebody
//  marks it dispatched.
//
//  No Flutter in this file: it runs on a bare Dart VM
//  (dispatch_models_check.dart).
// ══════════════════════════════════════════════════════════════

/// One of the four answers to "when does the customer need it?".
class UrgencyOption {
  final String value;
  final String label;
  final String hint;
  const UrgencyOption(this.value, this.label, this.hint);
}

/// The server's slots (prod/domain/dispatchSlots.js), in its order.
const kUrgencies = <UrgencyOption>[
  UrgencyOption('today_morning', 'Today morning', 'by 1 PM'),
  UrgencyOption('today_evening', 'Today evening', 'by 7 PM'),
  UrgencyOption('today', 'Today', 'by end of day'),
  UrgencyOption('tomorrow', 'Tomorrow', 'by end of tomorrow'),
];

DateTime? _moment(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class DispatchItem {
  final String id;
  final String kind; // job | sample
  final String? jobId;
  final String? sampleId;
  final String customerName;
  final String ref; // "J-3", "Sample #12"
  final String title;
  final double quantity; // metres, 0 when not known
  final int? orderNo;
  final String status; // awaiting_urgency | queued | dispatched | cancelled
  final DateTime? readyAt;
  final String? urgency;
  final String? urgencyLabel;
  final DateTime? dueAt;
  final String urgencySetByName;
  final DateTime? dispatchedAt;
  final String dispatchedByName;
  final String dispatchNote;
  final bool late;

  const DispatchItem({
    required this.id,
    required this.kind,
    required this.jobId,
    required this.sampleId,
    required this.customerName,
    required this.ref,
    required this.title,
    required this.quantity,
    required this.orderNo,
    required this.status,
    required this.readyAt,
    required this.urgency,
    required this.urgencyLabel,
    required this.dueAt,
    required this.urgencySetByName,
    required this.dispatchedAt,
    required this.dispatchedByName,
    required this.dispatchNote,
    required this.late,
  });

  bool get awaiting => status == 'awaiting_urgency';
  bool get queued => status == 'queued';

  factory DispatchItem.fromJson(Map<String, dynamic> j) {
    String? id(dynamic v) {
      if (v == null) return null;
      if (v is Map) return v['_id']?.toString();
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    final urgency = j['urgency']?.toString();
    return DispatchItem(
      id: (j['_id'] ?? '').toString(),
      kind: (j['kind'] ?? 'job').toString(),
      jobId: id(j['job']),
      sampleId: id(j['sample']),
      customerName: (j['customerName'] ?? '').toString(),
      ref: (j['ref'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      quantity: (j['quantity'] is num) ? (j['quantity'] as num).toDouble() : 0,
      orderNo: (j['orderNo'] is num) ? (j['orderNo'] as num).toInt() : null,
      status: (j['status'] ?? 'awaiting_urgency').toString(),
      readyAt: _moment(j['readyAt']),
      urgency: (urgency == null || urgency.isEmpty) ? null : urgency,
      urgencyLabel: j['urgencyLabel']?.toString(),
      dueAt: _moment(j['dueAt']),
      urgencySetByName: (j['urgencySetByName'] ?? '').toString(),
      dispatchedAt: _moment(j['dispatchedAt']),
      dispatchedByName: (j['dispatchedByName'] ?? '').toString(),
      dispatchNote: (j['dispatchNote'] ?? '').toString(),
      late: j['late'] == true,
    );
  }
}

class DispatchQueue {
  final List<DispatchItem> items;
  final int awaiting;
  final int queued;
  final int late;
  const DispatchQueue(this.items, this.awaiting, this.queued, this.late);

  factory DispatchQueue.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => DispatchItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final c = j['counts'];
    int n(String k, int fallback) =>
        (c is Map && c[k] is num) ? (c[k] as num).toInt() : fallback;
    return DispatchQueue(
      items,
      n('awaiting', items.where((i) => i.awaiting).length),
      n('queued', items.where((i) => i.queued).length),
      n('late', items.where((i) => i.late).length),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// When it has to leave, the way people say it: "by 1:00 PM today",
/// "by end of day tomorrow". Read from the deadline, not the slot's
/// name, so "tomorrow" chosen yesterday reads as today.
String dueText(DateTime dueAt, DateTime now) {
  final due = dueAt.toLocal();
  final here = now.toLocal();
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(here.year, here.month, here.day))
      .inHours;
  // Whole days, rounded: a day is not always 24 hours where clocks change.
  final d = (days / 24).round();
  final day = d == 0
      ? 'today'
      : d == 1
          ? 'tomorrow'
          : d == -1
              ? 'yesterday'
              : '${due.day} ${_months[due.month - 1]}';
  final endOfDay = due.hour == 23 && due.minute == 59;
  return endOfDay ? 'by end of day $day' : 'by ${clock(due)} $day';
}

/// "45m", "2h 10m", "3d 2h": late by, or waiting for.
String span(Duration d) {
  final m = d.isNegative ? 0 : (d.inSeconds / 60).round();
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  if (h < 24) return m % 60 == 0 ? '${h}h' : '${h}h ${m % 60}m';
  final days = h ~/ 24;
  return h % 24 == 0 ? '${days}d' : '${days}d ${h % 24}h';
}

/// "12 Nov 2026, 4:05 PM".
String stamp(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}, ${clock(l)}';
}

/// Metres with Indian digit grouping: 125000 → "1,25,000".
String metres(double q) {
  final whole = q.round().abs().toString();
  if (whole.length <= 3) return '${q < 0 ? '-' : ''}$whole m';
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${q < 0 ? '-' : ''}${parts.join(',')},$last3 m';
}

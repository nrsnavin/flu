// ══════════════════════════════════════════════════════════════
//  A CUSTOMER COMPLAINT, AND WHO ELSE GOT THE SAME CLOTH
//
//  Mirrors models/Complaints.js and api/complaint.js.
//
//  The trace is the reason this module exists. A complaint about one
//  delivery is a customer-service problem; the same complaint traced
//  back to a yarn lot, and forward to every OTHER job that used it, is
//  a recall. The server does that walk — this carries the answer.
// ══════════════════════════════════════════════════════════════

const complaintCategories = [
  'shade', 'strength', 'width', 'finish',
  'quantity', 'packing', 'delivery', 'other',
];

const complaintStatuses = ['Open', 'InReview', 'Resolved', 'Rejected', 'Closed'];

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// A populated ref may arrive as a map, a bare id string, or null when
/// the referenced document has been removed — populate() resolves a
/// dangling ref to null rather than failing, so every read here has to
/// survive it.
String _refName(dynamic v, {String fallback = '—'}) {
  if (v == null) return fallback;
  if (v is Map) return v['name']?.toString() ?? fallback;
  return fallback;
}

String? _refId(dynamic v) {
  if (v == null) return null;
  if (v is Map) return v['_id']?.toString();
  return v.toString();
}

class Complaint {
  final String id;
  final DateTime? date;
  final String customerName;
  final String? customerId;
  final String elasticName;
  final String? jobOrderNo;
  final String? orderNo;
  final String category;
  final String status;
  final String reason;
  final String feedback;
  final String resolution;
  final double quantity;

  const Complaint({
    required this.id,
    required this.date,
    required this.customerName,
    required this.customerId,
    required this.elasticName,
    required this.jobOrderNo,
    required this.orderNo,
    required this.category,
    required this.status,
    required this.reason,
    required this.feedback,
    required this.resolution,
    required this.quantity,
  });

  bool get isOpen => status == 'Open' || status == 'InReview';

  factory Complaint.fromJson(Map<String, dynamic> j) {
    final job = j['job'];
    String? jobNo;
    String? orderNo;
    if (job is Map) {
      jobNo = job['jobOrderNo']?.toString();
      final order = job['order'];
      if (order is Map) orderNo = order['orderNo']?.toString();
    }
    return Complaint(
      id: j['_id']?.toString() ?? '',
      date: DateTime.tryParse(j['date']?.toString() ?? ''),
      customerName: _refName(j['customer'], fallback: 'Unknown customer'),
      customerId: _refId(j['customer']),
      elasticName: _refName(j['elastic']),
      jobOrderNo: jobNo,
      orderNo: orderNo,
      category: j['category']?.toString() ?? 'other',
      status: j['status']?.toString() ?? 'Open',
      reason: j['reason']?.toString() ?? '',
      feedback: j['feedback']?.toString() ?? '',
      resolution: j['resolution']?.toString() ?? '',
      quantity: _num(j['quantity']),
    );
  }
}

class ComplaintPage {
  final List<Complaint> items;
  final int total;
  final int page;

  const ComplaintPage({
    required this.items,
    required this.total,
    required this.page,
  });

  factory ComplaintPage.fromJson(Map<String, dynamic> j) => ComplaintPage(
        items: (j['data'] as List? ?? const [])
            .map((e) => Complaint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
      );
}

/// Everything else that shares a yarn lot with the complained-about
/// job. The blast radius.
///
/// As services/complaintTrace.js sends it:
///   { ok, message?, lots, exposure: { inHouse, inTransit, delivered },
///     summary, caveats }
///
/// This used to read `exposedJobs` (or `jobs`) and `note` — names the
/// server has never sent. So the phone listed the lots and never one of
/// the other jobs carrying them; and when no lot was recorded at all it
/// said "No other jobs share a yarn lot with this one", where the
/// server's own answer is that this "is not evidence that no other
/// order is affected". On this screen a wrong "nobody else" is the one
/// mistake that matters.
class ComplaintTrace {
  /// False when there is no trail to follow at all (no job on the
  /// complaint); [message] says why.
  final bool ok;
  final String? message;

  /// Free-form rows the server builds by walking lot → batch → job.
  /// Kept loose on purpose: the fields of a row are the server's to
  /// add to, and a strict model here would break the screen each time.
  final List<Map<String, dynamic>> lots;

  /// The other jobs carrying those lots, by where the goods are.
  final List<Map<String, dynamic>> inHouse;
  final List<Map<String, dynamic>> inTransit;
  final List<Map<String, dynamic>> delivered;

  /// What the server says should be kept in mind when reading the rest.
  final List<String> caveats;

  const ComplaintTrace({
    required this.ok,
    required this.message,
    required this.lots,
    required this.inHouse,
    required this.inTransit,
    required this.delivered,
    required this.caveats,
  });

  int get otherJobs => inHouse.length + inTransit.length + delivered.length;

  /// Nothing could be traced — no trail, or no lot recorded against the
  /// job. NOT the same as nobody else being affected, and never shown
  /// as if it were.
  bool get nothingToTrace => !ok || lots.isEmpty;

  /// Lots were traced, and no other job carries them: the one case in
  /// which "nobody else" is a true thing to say.
  bool get nobodyElse => ok && lots.isNotEmpty && otherJobs == 0;

  /// "Job 771 · Order 871 · weaving · 20mm Black"
  static String jobLine(Map<String, dynamic> row) {
    final elastics = (row['elastics'] as List? ?? const [])
        .map((e) => e is Map ? (e['name']?.toString() ?? '') : '')
        .where((n) => n.isNotEmpty)
        .join(', ');
    return [
      row['jobNo'] != null ? 'Job ${row['jobNo']}' : 'Job',
      if (row['orderNo'] != null) 'Order ${row['orderNo']}',
      if ((row['jobStatus'] ?? '').toString().isNotEmpty) row['jobStatus'].toString(),
      if (elastics.isNotEmpty) elastics,
    ].join(' · ');
  }

  /// "Nylon 70D · Off White · issued" — the lot's number is the title.
  static String lotLine(Map<String, dynamic> lot) => [
        for (final k in const ['materialName', 'shade', 'source'])
          if ((lot[k] ?? '').toString().isNotEmpty) lot[k].toString(),
      ].join(' · ');

  factory ComplaintTrace.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> rows(dynamic v) => (v as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final exposure = j['exposure'] is Map
        ? Map<String, dynamic>.from(j['exposure'] as Map)
        : const <String, dynamic>{};
    return ComplaintTrace(
      // Only an explicit false is "no trail": a server that sends no
      // `ok` at all is read as it always was.
      ok: j['ok'] != false,
      message: j['message']?.toString(),
      lots: rows(j['lots']),
      inHouse: rows(exposure['inHouse']),
      inTransit: rows(exposure['inTransit']),
      delivered: rows(exposure['delivered']),
      caveats: (j['caveats'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

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
class ComplaintTrace {
  /// Free-form rows the server builds by walking lot → batch → job.
  /// Kept loose on purpose: the shape of the walk is the server's to
  /// change, and a strict model here would break the screen every time
  /// a field was added to it.
  final List<Map<String, dynamic>> lots;
  final List<Map<String, dynamic>> exposedJobs;
  final String? note;

  const ComplaintTrace({
    required this.lots,
    required this.exposedJobs,
    required this.note,
  });

  bool get isEmpty => lots.isEmpty && exposedJobs.isEmpty;

  factory ComplaintTrace.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> rows(dynamic v) => (v as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return ComplaintTrace(
      lots: rows(j['lots']),
      exposedJobs: rows(j['exposedJobs'] ?? j['jobs']),
      note: j['note']?.toString(),
    );
  }
}

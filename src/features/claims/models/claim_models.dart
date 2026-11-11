// ══════════════════════════════════════════════════════════════
//  EXPENSE CLAIMS — what the server sends (api/claims.js)
//
//  A claim is an Expense with a claimant: money someone spent for the
//  factory, waiting for Accounts to approve it and pay it back.
// ══════════════════════════════════════════════════════════════

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
String _s(Object? v) => v?.toString() ?? '';
DateTime? _date(Object? v) =>
    v == null || '$v'.isEmpty ? null : DateTime.tryParse('$v')?.toLocal();
Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

class ClaimCategory {
  const ClaimCategory({required this.id, required this.name, this.dailyLimit = 0});

  final String id, name;

  /// What one person may claim under it in a day; 0 for no cap.
  final double dailyLimit;

  factory ClaimCategory.fromJson(Map<String, dynamic> j) => ClaimCategory(
        id: _s(j['_id']),
        name: _s(j['name']),
        dailyLimit: _d(j['claimDailyLimit']),
      );
}

class Claim {
  const Claim({
    required this.id,
    this.expenseNo = '',
    this.date,
    this.categoryName = '',
    this.description = '',
    this.amount = 0,
    this.status = 'pending',
    this.decidedBy = '',
    this.decisionNote = '',
    this.paidAmount = 0,
    this.paidAt,
    this.attachments = 0,
  });

  final String id, expenseNo;
  final DateTime? date;
  final String categoryName, description;
  final double amount;

  /// pending, approved, rejected, paid or cancelled (withdrawn).
  final String status;
  final String decidedBy, decisionNote;
  final double paidAmount;
  final DateTime? paidAt;
  final int attachments;

  bool get isPending => status == 'pending';

  /// The status as the claimant reads it (the web's labels).
  String get statusLabel => switch (status) {
        'pending' => 'Waiting for approval',
        'approved' => 'Approved, to be paid',
        'rejected' => 'Rejected',
        'paid' => 'Paid back',
        'cancelled' => 'Withdrawn',
        _ => status,
      };

  factory Claim.fromJson(Map<String, dynamic> j) {
    final approval = _m(j['approval']);
    return Claim(
      id: _s(j['_id']),
      expenseNo: _s(j['expenseNo']),
      date: _date(j['date']),
      categoryName: _s(j['categoryName']),
      description: _s(j['description']),
      amount: _d(_m(j['totals'])['grand']),
      status: _s(j['status']).isEmpty ? 'pending' : _s(j['status']),
      decidedBy: _s(approval['byName']),
      decisionNote: _s(approval['note']),
      paidAmount: _d(j['paidAmount']),
      paidAt: _date(j['paidAt']),
      attachments: j['attachments'] is List ? (j['attachments'] as List).length : 0,
    );
  }
}

/// My claims, and what is waiting and owed on them (GET /claims).
class MyClaims {
  const MyClaims({this.claims = const [], this.waiting = 0, this.owed = 0});

  final List<Claim> claims;

  /// Waiting for approval.
  final double waiting;

  /// Approved and still to be paid back.
  final double owed;

  factory MyClaims.fromJson(Map<String, dynamic> j) => MyClaims(
        claims: (j['claims'] is List ? j['claims'] as List : const [])
            .whereType<Map>()
            .map((e) => Claim.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        waiting: _d(j['waiting']),
        owed: _d(j['owed']),
      );
}

/// What the receipt said, once read (POST /claims/scan). Nothing is
/// saved by reading: the form is filled from it and the claimant checks.
class ClaimScan {
  const ClaimScan({
    this.problem,
    this.amount,
    this.date = '',
    this.description = '',
    this.refNo = '',
    this.categoryId,
    this.categoryName = '',
    this.categoryReason = '',
    this.alreadyClaimed,
    this.aiSuggestion,
  });

  /// not_a_bill or unreadable; null when it was read.
  final String? problem;
  final double? amount;

  /// YYYY-MM-DD, as printed on the receipt.
  final String date;
  final String description, refNo;
  final String? categoryId;
  final String categoryName, categoryReason;

  /// The claim this receipt already went on, by its number or its
  /// amount that day.
  final String? alreadyClaimed;

  /// Sent back with the claim, so what the person corrected scores the read.
  final String? aiSuggestion;

  bool get read => problem == null;

  factory ClaimScan.fromJson(Map<String, dynamic> j) {
    final d = _m(j['draft']);
    final amount = d['amount'] == null ? null : _d(d['amount']);
    return ClaimScan(
      problem: j['problem'] == null && j['draft'] != null ? null : (_s(j['problem']).isEmpty ? 'unreadable' : _s(j['problem'])),
      amount: amount != null && amount > 0 ? amount : null,
      date: _s(d['date']),
      description: _s(d['description']),
      refNo: _s(d['refNo']),
      categoryId: d['category'] == null ? null : _s(d['category']),
      categoryName: _s(j['categoryName']),
      categoryReason: _s(j['categoryReason']),
      alreadyClaimed: j['alreadyClaimed'] == null ? null : _s(j['alreadyClaimed']),
      aiSuggestion: j['aiSuggestion'] == null ? null : _s(j['aiSuggestion']),
    );
  }
}

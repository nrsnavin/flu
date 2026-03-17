// ══════════════════════════════════════════════════════════════
//  PACKING MODELS — unified single file
// ══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  PackingJobModel  (Add Packing job dropdown)
//
//  FIX: ElasticItem.fromJson accessed json["elastic"]["_id"]
//       without null guard → crash on any unpopulated elastic.
// ─────────────────────────────────────────────────────────────

class PackingJobModel {
  final String id;
  final int jobNo;
  final String customerName;
  final List<ElasticItem> elastics;

  const PackingJobModel({
    required this.id,
    required this.jobNo,
    required this.customerName,
    required this.elastics,
  });

  factory PackingJobModel.fromJson(Map<String, dynamic> json) {
    final rawElastics = json['elastics'] as List? ?? [];
    return PackingJobModel(
      id:           json['_id']?.toString() ?? '',
      jobNo:        (json['jobOrderNo'] as num?)?.toInt() ?? 0,
      customerName: (json['customer'] is Map)
          ? (json['customer']['name']?.toString() ?? '—')
          : '—',
      elastics: rawElastics
          .where((e) => e['elastic'] != null)
          .map((e) => ElasticItem.fromJson(e))
          .toList(),
    );
  }
}

class ElasticItem {
  final String elasticId;
  final String name;

  const ElasticItem({required this.elasticId, required this.name});

  factory ElasticItem.fromJson(Map<String, dynamic> json) {
    final elastic = json['elastic'];
    if (elastic is Map) {
      return ElasticItem(
        elasticId: elastic['_id']?.toString() ?? '',
        name:      elastic['name']?.toString() ?? '—',
      );
    }
    return ElasticItem(elasticId: elastic?.toString() ?? '', name: '—');
  }
}

// ─────────────────────────────────────────────────────────────
//  PackingJobSummary  (job card in grouped/overview list)
//
//  NOTE: renamed from PackingOverviewItem → PackingJobSummary
//  to match usage in packing_controller.dart and
//  packing_overview_page.dart.
//  customerName is nullable because the aggregate pipeline may
//  not always populate customer info.
// ─────────────────────────────────────────────────────────────

class PackingJobSummary {
  final String  jobId;
  final int     jobNo;
  final String? customerName;
  final int     totalBoxes;
  final double  totalMeters;

  const PackingJobSummary({
    required this.jobId,
    required this.jobNo,
    this.customerName,
    required this.totalBoxes,
    required this.totalMeters,
  });

  factory PackingJobSummary.fromJson(Map<String, dynamic> json) {
    final job = json['job'];
    return PackingJobSummary(
      jobId:        (job is Map ? job['_id'] : json['jobId'])?.toString()       ?? '',
      jobNo:        ((job is Map ? job['jobOrderNo'] : json['jobOrderNo']) as num?)
          ?.toInt() ?? 0,
      customerName: (job is Map && job['customer'] is Map)
          ? job['customer']['name']?.toString()
          : null,
      totalBoxes:  (json['totalBoxes']  as num?)?.toInt()    ?? 0,
      totalMeters: (json['totalMeters'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PackingListItem  (row in list-by-job)
// ─────────────────────────────────────────────────────────────

class PackingListItem {
  final String id;
  final String elasticName;
  final double meters;
  final int joints;
  final String date;

  const PackingListItem({
    required this.id,
    required this.elasticName,
    required this.meters,
    required this.joints,
    required this.date,
  });

  factory PackingListItem.fromJson(Map<String, dynamic> json) {
    final elastic = json['elastic'];
    final elasticName = elastic is Map
        ? (elastic['name']?.toString() ?? '—')
        : (elastic?.toString() ?? '—');
    String date = '';
    try {
      final raw = json['date'] ?? json['createdAt'];
      if (raw != null) date = raw.toString().substring(0, 10);
    } catch (_) {}

    return PackingListItem(
      id:          json['_id']?.toString()           ?? '',
      elasticName: elasticName,
      meters:      (json['meter'] as num?)?.toDouble() ?? 0.0,
      joints:      (json['joints'] as num?)?.toInt()   ?? 0,
      date:        date,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PackingDetail  (full detail view)
//
//  BUGS FIXED:
//  1. stretch: int.parse(json["stretch"]) crashes before ?? fires
//     when stretch is null or non-numeric. → double.tryParse.
//  2. elasticName: populated endpoint returns object, not String.
//  3. jobOrderNo: not on Packing schema, lives on populated job.
//  4. checkedBy/packedBy: populated as {_id, name} objects.
// ─────────────────────────────────────────────────────────────

class PackingDetail {
  final String id;
  final String jobOrderNo;
  final String elasticId;
  final String elasticName;
  final String elasticWeaveType;
  final String customerName;
  final String po;
  final int joints;
  final double meters;
  final String stretch;  // stored as String in DB, e.g. "2.5"
  final double netWeight;
  final double tareWeight;
  final double grossWeight;
  final String checkedBy;
  final String packedBy;
  final String size;
  final String date;

  const PackingDetail({
    required this.id,
    required this.jobOrderNo,
    required this.elasticId,
    required this.elasticName,
    required this.elasticWeaveType,
    required this.customerName,
    required this.po,
    required this.joints,
    required this.meters,
    required this.stretch,   // String, e.g. "2.5"
    required this.netWeight,
    required this.tareWeight,
    required this.grossWeight,
    required this.checkedBy,
    required this.packedBy,
    required this.size,
    required this.date,
  });

  factory PackingDetail.fromJson(Map<String, dynamic> json) {
    final elastic = json['elastic'];
    final elasticId    = elastic is Map ? (elastic['_id']?.toString()       ?? '') : '';
    final elasticName  = elastic is Map ? (elastic['name']?.toString()      ?? '—') : '—';
    final elasticWeave = elastic is Map ? (elastic['weaveType']?.toString() ?? '—') : '—';

    final job = json['job'];
    final jobNo = job is Map ? (job['jobOrderNo']?.toString() ?? '—') : '—';

    String customerName = '—', po = '—';
    if (job is Map && job['order'] is Map) {
      customerName = (job['order']['customer'] is Map)
          ? (job['order']['customer']['name']?.toString() ?? '—')
          : '—';
      po = job['order']['po']?.toString() ?? '—';
    }

    String _name(dynamic v) =>
        v is Map ? (v['name']?.toString() ?? '—') : (v?.toString() ?? '—');

    // stretch is stored as String in schema (e.g. "2.5", "3"), keep as-is
    final stretch = json['stretch']?.toString() ?? '0';

    String date = '';
    try {
      final d = json['date'] ?? json['createdAt'];
      if (d != null) date = d.toString().substring(0, 10);
    } catch (_) {}

    return PackingDetail(
      id:               json['_id']?.toString()                    ?? '',
      jobOrderNo:       jobNo,
      elasticId:        elasticId,
      elasticName:      elasticName,
      elasticWeaveType: elasticWeave,
      customerName:     customerName,
      po:               po,
      joints:           (json['joints']      as num?)?.toInt()    ?? 0,
      meters:           (json['meter']       as num?)?.toDouble() ?? 0.0,
      stretch:          stretch,
      netWeight:        (json['netWeight']   as num?)?.toDouble() ?? 0.0,
      tareWeight:       (json['tareWeight']  as num?)?.toDouble() ?? 0.0,
      grossWeight:      (json['grossWeight'] as num?)?.toDouble() ?? 0.0,
      checkedBy:        _name(json['checkedBy']),
      packedBy:         _name(json['packedBy']),
      size:             json['size']?.toString()                  ?? '—',
      date:             date,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EmployeeOption  (Add Packing employee dropdowns)
// ─────────────────────────────────────────────────────────────

class EmployeeOption {
  final String id;
  final String name;

  const EmployeeOption({required this.id, required this.name});

  factory EmployeeOption.fromJson(Map<String, dynamic> json) {
    return EmployeeOption(
      id:   json['_id']?.toString()  ?? '',
      name: json['name']?.toString() ?? '—',
    );
  }
}
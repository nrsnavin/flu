// ══════════════════════════════════════════════════════════════
//  MACHINE SERVICE / SPARE BILL
//
//  Mirrors models/MachineServiceBill.js. The bytes are never in a list
//  response — every listing endpoint strips them with `.select("-data")`
//  — so this model carries metadata only and the file is fetched on
//  demand from /machine/service-bill/:id/file.
//
//  Bills live in their own collection rather than on the service log,
//  because service logs are embedded in the Machine document and inline
//  file bytes would march a regularly-serviced machine straight into
//  MongoDB's 16 MB per-document limit.
// ══════════════════════════════════════════════════════════════

const kBillKinds = ['service_bill', 'spare_bill'];

String billKindLabel(String kind) =>
    kind == 'spare_bill' ? 'Spare part' : 'Service';

/// What the server will take. An unlabelled upload is resolved by its
/// extension server-side, so the filename has to keep one.
const kBillContentTypes = [
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
];

const kBillMaxBytes = 5 * 1024 * 1024;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class ServiceBill {
  final String id;
  final String machineId;
  final String serviceLogId;

  /// service_bill · spare_bill
  final String kind;

  final String filename;
  final String contentType;

  /// Bytes of the original file, before base64 inflation.
  final int size;

  final double amount;
  final String vendor;
  final String billNo;
  final DateTime? billDate;

  /// Spare bills describe the part fitted.
  final String partName;
  final String notes;
  final DateTime? createdAt;

  const ServiceBill({
    required this.id,
    required this.machineId,
    required this.serviceLogId,
    required this.kind,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.amount,
    required this.vendor,
    required this.billNo,
    required this.partName,
    required this.notes,
    this.billDate,
    this.createdAt,
  });

  factory ServiceBill.fromJson(Map<String, dynamic> j) => ServiceBill(
        id:           _s(j['_id']),
        machineId:    _s(j['machine']),
        serviceLogId: _s(j['serviceLog']),
        kind:         _s(j['kind']).isEmpty ? 'service_bill' : _s(j['kind']),
        filename:     _s(j['filename']),
        contentType:  _s(j['contentType']),
        size:         (j['size'] as num?)?.toInt() ?? 0,
        amount:       _d(j['amount']),
        vendor:       _s(j['vendor']),
        billNo:       _s(j['billNo']),
        partName:     _s(j['partName']),
        notes:        _s(j['notes']),
        billDate:     _date(j['billDate']),
        createdAt:    _date(j['createdAt']),
      );

  bool get isSpare => kind == 'spare_bill';
  bool get isPdf => contentType == 'application/pdf';

  /// Something to call it in a list. A vendor's bill number is the most
  /// useful handle; the filename is the fallback, and neither being set
  /// is normal for a photo snapped on the floor.
  String get label {
    if (billNo.isNotEmpty) return billNo;
    if (partName.isNotEmpty) return partName;
    if (filename.isNotEmpty) return filename;
    return isSpare ? 'Spare bill' : 'Service bill';
  }

  /// The extension the server needs to resolve an unlabelled upload.
  String get extension {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  }

  String get sizeLabel {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) return '${(size / 1024).round()} KB';
    return '$size B';
  }
}

/// One list response: the bills, and the totals the server already
/// computed so the phone and the web cannot disagree about them.
class ServiceBillList {
  final List<ServiceBill> bills;
  final int count;
  final double totalAmount;

  const ServiceBillList({
    required this.bills,
    required this.count,
    required this.totalAmount,
  });

  static const empty = ServiceBillList(bills: [], count: 0, totalAmount: 0);

  factory ServiceBillList.fromJson(Map<String, dynamic> j) {
    final bills = (j['bills'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ServiceBill.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ServiceBillList(
      bills: bills,
      count: (j['count'] as num?)?.toInt() ?? bills.length,
      totalAmount: _d(j['totalAmount']),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  YARN LOT
//
//  A dyed lot of a raw material, tracked as its own bucket so a
//  warping batch can be tied to the exact yarn it was warped from.
//
//  Mirrors models/YarnLot.js. The one thing worth carrying over from
//  its comments: lot balances and RawMaterial.stock are separate
//  counters and are NOT expected to agree. Stock is debited when the
//  yarn is committed; a lot is drawn down when it is physically taken.
//  The sum of lot balances is a floor on the yarn present, never the
//  whole of it — yarn that came in before lot tracking has no lot.
// ══════════════════════════════════════════════════════════════

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

class YarnLot {
  final String id;
  final String lotNo;
  final String shade;
  final String dyer;
  final String materialName;
  final String supplierName;

  /// Accumulates across every inward carrying this lot number.
  final double receivedQty;
  final double consumedQty;

  /// open · exhausted · quarantined · closed
  final String status;
  final DateTime? receivedDate;
  final String remarks;

  const YarnLot({
    required this.id,
    required this.lotNo,
    required this.shade,
    required this.dyer,
    required this.materialName,
    required this.supplierName,
    required this.receivedQty,
    required this.consumedQty,
    required this.status,
    required this.remarks,
    this.receivedDate,
  });

  factory YarnLot.fromJson(Map<String, dynamic> j) {
    final material = j['rawMaterial'];
    final supplier = j['supplier'];
    return YarnLot(
      id: _s(j['_id']),
      lotNo: _s(j['lotNo']),
      shade: _s(j['shade']),
      dyer: _s(j['dyer']),
      materialName: material is Map ? _s(material['name']) : '',
      supplierName: supplier is Map ? _s(supplier['name']) : '',
      receivedQty: _d(j['receivedQty']),
      consumedQty: _d(j['consumedQty']),
      status: _s(j['status']).isEmpty ? 'open' : _s(j['status']),
      remarks: _s(j['remarks']),
      receivedDate: j['receivedDate'] == null
          ? null
          : DateTime.tryParse(j['receivedDate'].toString())?.toLocal(),
    );
  }

  /// What is left to draw. A virtual on the server, recomputed here so
  /// the figure cannot drift between the two.
  double get balance {
    final v = receivedQty - consumedQty;
    return v > 0 ? v : 0;
  }

  bool get isIssuable => status == 'open' && balance > 0;

  String get label => shade.isEmpty ? lotNo : '$lotNo · $shade';
}

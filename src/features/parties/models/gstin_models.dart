// ══════════════════════════════════════════════════════════════
//  A GSTIN, AND WHAT THE GST SYSTEM SAYS OF IT
//
//  "Verify" beside the GSTIN on the customer and supplier forms. The
//  server checks the number itself (pattern, check character) and then
//  asks the GST system, through whoever is connected in Settings →
//  Invoice on the web, who it is registered to, where, and whether it
//  is still active:
//
//    POST /customer/gstin/:gstin/verify     POST /supplier/gstin/:gstin/verify
//    GET  /customer/gstin/:gstin/check      GET  /supplier/gstin/:gstin/check
//
//  This file is what comes back, and the one rule about filling a form
//  from it (planFill): an empty field is filled; what somebody typed is
//  kept and listed; what Verify itself put there earlier is Verify's to
//  replace. No Flutter here, so it runs on a bare Dart VM — see
//  gstin_models_check.dart.
// ══════════════════════════════════════════════════════════════

const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
final _pattern = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

/// The GSTIN as it is kept: no spaces, capitals.
String normalGstin(String? raw) => (raw ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// The check character over the first fourteen (the published mod-36 scheme).
String gstinCheckChar(String first14) {
  var sum = 0;
  for (var i = 0; i < 14; i++) {
    final p = _chars.indexOf(first14[i]) * (i.isEven ? 1 : 2);
    sum += p ~/ 36 + p % 36;
  }
  return _chars[(36 - sum % 36) % 36];
}

/// What the number itself says, with no call to anyone.
class GstinInfo {
  final bool valid;
  final String stateCode;
  final String pan;
  final bool checksumOk;
  const GstinInfo({this.valid = false, this.stateCode = '', this.pan = '', this.checksumOk = false});
}

GstinInfo gstinInfo(String? raw) {
  final g = normalGstin(raw);
  if (!_pattern.hasMatch(g)) return const GstinInfo();
  return GstinInfo(
    valid: true,
    stateCode: g.substring(0, 2),
    pan: g.substring(2, 12),
    checksumOk: gstinCheckChar(g.substring(0, 14)) == g[14],
  );
}

String cleanText(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
bool sameText(String? a, String? b) => cleanText(a).toLowerCase() == cleanText(b).toLowerCase();

String _s(dynamic v) => v == null ? '' : v.toString();

/// What a customer or supplier form can take from the registration.
class GstinFill {
  /// What the business is known by: its trade name, else its legal name.
  final String name;
  final String legalName;
  final String tradeName;
  final String address;
  final String city;
  final String pincode;
  final String stateCode;

  /// The whole address on one line, for a form with one address field.
  final String fullAddress;
  final String pan;

  /// "regular" or "composition".
  final String gstRegistration;
  final bool sez;

  const GstinFill({
    this.name = '',
    this.legalName = '',
    this.tradeName = '',
    this.address = '',
    this.city = '',
    this.pincode = '',
    this.stateCode = '',
    this.fullAddress = '',
    this.pan = '',
    this.gstRegistration = 'regular',
    this.sez = false,
  });

  factory GstinFill.fromJson(Map<String, dynamic> j) => GstinFill(
        name: _s(j['name']),
        legalName: _s(j['legalName']),
        tradeName: _s(j['tradeName']),
        address: _s(j['address']),
        city: _s(j['city']),
        pincode: _s(j['pincode']),
        stateCode: _s(j['stateCode']),
        fullAddress: _s(j['fullAddress']),
        pan: _s(j['pan']),
        gstRegistration: j['gstRegistration'] == 'composition' ? 'composition' : 'regular',
        sez: j['sez'] == true,
      );

  /// The part a form field takes, by name.
  Map<String, String> get parts => {
        'name': name,
        'address': address,
        'fullAddress': fullAddress,
        'city': city,
        'pincode': pincode,
        'stateCode': stateCode,
        'pan': pan,
      };
}

/// The GST system's half of an answer.
class GstinPortal {
  /// false: the GST system was not asked — [reason] says why.
  final bool checked;

  /// "checksum" (a typo) or "not_connected".
  final String reason;
  final bool found;
  final bool fromCache;
  final DateTime? checkedAt;
  final String checkedByName;
  final String via;
  final String said;

  /// active, cancelled, suspended, inactive, provisional, unknown.
  final String status;
  final String statusText;
  final String legalName;
  final String tradeName;
  final String taxpayerType;
  final String registeredOn;
  final String cancelledOn;

  /// Blocked from e-invoicing; null when the provider does not say.
  final bool? einvoiceBlocked;

  const GstinPortal({
    this.checked = false,
    this.reason = '',
    this.found = false,
    this.fromCache = false,
    this.checkedAt,
    this.checkedByName = '',
    this.via = '',
    this.said = '',
    this.status = 'unknown',
    this.statusText = '',
    this.legalName = '',
    this.tradeName = '',
    this.taxpayerType = '',
    this.registeredOn = '',
    this.cancelledOn = '',
    this.einvoiceBlocked,
  });

  factory GstinPortal.fromJson(Map<String, dynamic> j) => GstinPortal(
        checked: j['checked'] == true,
        reason: _s(j['reason']),
        found: j['found'] == true,
        fromCache: j['fromCache'] == true,
        checkedAt: DateTime.tryParse(_s(j['checkedAt'])),
        checkedByName: _s(j['checkedByName']),
        via: _s(j['via']),
        said: _s(j['said']),
        status: _s(j['status']).isEmpty ? 'unknown' : _s(j['status']),
        statusText: _s(j['statusText']),
        legalName: _s(j['legalName']),
        tradeName: _s(j['tradeName']),
        taxpayerType: _s(j['taxpayerType']),
        registeredOn: _s(j['registeredOn']),
        cancelledOn: _s(j['cancelledOn']),
        einvoiceBlocked: j['einvoiceBlocked'] is bool ? j['einvoiceBlocked'] as bool : null,
      );

  /// A registration a form may be filled from without being asked.
  bool get live => found && const ['active', 'provisional', 'unknown'].contains(status);

  /// "SUNRISE GARMENTS PRIVATE LIMITED · trade name Sunrise Garments".
  String get names {
    final out = <String>[
      if (legalName.isNotEmpty) legalName,
      if (tradeName.isNotEmpty && !sameText(tradeName, legalName)) 'trade name $tradeName',
    ];
    return out.isEmpty ? 'Name not given' : out.join(' · ');
  }

  /// "Regular · registered 1 Jul 2017 · cancelled 12 Mar 2024".
  String get about => [
        if (taxpayerType.isNotEmpty) taxpayerType,
        if (registeredOn.isNotEmpty) 'registered ${dayText(registeredOn)}',
        if (cancelledOn.isNotEmpty) 'cancelled ${dayText(cancelledOn)}',
      ].join(' · ');

  /// "Checked 18 Nov 2026, 3:42 pm through ClearTax by Owner".
  String checkedLine({bool earlier = false}) {
    final at = checkedAt == null ? '' : whenText(checkedAt!.toLocal());
    final said = [
      at,
      if (via.isNotEmpty) 'through $via',
      if (checkedByName.isNotEmpty) 'by $checkedByName',
    ].where((x) => x.isNotEmpty).join(' ');
    return '${earlier ? 'Last check:' : 'Checked'} $said'.trim();
  }
}

/// One answer from POST …/gstin/:gstin/verify (or the kept one from …/check).
class GstinAnswer {
  final String gstin;
  final bool valid;
  final bool checksumOk;
  final String stateCode;
  final String stateName;
  final String pan;
  final GstinPortal portal;
  final GstinFill? fill;
  final String message;

  const GstinAnswer({
    required this.gstin,
    this.valid = false,
    this.checksumOk = false,
    this.stateCode = '',
    this.stateName = '',
    this.pan = '',
    this.portal = const GstinPortal(),
    this.fill,
    this.message = '',
  });

  factory GstinAnswer.fromJson(Map<String, dynamic> j) => GstinAnswer(
        gstin: normalGstin(_s(j['gstin'])),
        valid: j['valid'] == true,
        checksumOk: j['checksumOk'] == true,
        stateCode: _s(j['stateCode']),
        stateName: _s(j['stateName']),
        pan: _s(j['pan']),
        portal: j['portal'] is Map ? GstinPortal.fromJson(Map<String, dynamic>.from(j['portal'] as Map)) : const GstinPortal(),
        fill: j['fill'] is Map ? GstinFill.fromJson(Map<String, dynamic>.from(j['fill'] as Map)) : null,
        message: _s(j['message']),
      );

  /// What the number itself gives when nobody was asked: two of the fields.
  Map<String, String> get fromTheNumber => {'stateCode': stateCode, 'pan': pan};
}

// ── Filling a form ─────────────────────────────────────────────

/// One form field and the part of the registration that goes in it.
class FillTarget {
  /// The field's own name in its form ("name", "address"…).
  final String field;

  /// What the form calls it ("Customer name").
  final String label;

  /// name, address, fullAddress, city, pincode, stateCode or pan.
  final String part;
  const FillTarget(this.field, this.label, this.part);
}

/// What Verify put in a field, and for which GSTIN.
class Wrote {
  final String value;
  final String gstin;
  const Wrote(this.value, this.gstin);
}

/// A field left as typed, and what the registration has for it.
class KeptField {
  final String field;
  final String label;
  final String current;
  final String value;
  const KeptField(this.field, this.label, this.current, this.value);
}

class FillPlan {
  /// field → the value to put in it.
  final Map<String, String> writes;

  /// The labels of the fields that are written, in the form's order.
  final List<String> filled;
  final List<KeptField> kept;

  /// Fields that already hold the value and stood from another number's check.
  final List<String> adopted;
  const FillPlan({required this.writes, required this.filled, required this.kept, this.adopted = const []});
}

/// Decide what goes in the form.
///
///  • an empty field takes the registration's value;
///  • a field that still stands as Verify wrote it (for any number) takes
///    the new value — nobody typed it;
///  • anything else was typed by a person: kept, and listed.
FillPlan planFill({
  required List<FillTarget> targets,
  required Map<String, String> parts,
  required Map<String, String> current,
  required Map<String, Wrote> wrote,
}) {
  final writes = <String, String>{};
  final filled = <String>[];
  final kept = <KeptField>[];
  final adopted = <String>[];
  for (final t in targets) {
    final value = cleanText(parts[t.part]);
    if (value.isEmpty) continue;
    final now = cleanText(current[t.field]);
    final mine = wrote[t.field];
    final ours = mine != null && sameText(now, mine.value);
    if (sameText(now, value)) {
      if (ours) adopted.add(t.field);
    } else if (now.isEmpty || ours) {
      writes[t.field] = value;
      filled.add(t.label);
    } else {
      kept.add(KeptField(t.field, t.label, now, value));
    }
  }
  return FillPlan(writes: writes, filled: filled, kept: kept, adopted: adopted);
}

/// Fields still holding what a check of ANOTHER number filled in.
List<FillTarget> staleTargets({
  required List<FillTarget> targets,
  required Map<String, String> current,
  required Map<String, Wrote> wrote,
  required String gstin,
}) =>
    targets.where((t) {
      final mine = wrote[t.field];
      return mine != null && mine.gstin != gstin && sameText(current[t.field], mine.value);
    }).toList();

// ── Dates, as the rest of the app writes them ──────────────────

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2017-07-01" → "1 Jul 2017"; anything else comes back as it was.
String dayText(String ymd) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(ymd);
  if (m == null) return ymd;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return ymd;
  return '${int.parse(m.group(3)!)} ${_months[month - 1]} ${m.group(1)}';
}

/// "18 Nov 2026, 3:42 pm" of a local time.
String whenText(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

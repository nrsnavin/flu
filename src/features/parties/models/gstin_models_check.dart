// ignore_for_file: avoid_print
import 'gstin_models.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/features/parties/models/gstin_models_check.dart
//
//  gstin_models.dart imports no Flutter, so it runs on a bare Dart VM
//  from the repo root (as src/core/scan_payload_check.dart does).
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [String extra = '']) {
  print('${ok ? "PASS" : "FAIL"}  $what ${ok ? '' : extra}');
  if (!ok) failed++;
}

const gstin = '33AAECB1234F1ZC';
const other = '29AAGCM9012L1Z3';

const targets = [
  FillTarget('name', 'Customer name', 'name'),
  FillTarget('address', 'Billing address', 'address'),
  FillTarget('city', 'City', 'city'),
  FillTarget('pincode', 'PIN code', 'pincode'),
  FillTarget('stateCode', 'GST state code', 'stateCode'),
  FillTarget('pan', 'PAN', 'pan'),
];

void main() {
  // ── The number itself ─────────────────────────────────────
  final i = gstinInfo(' 33aaecb1234f1zc ');
  check('reads state and PAN off the number', i.valid && i.stateCode == '33' && i.pan == 'AAECB1234F');
  check('the check character holds', i.checksumOk);
  check('the same as the web and the server compute', gstinCheckChar('27AAPFU0939F1Z') == 'V' && gstinCheckChar('33AABCS5678K1Z') == 'Z');
  check('a wrong last character is a typo', gstinInfo('33AAECB1234F1Z5').valid && !gstinInfo('33AAECB1234F1Z5').checksumOk);
  for (final bad in ['', '33AAECB1234F1Z', 'AAECB1234F', '33AAECB1234F1ZCC', null]) {
    check('not a GSTIN: "$bad"', !gstinInfo(bad).valid);
  }
  check('kept without spaces, in capitals', normalGstin(' 33aa ecb1234f1zc ') == gstin);

  // ── What the server sends ─────────────────────────────────
  final a = GstinAnswer.fromJson({
    'success': true, 'gstin': gstin, 'valid': true, 'checksumOk': true, 'stateCode': '33', 'stateName': 'Tamil Nadu', 'pan': 'AAECB1234F',
    'message': 'Active on the GST portal: SUNRISE GARMENTS PRIVATE LIMITED (trade name Sunrise Garments).',
    'portal': {
      'checked': true, 'found': true, 'fromCache': false, 'checkedAt': '2026-11-18T10:12:00.000Z', 'checkedByName': 'Owner', 'source': 'cleartax',
      'via': 'ClearTax', 'said': '', 'status': 'active', 'statusText': 'Active', 'legalName': 'SUNRISE GARMENTS PRIVATE LIMITED',
      'tradeName': 'Sunrise Garments', 'taxpayerType': 'Regular', 'composition': false, 'sez': false, 'registeredOn': '2017-07-01',
      'cancelledOn': '', 'einvoiceBlocked': false, 'address': {'line': '12/4, Avinashi Road', 'city': 'Tiruppur'},
    },
    'fill': {
      'name': 'Sunrise Garments', 'legalName': 'SUNRISE GARMENTS PRIVATE LIMITED', 'tradeName': 'Sunrise Garments',
      'address': '12/4, 2nd Floor, Sunrise Towers, Avinashi Road', 'city': 'Tiruppur', 'pincode': '641603', 'stateCode': '33',
      'fullAddress': '12/4, 2nd Floor, Sunrise Towers, Avinashi Road, Tiruppur, Tamil Nadu - 641603', 'pan': 'AAECB1234F',
      'gstRegistration': 'regular', 'sez': false,
    },
  });
  check('the answer is for the number asked', a.gstin == gstin && a.checksumOk);
  check('found, active, live', a.portal.checked && a.portal.found && a.portal.status == 'active' && a.portal.live);
  check('both names, once each', a.portal.names == 'SUNRISE GARMENTS PRIVATE LIMITED · trade name Sunrise Garments', a.portal.names);
  check('type and registration date', a.portal.about == 'Regular · registered 1 Jul 2017', a.portal.about);
  check('the e-invoice flag as sent', a.portal.einvoiceBlocked == false);
  check('what the form takes', a.fill!.name == 'Sunrise Garments' && a.fill!.pincode == '641603' && a.fill!.gstRegistration == 'regular' && !a.fill!.sez);
  check('the same instant it was checked', a.portal.checkedAt!.toUtc().toIso8601String() == '2026-11-18T10:12:00.000Z');
  check('who and through whom', a.portal.checkedLine().endsWith('through ClearTax by Owner') && a.portal.checkedLine().startsWith('Checked '), a.portal.checkedLine());
  check('an earlier check says so', a.portal.checkedLine(earlier: true).startsWith('Last check: '));

  final same = GstinPortal.fromJson({'checked': true, 'found': true, 'status': 'active', 'legalName': 'ACME LLP', 'tradeName': 'acme llp'});
  check('a trade name equal to the legal name is said once', same.names == 'ACME LLP', same.names);
  check('no name at all', const GstinPortal(checked: true, found: true).names == 'Name not given');

  final cancelled = GstinPortal.fromJson({
    'checked': true, 'found': true, 'status': 'cancelled', 'statusText': 'Cancelled', 'taxpayerType': 'Regular',
    'registeredOn': '2018-04-12', 'cancelledOn': '2024-03-12', 'einvoiceBlocked': null,
  });
  check('cancelled is not live', !cancelled.live);
  check('cancelled says since when', cancelled.about == 'Regular · registered 12 Apr 2018 · cancelled 12 Mar 2024', cancelled.about);
  check('the e-invoice flag not sent is not a no', cancelled.einvoiceBlocked == null);
  for (final s in ['suspended', 'inactive']) {
    check('$s is not live', !GstinPortal.fromJson({'checked': true, 'found': true, 'status': s}).live);
  }
  for (final s in ['provisional', 'unknown']) {
    check('$s may fill the form', GstinPortal.fromJson({'checked': true, 'found': true, 'status': s}).live);
  }

  final typo = GstinAnswer.fromJson({
    'gstin': '33AAECB1234F1Z5', 'valid': true, 'checksumOk': false, 'stateCode': '33', 'pan': 'AAECB1234F',
    'portal': {'checked': false, 'reason': 'checksum'}, 'fill': null, 'message': 'check for a typo',
  });
  check('a typo: nobody was asked, nothing to fill', !typo.portal.checked && typo.portal.reason == 'checksum' && typo.fill == null);
  final none = GstinAnswer.fromJson({
    'gstin': gstin, 'valid': true, 'checksumOk': true, 'stateCode': '33', 'pan': 'AAECB1234F',
    'portal': {'checked': false, 'reason': 'not_connected'}, 'fill': null,
  });
  check('not connected: the number still gives the state and the PAN', none.fromTheNumber['stateCode'] == '33' && none.fromTheNumber['pan'] == 'AAECB1234F');
  final missing = GstinAnswer.fromJson({'gstin': gstin, 'portal': {'checked': true, 'found': false, 'said': 'No records found'}});
  check('no registration: not found, not live, nothing to fill', missing.portal.checked && !missing.portal.found && !missing.portal.live && missing.fill == null);
  check('an answer with nothing in it does not throw', GstinAnswer.fromJson({}).gstin.isEmpty && !GstinAnswer.fromJson({}).portal.checked);
  check('a composition dealer', GstinFill.fromJson({'gstRegistration': 'composition'}).gstRegistration == 'composition');
  check('anything else is regular', GstinFill.fromJson({'gstRegistration': 'what'}).gstRegistration == 'regular');

  // ── Filling a form ────────────────────────────────────────
  final parts = a.fill!.parts;
  var plan = planFill(targets: targets, parts: parts, current: {}, wrote: {});
  check('an empty form takes everything', plan.filled.join(', ') == 'Customer name, Billing address, City, PIN code, GST state code, PAN' && plan.kept.isEmpty, plan.filled.join(', '));
  check('the values written', plan.writes['name'] == 'Sunrise Garments' && plan.writes['city'] == 'Tiruppur' && plan.writes['stateCode'] == '33');

  plan = planFill(targets: targets, parts: parts, current: {'name': 'Sunrise', 'city': 'Tirupur', 'stateCode': '33'}, wrote: {});
  check('what was typed is kept', !plan.writes.containsKey('name') && !plan.writes.containsKey('city'));
  check('and listed with the registration\'s value', plan.kept.length == 2 && plan.kept.first.current == 'Sunrise' && plan.kept.first.value == 'Sunrise Garments' && plan.kept.last.label == 'City');
  check('a field that already matches is neither', plan.filled.join(', ') == 'Billing address, PIN code, PAN', plan.filled.join(', '));

  plan = planFill(targets: targets, parts: parts, current: {'name': '  sunrise   GARMENTS ', 'city': 'tiruppur'}, wrote: {});
  check('the same words in another case are the same', !plan.kept.any((k) => k.field == 'name' || k.field == 'city') && !plan.writes.containsKey('name'));

  // A second number on the same form.
  final wrote = {for (final t in targets) t.field: Wrote(parts[t.part]!, gstin)};
  final after = {for (final t in targets) t.field: parts[t.part]!};
  final meridian = {
    'name': 'Meridian Knits', 'address': '88, Peenya 2nd Stage', 'fullAddress': '88, Peenya 2nd Stage, Bengaluru, Karnataka - 560058',
    'city': 'Bengaluru', 'pincode': '560058', 'stateCode': '29', 'pan': 'AAGCM9012L',
  };
  plan = planFill(targets: targets, parts: meridian, current: after, wrote: wrote);
  check('what the first check filled is replaced by the second', plan.writes.length == 6 && plan.writes['city'] == 'Bengaluru' && plan.kept.isEmpty, '${plan.writes}');

  plan = planFill(targets: targets, parts: meridian, current: {...after, 'city': 'Avinashi'}, wrote: wrote);
  check('a field changed by hand since is theirs', !plan.writes.containsKey('city') && plan.kept.single.field == 'city' && plan.kept.single.current == 'Avinashi');

  plan = planFill(targets: targets, parts: {...meridian, 'pincode': ''}, current: after, wrote: wrote);
  check('a part the registration lacks is left alone', !plan.writes.containsKey('pincode') && plan.writes.length == 5);

  plan = planFill(targets: targets, parts: {...meridian, 'stateCode': '33'}, current: after, wrote: wrote);
  check('a value both numbers share becomes this number\'s', plan.adopted.contains('stateCode') && !plan.writes.containsKey('stateCode'));

  var stale = staleTargets(targets: targets, current: after, wrote: wrote, gstin: other);
  check('all six still stand from the first number', stale.length == 6 && stale.first.label == 'Customer name');
  stale = staleTargets(targets: targets, current: after, wrote: wrote, gstin: gstin);
  check('nothing is stale under the number it was filled for', stale.isEmpty);
  stale = staleTargets(targets: targets, current: {...after, 'name': 'Typed over', 'city': ''}, wrote: wrote, gstin: other);
  check('what was typed over or cleared is not stale', stale.map((t) => t.field).join(',') == 'address,pincode,stateCode,pan', stale.map((t) => t.field).join(','));
  check('a form Verify never touched has nothing stale', staleTargets(targets: targets, current: after, wrote: {}, gstin: other).isEmpty);

  // ── Dates ─────────────────────────────────────────────────
  check('a calendar date', dayText('2017-07-01') == '1 Jul 2017' && dayText('2024-03-12') == '12 Mar 2024');
  check('not a date comes back as it was', dayText('soon') == 'soon' && dayText('2024-13-01') == '2024-13-01');
  check('morning', whenText(DateTime(2026, 11, 18, 9, 5)) == '18 Nov 2026, 9:05 am', whenText(DateTime(2026, 11, 18, 9, 5)));
  check('afternoon', whenText(DateTime(2026, 11, 18, 15, 42)) == '18 Nov 2026, 3:42 pm');
  check('noon and midnight', whenText(DateTime(2026, 11, 18, 12, 0)) == '18 Nov 2026, 12:00 pm' && whenText(DateTime(2026, 11, 18, 0, 30)) == '18 Nov 2026, 12:30 am');

  print(failed == 0 ? '\nall passed' : '\n$failed FAILED');
  if (failed != 0) throw StateError('$failed check(s) failed');
}

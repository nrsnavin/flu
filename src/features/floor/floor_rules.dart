// ══════════════════════════════════════════════════════════════
//  FLOOR ENTRY — the rules the screen follows before it asks the
//  server. The same as the web's floor screen (prod_web
//  features/floor/floorRules.ts), so a supervisor who uses both sees
//  the same answers.
// ══════════════════════════════════════════════════════════════

/// The shift running now, by the factory's clock: day 8 am to 8 pm,
/// night after, and before 8 am still the night shift OF THE DAY BEFORE
/// — the night that started yesterday evening is the one being entered.
/// The server decides the same way (services/machineLoading.js).
({String dateKey, String shift}) shiftNow([DateTime? at]) {
  final now = at ?? DateTime.now();
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final h = now.hour;
  if (h >= 8 && h < 20) return (dateKey: key(now), shift: 'DAY');
  if (h >= 20) return (dateKey: key(now), shift: 'NIGHT');
  final y = DateTime(now.year, now.month, now.day - 1);
  return (dateKey: key(y), shift: 'NIGHT');
}

/// What a scanned or typed code is, before the server is asked:
///
///   `MACHINE|id|ID`          the label on a loom → sent as it is
///   SHIFTROW|… / FLOORROW|…  a row off a printed sheet → sent
///   J-12 / JOB|…             a job label → refused here, with the reason
///   anything else            a typed machine ID → sent trimmed
///
/// Returns the code to send, or the problem to show (never both).
({String? code, String? problem}) readLoomCode(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return (code: null, problem: 'Scan the label on the loom, or type its ID.');
  }
  if (RegExp(r'^J-?\d+$', caseSensitive: false).hasMatch(text) ||
      RegExp(r'^JOB\|', caseSensitive: false).hasMatch(text)) {
    return (code: null, problem: 'That is a job label. Scan the label on the loom itself.');
  }
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) {
    return (code: null, problem: 'That QR is a web link, not a loom label.');
  }
  return (code: text, problem: null);
}

/// What the floor can do on a loom this shift (the server's `entry`).
const entryLabels = {
  'free': 'Free',
  'loading': 'Loading',
  'unplanned': 'Not on plan',
  'ready': 'To enter',
  'entered': 'Entered',
  'verified': 'Verified',
  'locked': 'Locked',
};

/// Whether a loom's production can be entered (or corrected) now.
bool canEnter(String entry) =>
    entry == 'ready' || entry == 'unplanned' || entry == 'entered';

/// "7.30" → "7:30:00"; "730" → "7:30:00"; "07:30:00" stays as it is.
/// Typed on a phone's number pad a run time rarely has a colon. Minutes
/// and seconds to 59; anything else comes back as typed, for the server
/// to refuse in its own words.
String tidyRunTime(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  int? h, mm, ss;
  final m = RegExp(r'^(\d{1,2})[:.](\d{1,2})(?:[:.](\d{1,2}))?$').firstMatch(t);
  if (m != null) {
    h = int.parse(m.group(1)!);
    mm = int.parse(m.group(2)!);
    ss = m.group(3) == null ? 0 : int.parse(m.group(3)!);
  } else {
    final d = RegExp(r'^(\d{3,4})$').firstMatch(t);
    if (d == null) return t;
    final p = d.group(1)!.padLeft(4, '0');
    h = int.parse(p.substring(0, 2));
    mm = int.parse(p.substring(2));
    ss = 0;
  }
  if (mm > 59 || ss > 59) return t;
  return '$h:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
}

/// Minutes run from a run time as typed; null when it cannot be read.
double? runMinutes(String raw) {
  final tidy = tidyRunTime(raw);
  final m = RegExp(r'^(\d{1,2}):(\d{2}):(\d{2})$').firstMatch(tidy);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 +
      int.parse(m.group(2)!) +
      int.parse(m.group(3)!) / 60;
}

/// What a head weaves a minute when the loom has no rate of its own yet.
const defaultCmPerMin = 30.0;

/// Metres one head makes in the run time at the rate, to a tenth of a
/// metre (the web's expectedPerHead); null when the run time cannot be
/// read.
double? expectedPerHead(String runTime, {double cmPerMin = defaultCmPerMin}) {
  final minutes = runMinutes(runTime);
  if (minutes == null) return null;
  return (minutes * cmPerMin).round() / 100;
}

/// The figure as the field shows it: "135", "135.5".
String perHeadText(String runTime, {double cmPerMin = defaultCmPerMin}) {
  final m = expectedPerHead(runTime, cmPerMin: cmPerMin);
  if (m == null) return '';
  return m == m.roundToDouble() ? m.toInt().toString() : m.toString();
}

/// The order the list shows looms in: what needs entering first, then
/// entered, then verified, then the rest; by loom ID within each.
int listOrder(String entryA, String idA, String entryB, String idB) {
  int rank(String e) => e == 'ready' || e == 'unplanned'
      ? 0
      : e == 'entered'
          ? 1
          : e == 'verified'
              ? 2
              : 3;
  final r = rank(entryA) - rank(entryB);
  if (r != 0) return r;
  return _natural(idA, idB);
}

/// "L-2" before "L-10".
int _natural(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]), nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// The kinds a remark is classed into on the server (services/floorRemark.js).
const remarkKinds = {
  'beam_change': 'Beam change',
  'yarn_break': 'Yarn breaks',
  'mechanical': 'Mechanical fault',
  'electrical': 'Electrical fault',
  'power_cut': 'Power cut',
  'no_operator': 'No operator',
  'waiting_material': 'Waiting for material',
  'quality': 'Quality',
  'other': 'Remark',
};

/// "Beam change · 40 min", "Power cut · 1 h 10 min".
String remarkWords(String kind, int? minutes) {
  final label = remarkKinds[kind] ?? 'Remark';
  if (minutes == null) return label;
  if (minutes >= 60) {
    final rest = minutes % 60;
    return '$label · ${minutes ~/ 60} h${rest > 0 ? ' $rest min' : ''}';
  }
  return '$label · $minutes min';
}

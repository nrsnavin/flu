import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  THE AADHAAR CARD'S QR CODE: READ IT, AND SEE WHETHER UIDAI
//  SIGNED IT
//
//  The holder agrees first: offline verification is theirs to allow.
//  The phone's camera reads the large QR code on the letter, the
//  e-Aadhaar or the PVC card. The server reads it and checks UIDAI's
//  signature (utils/aadhaarQr.js on the server), as the web page does,
//  and what comes back is shown for what it is: signed, not matching,
//  not checked, or the old unsigned code. A code whose signature fails
//  is never offered for filling, and no comparison is drawn from its
//  altered details.
//
//  With an employee named, the outcome is kept on their record. On the
//  new-employee form nothing is kept yet: the form fills from the card,
//  and the code goes with the record when it is saved.
// ══════════════════════════════════════════════════════════════

String _s(Object? v) => v?.toString() ?? '';
String? _sn(Object? v) => v == null || v.toString().isEmpty ? null : v.toString();
bool? _b(Object? v) => v is bool ? v : null;
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};

class AadhaarQrFields {
  final String name;
  /// YYYY-MM-DD (a year alone comes as YYYY-01-01), or null.
  final String? dob;
  /// male, female or other, or null.
  final String? gender;
  final String careOf;
  final String address;
  final String pincode;
  const AadhaarQrFields({required this.name, this.dob, this.gender, this.careOf = '', this.address = '', this.pincode = ''});

  static AadhaarQrFields? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    return AadhaarQrFields(
      name: _s(j['name']), dob: _sn(j['dob']), gender: _sn(j['gender']),
      careOf: _s(j['careOf']), address: _s(j['address']), pincode: _s(j['pincode']),
    );
  }
}

class AadhaarQrRead {
  /// secure: the signed code on cards since 2019; old: the earlier XML code.
  final String kind;
  final String? version;
  /// known, guessed (a newer layout whose fields all had their shape), unreadable.
  final String layout;
  /// valid, invalid, unchecked or unsigned.
  final String signature;
  final String? last4;
  final DateTime? issuedAt;
  final AadhaarQrFields? fields;
  /// The full number: only the old XML code carries it.
  final String? aadhaar;
  final String? mobileLast4;
  const AadhaarQrRead({
    required this.kind, this.version, required this.layout, required this.signature,
    this.last4, this.issuedAt, this.fields, this.aadhaar, this.mobileLast4,
  });

  factory AadhaarQrRead.from(Object? raw) {
    final j = _map(raw);
    return AadhaarQrRead(
      kind: _s(j['kind']), version: _sn(j['version']), layout: _s(j['layout']),
      signature: _s(j['signature']), last4: _sn(j['last4']),
      issuedAt: DateTime.tryParse(_s(j['issuedAt']))?.toLocal(),
      fields: AadhaarQrFields.from(j['fields']), aadhaar: _sn(j['aadhaar']), mobileLast4: _sn(j['mobileLast4']),
    );
  }
}

class AadhaarQrMatches {
  final bool? last4;
  /// same, close or different.
  final String? name;
  final bool? phone;
  const AadhaarQrMatches({this.last4, this.name, this.phone});
  factory AadhaarQrMatches.from(Object? raw) {
    final j = _map(raw);
    return AadhaarQrMatches(last4: _b(j['last4']), name: _sn(j['name']), phone: _b(j['phone']));
  }
}

/// The outcome kept on an employee.
class AadhaarCheck {
  final String signature;
  final String layout;
  final DateTime? at;
  final String byName;
  final String last4;
  final AadhaarQrMatches matches;
  const AadhaarCheck({required this.signature, required this.layout, this.at, this.byName = '', this.last4 = '', this.matches = const AadhaarQrMatches()});
  static AadhaarCheck? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    if (_s(j['signature']).isEmpty) return null;
    return AadhaarCheck(
      signature: _s(j['signature']), layout: _s(j['layout']),
      at: DateTime.tryParse(_s(j['at']))?.toLocal(), byName: _s(j['byName']), last4: _s(j['last4']),
      matches: AadhaarQrMatches.from(j['matches']),
    );
  }
}

class AadhaarQrResult {
  final AadhaarQrRead read;
  final AadhaarQrMatches matches;
  /// Set when an employee was named: the outcome kept on their record.
  final AadhaarCheck? check;
  const AadhaarQrResult({required this.read, required this.matches, this.check});
  factory AadhaarQrResult.from(Object? raw) {
    final j = _map(raw);
    return AadhaarQrResult(read: AadhaarQrRead.from(j['read']), matches: AadhaarQrMatches.from(j['matches']), check: AadhaarCheck.from(j['check']));
  }
}

class AadhaarQrError implements Exception {
  final String message;
  const AadhaarQrError(this.message);
  @override
  String toString() => message;
}

class AadhaarQrApi {
  static final Dio _dio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

  /// The card's details, UIDAI's signature, and how it compares with the
  /// employee (or with what the form holds). Sent with the holder's consent.
  static Future<AadhaarQrResult> check({required String qr, String? employeeId, Map<String, String>? compare}) async {
    try {
      final res = await _dio.post('/employee/aadhaar-qr', data: {
        'qr': qr,
        'consent': true,
        if (employeeId != null) 'employeeId': employeeId,
        if (employeeId == null && compare != null) 'compare': compare,
      });
      return AadhaarQrResult.from(res.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw AadhaarQrError(data is Map && data['message'] != null
          ? data['message'].toString()
          : e.response == null
              ? 'Could not reach the server. Check the connection and try again.'
              : 'The code could not be checked. Try again.');
    }
  }

  /// The card's date of birth, gender and address on the employee's record.
  static Future<void> useOnRecord(String employeeId, AadhaarQrFields f) async {
    try {
      await _dio.put('/employee/update', queryParameters: {'id': employeeId}, data: {
        if (f.dob != null) 'dob': f.dob,
        if (f.gender != null) 'gender': f.gender,
        if (f.address.isNotEmpty) 'address': f.address,
        if (f.pincode.isNotEmpty) 'pincode': f.pincode,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      throw AadhaarQrError(data is Map && data['message'] != null ? data['message'].toString() : 'Could not save the card\'s details.');
    }
  }
}

// ── Words ─────────────────────────────────────────────────────

class SignatureWords {
  final String title;
  final String detail;
  final Color color;
  final IconData icon;
  const SignatureWords(this.title, this.detail, this.color, this.icon);
}

/// What a signature state means, in plain words.
SignatureWords signatureWords(String signature) => switch (signature) {
      'valid' => SignatureWords('Signed by UIDAI', 'These are the details UIDAI issued. The code has not been changed.',
          ErpColors.successGreen, Icons.verified_user_outlined),
      'invalid' => SignatureWords('UIDAI\'s signature does not match',
          'This code has been changed, or UIDAI did not issue it. Do not rely on these details: ask for the card again.',
          ErpColors.errorRed, Icons.gpp_bad_outlined),
      'unsigned' => SignatureWords('Old QR code: nothing to check',
          'Cards printed before 2019 have a QR code without UIDAI\'s signature. It can fill the form, but it proves nothing.',
          ErpColors.warningAmber, Icons.help_outline_rounded),
      _ => SignatureWords('Signature not checked',
          'UIDAI\'s certificates are not on the server yet, so these details are unproven. On the server, run: node scripts/fetch-uidai-certs.js',
          ErpColors.warningAmber, Icons.help_outline_rounded),
    };

/// The comparisons that could be made, as lines: none for a code whose signature fails.
List<({bool ok, String text})> matchLines(AadhaarQrRead read, AadhaarQrMatches m, {required bool onRecord}) {
  if (read.signature == 'invalid') return const [];
  final where = onRecord ? 'on record' : 'typed';
  return [
    if (m.last4 != null)
      (ok: m.last4!, text: m.last4! ? 'Last 4 digits match the Aadhaar number $where' : 'Last 4 digits do not match the Aadhaar number $where'),
    if (m.name != null)
      (ok: m.name != 'different', text: switch (m.name) { 'same' => 'Name matches', 'close' => 'Name is close (initials or a word differ)', _ => 'Name does not match' }),
    if (m.phone != null)
      (ok: m.phone!, text: m.phone! ? 'Phone matches the mobile registered with Aadhaar' : 'Phone is not the mobile registered with Aadhaar'),
  ];
}

/// The large decimal number of a Secure QR code, or the old XML code.
bool looksLikeAadhaarQr(String? raw) {
  final t = raw?.trim() ?? '';
  return (t.length >= 500 && RegExp(r'^\d+$').hasMatch(t)) || RegExp(r'<(PrintLetterBarcodeData|QPDB)\b').hasMatch(t);
}

String dmy(String? iso) => iso == null || iso.isEmpty ? '' : iso.split('-').reversed.join('/');

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String dayText(DateTime? d) => d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

String genderText(String? g) => switch (g) { 'male' => 'Male', 'female' => 'Female', 'other' => 'Transgender / other', _ => '' };

// ── The camera ────────────────────────────────────────────────

/// Open the camera and return the first Aadhaar QR code it reads; null when dismissed.
Future<String?> scanAadhaarQr(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AadhaarScanSheet(),
    );

class _AadhaarScanSheet extends StatefulWidget {
  const _AadhaarScanSheet();
  @override
  State<_AadhaarScanSheet> createState() => _AadhaarScanSheetState();
}

class _AadhaarScanSheetState extends State<_AadhaarScanSheet> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;
  bool _other = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (looksLikeAadhaarQr(raw)) {
        _done = true;
        Navigator.of(context).pop(raw!.trim());
        return;
      }
      if (raw != null && raw.isNotEmpty && !_other && mounted) setState(() => _other = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: ErpColors.navyDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            Expanded(child: Text('Scan the Aadhaar QR code', style: TextStyle(color: ErpColors.textOnDark, fontSize: 15, fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'Torch', onPressed: _controller.toggleTorch, icon: Icon(Icons.flashlight_on_outlined, color: ErpColors.textOnDark)),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: ErpColors.textOnDark)),
          ]),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'The camera could not be started. Allow camera access in the phone\'s settings, or check the card on the web page with a photo of it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 13),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(border: Border.all(color: ErpColors.accentLight, width: 2), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Text(
            _other
                ? 'That is not an Aadhaar QR code. Scan the large QR code on the card.'
                : 'Hold the card\'s large QR code inside the frame. Close and steady reads it best.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _other ? ErpColors.statusPartialText : ErpColors.textOnDarkSub),
          ),
        ),
      ]),
    );
  }
}

// ── The check ─────────────────────────────────────────────────

/// What the check ended with: the result, the code's text, and whether
/// to use the card's details (the form fills, or the record takes them).
class AadhaarQrOutcome {
  final AadhaarQrResult result;
  final String qr;
  final bool fill;
  const AadhaarQrOutcome(this.result, this.qr, {this.fill = false});
}

typedef AadhaarScan = Future<String?> Function(BuildContext context);
typedef AadhaarCheckCall = Future<AadhaarQrResult> Function({required String qr, String? employeeId, Map<String, String>? compare});

class AadhaarQrPage extends StatefulWidget {
  /// Who is being checked, for the consent line.
  final String? personName;
  /// Keep the outcome on this employee.
  final String? employeeId;
  /// What the form holds, to compare the card with when there is no employee yet.
  final Map<String, String>? compare;
  final String fillLabel;
  final AadhaarScan scan;
  final AadhaarCheckCall check;
  const AadhaarQrPage({
    super.key,
    this.personName,
    this.employeeId,
    this.compare,
    this.fillLabel = 'Fill the form',
    this.scan = scanAadhaarQr,
    this.check = AadhaarQrApi.check,
  });

  @override
  State<AadhaarQrPage> createState() => _AadhaarQrPageState();
}

class _AadhaarQrPageState extends State<AadhaarQrPage> {
  bool _consent = false;
  bool _busy = false;
  String? _error;
  AadhaarQrResult? _result;
  String? _qr;

  Future<void> _scanAndCheck() async {
    final code = await widget.scan(context);
    if (code == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.check(qr: code, employeeId: widget.employeeId, compare: widget.employeeId == null ? widget.compare : null);
      if (!mounted) return;
      setState(() {
        _result = r;
        _qr = code;
      });
    } on AadhaarQrError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'The code could not be checked. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final who = (widget.personName ?? '').trim().isEmpty ? 'The employee' : widget.personName!.trim();
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: Colors.white,
        title: Text('Aadhaar QR check', style: ErpTextStyles.pageTitle),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_result == null) ...[
          ErpSectionCard(
            title: 'CONSENT',
            icon: Icons.handshake_outlined,
            // Its own Material: the card's colour would hide the tile's ripple.
            child: Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('$who agrees to this check of their Aadhaar QR code.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                subtitle: Text(
                  'The code is read and UIDAI\'s signature on it is checked. ${widget.employeeId != null ? 'The outcome is kept on their record, with your name; ' : 'Only the outcome is kept, with the record; '}the photo on the card is not.',
                  style: TextStyle(fontSize: 11, color: ErpColors.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _consent && !_busy ? _scanAndCheck : null,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              label: Text(_busy ? 'Checking…' : 'Scan the QR code', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: ErpColors.accentBlue, elevation: 0),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: ErpColors.errorRed, fontSize: 13)),
          ],
        ] else
          _ResultView(
            result: _result!,
            onRecord: widget.employeeId != null,
            fillLabel: widget.fillLabel,
            onFill: _result!.read.fields != null && _result!.read.signature != 'invalid'
                ? () => Navigator.of(context).pop(AadhaarQrOutcome(_result!, _qr!, fill: true))
                : null,
            onAgain: () => setState(() {
              _result = null;
              _error = null;
            }),
            onDone: () => Navigator.of(context).pop(AadhaarQrOutcome(_result!, _qr!)),
          ),
      ]),
    );
  }
}

class _ResultView extends StatelessWidget {
  final AadhaarQrResult result;
  final bool onRecord;
  final String fillLabel;
  final VoidCallback? onFill;
  final VoidCallback onAgain;
  final VoidCallback onDone;
  const _ResultView({required this.result, required this.onRecord, required this.fillLabel, required this.onFill, required this.onAgain, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final read = result.read;
    final w = signatureWords(read.signature);
    final f = read.fields;
    final rows = <(String, String)>[
      if (f != null) ...[
        ('Name', f.name),
        ('Date of birth', dmy(f.dob)),
        ('Gender', genderText(f.gender)),
        ('Care of', f.careOf),
        ('Address', f.address),
        ('Pin code', f.pincode),
      ],
      if (read.aadhaar != null) ('Aadhaar number', read.aadhaar!) else if (read.last4 != null) ('Aadhaar number', 'ends in ${read.last4}'),
      if (read.mobileLast4 != null) ('Registered mobile', 'ends in ${read.mobileLast4}'),
      if (read.issuedAt != null) ('Code made on', dayText(read.issuedAt)),
    ].where((r) => r.$2.isNotEmpty).toList();
    final lines = matchLines(read, result.matches, onRecord: onRecord);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: w.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: w.color.withValues(alpha: 0.4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(w.icon, color: w.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.title, style: TextStyle(fontWeight: FontWeight.w800, color: w.color)),
              const SizedBox(height: 4),
              Text(w.detail, style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
            ]),
          ),
        ]),
      ),
      if (read.layout == 'unreadable') ...[
        const SizedBox(height: 10),
        Text('The signature was checked, but this card\'s QR layout${read.version != null ? ' (${read.version})' : ''} is not one this version can read field by field. Type the details in.',
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
      ],
      if (rows.isNotEmpty) ...[
        const SizedBox(height: 12),
        ErpSectionCard(
          title: 'ON THE CARD',
          icon: Icons.credit_card_rounded,
          child: Column(children: [for (final r in rows) ErpInfoRow(r.$1, r.$2)]),
        ),
      ],
      if (read.signature == 'invalid') ...[
        const SizedBox(height: 8),
        Text('No comparison is shown: these details are not the card\'s.', style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
      ],
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${l.ok ? '✓' : '✗'} ${l.text}',
              style: TextStyle(fontSize: 13, color: l.ok ? ErpColors.successGreen : ErpColors.errorRed)),
        ),
      if (result.check != null) ...[
        const SizedBox(height: 8),
        Text('Kept on their record.', style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onAgain,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Scan another'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: onFill ?? onDone,
            style: ElevatedButton.styleFrom(backgroundColor: ErpColors.accentBlue, elevation: 0),
            child: Text(onFill != null ? fillLabel : 'Done', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ]);
  }
}

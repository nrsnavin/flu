import 'dart:convert';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'job_qr_label_doc.dart';

// ══════════════════════════════════════════════════════════════
//  RUN ME:  dart run src/features/Job/screens/job_qr_label_check.dart
//
//  Builds the label and reads its page box back out of the generated
//  PDF, rather than trusting that a page declared 2in wide came out
//  2in wide.
//
//  That distinction is not pedantry. The WEB version of this label
//  shipped at the right size with the QR flush against the paper
//  edge, because Tailwind silently dropped `p-[0.1in]` at build time;
//  and the first attempt to prove the page size passed while proving
//  nothing, because the test handed an explicit width to page.pdf()
//  and thereby forced the very thing it was checking. A label at the
//  wrong size does not raise anything — it prints, and then does not
//  fit the roll.
//
//  So: generate the real bytes, parse the real /MediaBox.
// ══════════════════════════════════════════════════════════════

int failed = 0;
void check(String what, bool ok, [String extra = '']) {
  print('${ok ? "PASS" : "FAIL"}  $what ${ok ? '' : extra}');
  if (!ok) failed++;
}

/// Pull the first /MediaBox out of a PDF's raw bytes.
List<double>? mediaBoxOf(List<int> bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final m = RegExp(
    r'/MediaBox\s*\[\s*([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s+([\d.-]+)\s*\]',
  ).firstMatch(text);
  if (m == null) return null;
  return [
    for (var i = 1; i <= 4; i++) double.parse(m.group(i)!),
  ];
}

Future<void> main() async {
  const id = '6a85c96260514cc7d9a7401f';

  // ── The payload matches the web's rule ────────────────────
  check(
    'payload is <origin>/jobs/<id>, API path stripped',
    jobLabelPayload('https://erp.example.com/api/v2', id) ==
        'https://erp.example.com/jobs/$id',
    'got ${jobLabelPayload('https://erp.example.com/api/v2', id)}',
  );
  check(
    'a port survives',
    jobLabelPayload('http://192.168.1.9:4000/api/v2', id) ==
        'http://192.168.1.9:4000/jobs/$id',
    'got ${jobLabelPayload('http://192.168.1.9:4000/api/v2', id)}',
  );
  check(
    'a sandbox host stays the sandbox host',
    jobLabelPayload('https://sandbox.example.com/api/v2', id)
        .startsWith('https://sandbox.example.com/'),
  );
  check('a junk base does not crash',
      jobLabelPayload('not a url', id) == '/jobs/$id',
      'got ${jobLabelPayload('not a url', id)}');

  // The label must round-trip through the scanner this app ships.
  // (Parser lives in core/scan_payload.dart and is checked there; this
  // asserts the two agree on the FORMAT.)
  final payload = jobLabelPayload('https://erp.example.com/api/v2', id);
  check('the printed payload contains /jobs/ and the id',
      payload.contains('/jobs/$id'));

  // ── The page really is 2in square ─────────────────────────
  final doc = buildJobLabelDocument(payload: payload, jobNo: '4821');
  final bytes = await doc.save();

  final box = mediaBoxOf(bytes);
  check('the PDF declares a MediaBox', box != null);
  if (box != null) {
    final w = box[2] - box[0];
    final h = box[3] - box[1];
    const want = kLabelInches * PdfPageFormat.inch; // 144pt
    check('width is 2in (144pt)', (w - want).abs() < 0.5, 'got ${w}pt');
    check('height is 2in (144pt)', (h - want).abs() < 0.5, 'got ${h}pt');
    check('it is square', (w - h).abs() < 0.5, 'got ${w}x$h');

    // CONTROL: the three assertions above must be capable of FAILING.
    // A differently-sized page has to read back differently, or
    // mediaBoxOf is not measuring anything and "144pt" was a
    // coincidence of the parser, not a fact about the label.
    final a4 = pw.Document()
      ..addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Container(),
      ));
    final a4Box = mediaBoxOf(await a4.save());
    final a4Width = a4Box == null ? 0.0 : a4Box[2] - a4Box[0];
    check(
      'control: an A4 page reads back as A4, not as 144pt',
      a4Box != null &&
          (a4Width - PdfPageFormat.a4.width).abs() < 0.5 &&
          (a4Width - want).abs() > 1,
      'got ${a4Width}pt, expected ~${PdfPageFormat.a4.width}pt',
    );
  }

  // ── The symbol encodes what we think it does ──────────────
  final qr = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium);
  check('the payload is encodable as a QR', () {
    try {
      qr.verify(payload);
      return true;
    } catch (_) {
      return false;
    }
  }());

  // A long host must still fit — this is the case that silently
  // shrinks the modules and is why the quiet zone is expressed in
  // modules rather than inches.
  final longPayload = jobLabelPayload(
      'https://a-rather-long-tenant-name.erp.example.co.in/api/v2', id);
  check('a long host still encodes', () {
    try {
      qr.verify(longPayload);
      return true;
    } catch (_) {
      return false;
    }
  }());
  final longDoc =
      buildJobLabelDocument(payload: longPayload, jobNo: '4821');
  final longBox = mediaBoxOf(await longDoc.save());
  check('a long host does not change the paper size',
      longBox != null &&
          (longBox[2] - longBox[0] - kLabelInches * PdfPageFormat.inch)
                  .abs() <
              0.5,
      'got ${longBox?[2]}');

  print(failed == 0 ? '\nALL PASS' : '\n$failed FAILED');
}

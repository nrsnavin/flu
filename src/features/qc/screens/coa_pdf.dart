import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  CERTIFICATE OF ANALYSIS
//
//  The document that leaves the building with the goods. The web has
//  printed it since QC shipped; the phone could record a QC check and
//  then not produce the certificate for it, which is the half of the
//  job that the customer actually receives.
//
//  ── Drawn here, not fetched ────────────────────────────────────
//  Unlike the quotation and the delivery challan, there is no
//  server-rendered COA to download — the web builds it in the browser
//  from /qc/coa. So this draws the same payload, and the rule is that
//  the DATA comes from the same endpoint: the certificate must not be
//  able to disagree with the screen about which records passed.
//
//  ── What it certifies is the LATEST passing record ─────────────
//  The route picks the most recent passing QcRecord per elastic. This
//  never re-derives that. A certificate assembled from a different
//  rule than the one the endpoint applies is a certificate that says
//  something nobody has checked.
//
//  ── An empty certificate is refused, not printed ───────────────
//  A job with no passing QC yields a sheet with a heading, a customer
//  name and no results. That is a document that LOOKS like a
//  certificate and certifies nothing, and it would go out of the door
//  attached to goods. The caller is told there is nothing to certify
//  instead.
// ══════════════════════════════════════════════════════════════

class CoaEmpty implements Exception {
  const CoaEmpty();
  @override
  String toString() =>
      'No passing QC records for this job yet — there is nothing to certify.';
}

class CoaPdf {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/qc');

  static Future<Map<String, dynamic>> fetch(String jobId) async {
    final res = await _dio.get('/coa', queryParameters: {'jobId': jobId});
    return Map<String, dynamic>.from(res.data['coa'] as Map);
  }

  /// Fetch and open. Throws [CoaEmpty] when there is nothing to
  /// certify, and lets a DioException through for the caller's own
  /// message handling.
  static Future<void> generate(String jobId) async {
    final coa = await fetch(jobId);
    final items = (coa['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (items.isEmpty) throw const CoaEmpty();

    final doc = pw.Document();
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final day = DateFormat('dd MMM yyyy');

    final subtitle = [
      'Job J-${coa['jobOrderNo'] ?? '—'}',
      if (coa['orderNo'] != null) 'Order #${coa['orderNo']}',
      if ((coa['customerPo'] ?? '').toString().isNotEmpty)
        'PO ${coa['customerPo']}',
      if ((coa['customerName'] ?? '').toString().isNotEmpty)
        coa['customerName'].toString(),
    ].join('  ·  ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          // ── Heading ───────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(width: 1.6)),
            ),
            child: pw.Column(children: [
              pw.Text('CERTIFICATE OF ANALYSIS',
                  style: pw.TextStyle(
                      fontSize: 17, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
          pw.SizedBox(height: 14),

          for (final item in items) ...[
            pw.Text(item['elasticName']?.toString() ?? '—',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _resultsTable(item, bold),
            pw.SizedBox(height: 3),
            pw.Text(
              [
                'Checked by ${_or(item['checkedBy'], '—')}',
                if (item['checkedAt'] != null)
                  'on ${_date(item['checkedAt'], day)}',
              ].join(' '),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
          ],

          pw.SizedBox(height: 26),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 170,
              padding: const pw.EdgeInsets.only(top: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: 0.8)),
              ),
              child: pw.Text('Authorised signatory',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/COA_J${coa['jobOrderNo'] ?? 'job'}.pdf');
    await file.writeAsBytes(await doc.save());
    await OpenFile.open(file.path);
  }

  static pw.Widget _resultsTable(Map<String, dynamic> item, pw.TextStyle bold) {
    final results = (item['results'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (results.isEmpty) {
      return pw.Text('No parameters recorded.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
    }

    return pw.TableHelper.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: const {3: pw.Alignment.center},
      border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey500),
      headers: const ['Parameter', 'Specified', 'Measured', 'Result'],
      data: [
        for (final r in results)
          [
            _or(r['parameter'], '—'),
            _or(r['expected'], '—'),
            _or(r['measured'], '—'),
            // Every row on a COA is a passing record by construction,
            // but the flag is printed from the data rather than assumed
            // — a certificate that prints PASS regardless of what it
            // was handed is not a certificate.
            r['pass'] == true ? 'PASS' : 'FAIL',
          ],
      ],
    );
  }

  static String _or(dynamic v, String fallback) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  static String _date(dynamic v, DateFormat f) {
    final d = DateTime.tryParse(v.toString());
    return d == null ? '—' : f.format(d);
  }
}

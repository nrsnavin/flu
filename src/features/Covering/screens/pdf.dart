import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/covering.dart';

// ══════════════════════════════════════════════════════════════
//  COVERING PROGRAM PDF  —  A5, minimal, print-safe
//
//  Sections:
//   1. Page header  : title, job#, customer, date, status
//   2. Job Summary  : 5-column key-value table
//   3. Elastic Summary (one row per elastic):
//        # | Elastic | Qty | Warp Spandex | Sp. Covering | Sp. Ends | Total Wt
//      Warp Spandex cell : materialName / ends / weight
//      Sp. Covering cell : materialName / weight
//      Sp. Ends          : el.spandexEnds
//      Total Wt          : warpSpandex.weight + spandexCovering.weight
//   4. Signature strip
// ══════════════════════════════════════════════════════════════
class CoveringProgramPdf {
  static const _dark    = PdfColor.fromInt(0xFF1A1A1A);
  static const _mid     = PdfColor.fromInt(0xFF444444);
  static const _lite    = PdfColor.fromInt(0xFF888888);
  static const _hdrFill = PdfColor.fromInt(0xFFD9E1F2);
  static const _altFill = PdfColor.fromInt(0xFFF2F2F2);
  static const _bdr     = PdfColor.fromInt(0xFFAAAAAA);
  static const _bdrMed  = PdfColor.fromInt(0xFF666666);
  static const _white   = PdfColors.white;

  static Future<void> generate(CoveringDetail covering) async {
    final pdf  = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();
    final now  = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.only(
          left:   10 * PdfPageFormat.mm,
          right:  10 * PdfPageFormat.mm,
          top:    10 * PdfPageFormat.mm + 15 * PdfPageFormat.mm,
          bottom:  9 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: reg, bold: bold),
        header: (_) => _pageHeader(covering, bold, reg),
        footer: (ctx) => _pageFooter(ctx, reg),
        build: (ctx) => [
          _secHeading('JOB SUMMARY', bold),
          pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
          _jobSummary(covering.job, bold, reg),
          pw.SizedBox(height: 3.5 * PdfPageFormat.mm),
          _secHeading('ELASTICS  (${covering.elasticPlanned.length} items)', bold),
          pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
          _elasticSummaryTable(covering.elasticPlanned, bold, reg),
          pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
          _expectedWeightRow(covering.elasticPlanned, bold, reg),
          pw.SizedBox(height: 4 * PdfPageFormat.mm),
          _signRow(bold, reg),
        ],
      ),
    );

    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/CoveringProgram_J${covering.job.jobOrderNo}'
        '_${DateFormat('yyyyMMdd').format(now)}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // ── Page Header ──────────────────────────────────────────
  static pw.Widget _pageHeader(CoveringDetail c, pw.Font bold, pw.Font reg) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('COVERING PROGRAM',
            style: pw.TextStyle(font: bold, fontSize: 11, color: _dark, letterSpacing: 0.5)),
        pw.Text(
          'Job #${c.job.jobOrderNo}   |   ${c.job.customerName ?? '—'}   |   '
              '${_fmt(c.date)}   |   ${c.status.toUpperCase().replaceAll('_', ' ')}',
          style: pw.TextStyle(font: reg, fontSize: 6.5, color: _mid),
        ),
      ]),
      pw.SizedBox(height: 2),
      pw.Divider(thickness: 0.65, color: _bdrMed),
    ]);
  }

  // ── Page Footer ──────────────────────────────────────────
  static pw.Widget _pageFooter(pw.Context ctx, pw.Font reg) {
    return pw.Column(children: [
      pw.Divider(thickness: 0.4, color: _bdr),
      pw.SizedBox(height: 2),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Supreme Stitch ERP',
            style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
      ]),
    ]);
  }

  // ── Section Heading ───────────────────────────────────────
  static pw.Widget _secHeading(String title, pw.Font bold) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title,
          style: pw.TextStyle(font: bold, fontSize: 7, color: _dark, letterSpacing: 0.3)),
      pw.SizedBox(height: 2),
      pw.Divider(thickness: 0.8, color: _bdrMed),
    ]);
  }

  // ── Job Summary ───────────────────────────────────────────
  static pw.Widget _jobSummary(JobSummary job, pw.Font bold, pw.Font reg) {
    final labels = ['Job Order No.', 'Customer', 'PO No.', 'Order No.', 'Status'];
    final values = [
      '#${job.jobOrderNo}',
      job.customerName ?? '—',
      job.po ?? '—',
      job.orderNo ?? '—',
      job.status.toUpperCase().replaceAll('_', ' '),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.35),
      columnWidths: const {
        0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _hdrFill),
          children: labels.map((l) => _c(l, reg, 6, _mid, align: pw.TextAlign.center)).toList(),
        ),
        pw.TableRow(
          children: values.map((v) => _c(v, bold, 7, _dark, align: pw.TextAlign.center)).toList(),
        ),
      ],
    );
  }

  // ── Elastic Summary Table ─────────────────────────────────
  // Columns: # | Elastic | Qty(m) | Warp Spandex | Sp.Covering | Sp.Ends | Total Wt
  static pw.Widget _elasticSummaryTable(
      List<CoveringElasticDetail> items, pw.Font bold, pw.Font reg) {
    const cw = {
      0: pw.FixedColumnWidth(10),
      1: pw.FlexColumnWidth(2.2),
      2: pw.FixedColumnWidth(24),
      3: pw.FlexColumnWidth(2.2),
      4: pw.FlexColumnWidth(1.8),
      5: pw.FixedColumnWidth(26),
      6: pw.FixedColumnWidth(28),
      7: pw.FixedColumnWidth(32),   // ← Expected Produce Wt
    };

    final headerCells = ['#', 'ELASTIC', 'QTY\n(m)', 'WARP SPANDEX', 'SP. COVERING', 'SP.\nENDS', 'TOTAL WT\n(g)', 'EXP. PRODUCE\n(kg)'];

    final dataRows = items.asMap().entries.map((entry) {
      final i   = entry.key;
      final ced = entry.value;
      final el  = ced.elastic;
      final ws  = el.warpSpandex;
      final sc  = el.spandexCovering;

      // Warp Spandex: name + ends + weight
      final wsText = ws != null
          ? '${ws.materialName}\n  Wt: ${_wt(ws.weight)} g'
          : '—';

      // Sp. Covering: name + weight
      final scText = sc != null
          ? '${sc.materialName}\nWt: ${_wt(sc.weight)} g'
          : '—';

      // Total weight = warpSpandex.weight + spandexCovering.weight
      final totalWt = (ws?.weight ?? 0.0) + (sc?.weight ?? 0.0);
      final totalWtText = totalWt > 0 ? '${_wt(totalWt)} g' : '—';

      // Expected produce weight = (warpSpandex.weight + spandexCovering.weight) × quantity
      // Expected produce weight = (ws + sc) × qty in grams → ÷1000 → kg
      final expProduceKg = (totalWt * ced.quantity) / 1000;
      final expProduceText = expProduceKg > 0 ? '${_wt(expProduceKg)} kg' : '—';

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isOdd ? _altFill : _white),
        children: [
          _c('${i + 1}', reg, 6, _lite, align: pw.TextAlign.center),
          _c(el.name, bold, 6.5, _dark),
          _c('${ced.quantity}', bold, 7, _dark, align: pw.TextAlign.center),
          _c(wsText, reg, 6, _dark),
          _c(scText, reg, 6, _dark),
          _c('${el.spandexEnds}', bold, 7, _dark, align: pw.TextAlign.center),
          _c(totalWtText, bold, 7, _dark, align: pw.TextAlign.center),
          _c(expProduceText, bold, 7, _dark, align: pw.TextAlign.center),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.35),
      columnWidths: cw,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _hdrFill),
          children: headerCells
              .map((h) => _c(h, bold, 5.8, _dark, align: pw.TextAlign.center))
              .toList(),
        ),
        ...dataRows,
      ],
    );
  }

  // ── Expected Produce Weight summary row ──────────────────
  // Formula per elastic: (warpSpandex.weight + spandexCovering.weight) × quantity
  // Weights in g/m, quantity in meters → total in grams.
  static pw.Widget _expectedWeightRow(
      List<CoveringElasticDetail> items, pw.Font bold, pw.Font reg) {
    double totalGrams = 0;
    for (final ep in items) {
      final ws = ep.elastic.warpSpandex?.weight    ?? 0.0;
      final sc = ep.elastic.spandexCovering?.weight ?? 0.0;
      totalGrams += (ws + sc) * ep.quantity;
    }
    final totalKg  = totalGrams / 1000;
    final totalStr = totalKg > 0 ? '${_wt(totalKg)} kg' : '—';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _bdr, width: 0.35),
          ),
          child: pw.Row(children: [
            pw.Text(
              'EXPECTED PRODUCE WEIGHT:',
              style: pw.TextStyle(
                  font: bold, fontSize: 6.5, color: _mid, letterSpacing: 0.3),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              totalStr,
              style: pw.TextStyle(font: bold, fontSize: 8, color: _dark),
            ),
          ]),
        ),
      ],
    );
  }

  // ── Signature Strip ───────────────────────────────────────
  static pw.Widget _signRow(pw.Font bold, pw.Font reg) {
    const cols = ['Prepared By', 'Checked By', 'Approved By'];
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: cols.map((col) => pw.Column(children: [
        pw.Container(width: 30 * PdfPageFormat.mm, height: 0.6, color: _bdrMed),
        pw.SizedBox(height: 3),
        pw.Text(col, style: pw.TextStyle(font: reg, fontSize: 6, color: _lite)),
      ])).toList(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  static pw.Widget _c(
      String text, pw.Font font, double size, PdfColor color, {
        pw.TextAlign align = pw.TextAlign.left,
        double hpad = 3.5, double vpad = 2.2,
      }) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: hpad, vertical: vpad),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: size, color: color),
            textAlign: align),
      );

  // Integer if whole number, 2 decimal places otherwise
  static String _wt(double w) =>
      w == w.truncateToDouble() ? w.toInt().toString() : w.toStringAsFixed(2);

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
// ══════════════════════════════════════════════════════════════
//  COVERING BEAM LABEL PDF SERVICE  — thermal printer friendly
//  File: lib/src/features/Covering/screens/covering_beam_label_pdf.dart
//
//  Generates a single 2" × 1" label PDF for ONE beam entry.
//  Opened immediately via OpenFile (triggers print dialog on device).
//
//  Label contents:
//    • Job number
//    • Beam number + weight
//    • Warp Spandex  (material name + ends)
//    • Covering Yarn (spandex covering material name)
//    • Spandex Ends
//
//  Thermal-friendly rules:
//    • Pure white background — no fills
//    • Section separators are black rules, not coloured bars
//    • All text black or dark-grey only
//    • Outer border: 1.2pt black
//
//  Usage:
//    await CoveringBeamLabelPdf.generate(
//      entry   : beamEntry,
//      covering: coveringDetail,
//    );
// ══════════════════════════════════════════════════════════════
import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/covering.dart';

class CoveringBeamLabelPdf {
  // ── Page: 2" wide × 1" tall (landscape) ─────────────────
  static const double _w = 2.0 * PdfPageFormat.inch; // 144 pt
  static const double _h = 1.0 * PdfPageFormat.inch; //  72 pt

  // ── Section heights ───────────────────────────────────────
  static const double _headerH = 14.0; // top strip (rule below)
  static const double _footerH = 10.0; // bottom strip (rule above)
  // body = 48 pt (Expanded)

  // ── Left column: beam number ──────────────────────────────
  static const double _beamColW = 30.0;

  // ── Thermal-safe palette ──────────────────────────────────
  static const _black  = PdfColors.black;
  static const _gray   = PdfColor.fromInt(0xFF555555);
  static const _ltgray = PdfColor.fromInt(0xFF888888);

  // ── Border weights ────────────────────────────────────────
  static const double _outerW   = 1.2;
  static const double _headerW  = 1.2;
  static const double _footerW  = 0.6;
  static const double _dividerW = 0.8;

  // ══════════════════════════════════════════════════════════
  //  PUBLIC ENTRY POINT
  // ══════════════════════════════════════════════════════════
  static Future<void> generate({
    required BeamEntry entry,
    required CoveringDetail covering,
  }) async {
    final pdf  = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();

    // Pull elastic data from the first planned elastic (primary)
    final elastic = covering.elasticPlanned.isNotEmpty
        ? covering.elasticPlanned.first.elastic
        : null;

    final warpSpandex    = elastic?.warpSpandex;
    final spandexCovering = elastic?.spandexCovering;
    final spandexEnds    = elastic?.spandexEnds ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_w, _h),
        margin: pw.EdgeInsets.zero,
        theme: pw.ThemeData.withFont(base: reg, bold: bold),
        build: (_) => _buildLabel(
          bold: bold,
          reg: reg,
          jobOrderNo: covering.job.jobOrderNo,
          entry: entry,
          warpSpandexName: warpSpandex?.materialName ?? '—',
          warpSpandexEnds: warpSpandex?.ends ?? 0,
          coveringYarnName: spandexCovering?.materialName ?? '—',
          spandexEnds: spandexEnds,
        ),
      ),
    );

    final dir  = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/covering_beam_label'
          '_J${covering.job.jobOrderNo}'
          '_B${entry.beamNo}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD LABEL
  // ══════════════════════════════════════════════════════════
  static pw.Widget _buildLabel({
    required pw.Font bold,
    required pw.Font reg,
    required int jobOrderNo,
    required BeamEntry entry,
    required String warpSpandexName,
    required int    warpSpandexEnds,
    required String coveringYarnName,
    required int    spandexEnds,
  }) {
    // Weight formatted: trim trailing zeros
    final wtStr = entry.weight == entry.weight.truncateToDouble()
        ? '${entry.weight.toInt()} kg'
        : '${entry.weight.toStringAsFixed(2)} kg';

    return pw.Container(
      // ── Outer border: 1.2pt black ──────────────────────
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _black, width: _outerW),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

          // ════════════════════════════════════════
          //  HEADER — 14 pt
          //  Left : "Job #XXXX"   9pt bold
          //  Right: "COVERING"    5pt ltgray
          //  Separator: 1.2pt black rule below
          // ════════════════════════════════════════
          pw.Container(
            height: _headerH,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _black, width: _headerW),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Job #$jobOrderNo',
                  style: pw.TextStyle(
                    font: bold, fontSize: 9, color: _black,
                    letterSpacing: 0.3,
                  ),
                ),
                pw.Text(
                  'COVERING BEAM',
                  style: pw.TextStyle(
                    font: reg, fontSize: 5, color: _ltgray,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // ════════════════════════════════════════
          //  BODY — 48 pt (Expanded)
          //  Left 30pt  : Beam number column
          //  Divider 0.8pt
          //  Right flex : 2×2 field grid
          // ════════════════════════════════════════
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

                // ── Left: beam number + weight ────
                pw.Container(
                  width: _beamColW,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(
                          color: _black, width: _dividerW),
                    ),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'BEAM',
                        style: pw.TextStyle(
                          font: reg, fontSize: 4.5,
                          color: _ltgray, letterSpacing: 0.6,
                        ),
                      ),
                      pw.SizedBox(height: 0.5),
                      // Big beam digit
                      pw.Text(
                        '${entry.beamNo}',
                        style: pw.TextStyle(
                          font: bold, fontSize: 22, color: _black,
                        ),
                      ),
                      // Weight below digit
                      pw.Text(
                        wtStr,
                        style: pw.TextStyle(
                          font: bold, fontSize: 5.5, color: _gray,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Right: 2×2 field grid ─────────
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(6, 5, 5, 3),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Row 1 — WARP SPANDEX | COVERING YARN
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _field(
                              _trim(warpSpandexName, 14),
                              'WARP SPANDEX',
                              bold, reg,
                            ),
                            _field(
                              _trim(coveringYarnName, 14),
                              'COVERING YARN',
                              bold, reg,
                            ),
                          ],
                        ),
                        // Row 2 — SP. ENDS | WARP SP. ENDS
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _field(
                              '$spandexEnds',
                              'ENDS',
                              bold, reg,
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ════════════════════════════════════════
          //  FOOTER — 10 pt
          //  Beam note if present, else date/time
          //  0.6pt black rule above
          // ════════════════════════════════════════
          pw.Container(
            height: _footerH,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _black, width: _footerW),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 5, vertical: 0),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                entry.note.isNotEmpty
                    ? entry.note
                    : _fmtDate(entry.enteredAt),
                style: pw.TextStyle(
                  font: reg, fontSize: 5, color: _gray,
                ),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── Field cell: label (4.5pt ltgray) + value (8pt bold black) ─
  static pw.Expanded _field(
      String value,
      String label,
      pw.Font bold,
      pw.Font reg,
      ) =>
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: reg, fontSize: 4.5,
                color: _ltgray, letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: bold, fontSize: 8, color: _black,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ],
        ),
      );

  // ── Trim string to max chars ──────────────────────────────
  static String _trim(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 1)}\u2026' : s;

  // ── Format date for footer ────────────────────────────────
  static String _fmtDate(DateTime d) {
    final p = (int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}  ${p(d.hour)}:${p(d.minute)}';
  }
}
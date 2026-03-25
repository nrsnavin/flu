// ══════════════════════════════════════════════════════════════
//  BEAM LABEL PDF SERVICE  — thermal printer friendly
//  File: lib/src/features/Warping/screens/beam_label_pdf.dart
//
//  Thermal-friendly rules applied:
//    • No filled/coloured backgrounds — white page only
//    • Header section marked by thick bottom rule (1.2pt) instead
//      of a black fill
//    • Footer section marked by thick top rule (0.6pt)
//    • Vertical beam-col divider: 0.8pt black
//    • Outer border: 1.2pt black
//    • All text is black or dark-grey — no colour fills
//    • Font sizes unchanged so text stays crisp at low DPI
//
//  Page size : 2" × 1" landscape  (144 pt × 72 pt), zero margin
//  One page per beam, all beams in a single PDF file.
//
//  Layout (top → bottom):
//    ┌─────────────────────────────┐  14 pt  Header (rule below)
//    │  Beam# col  │  Field 2×2   │  48 pt  Body
//    └─────────────────────────────┘  10 pt  Footer (rule above)
//
//  Usage:
//    await BeamLabelPdf.generate(
//      jobOrderNo : plan.jobOrderNo,
//      shade      : w.elastics.first.elasticName,
//      meters     : w.elastics.first.plannedQty,
//      beams      : plan.beams,
//    );
// ══════════════════════════════════════════════════════════════
import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

class BeamLabelPdf {
  // ── Page dimensions (1 inch = 72 pt) ─────────────────────
  static const double _w = 2.0 * PdfPageFormat.inch; // 144 pt
  static const double _h = 1.0 * PdfPageFormat.inch; //  72 pt

  // ── Section heights ───────────────────────────────────────
  static const double _headerH  = 14.0;  // top area
  static const double _footerH  = 10.0;  // bottom area
  // body = 72 - 14 - 10 = 48 pt  (pw.Expanded fills this)

  // ── Left beam-number column width ────────────────────────
  static const double _beamColW = 30.0;

  // ── Thermal-safe palette — black / grey only, no fills ───
  static const _black   = PdfColors.black;
  static const _gray    = PdfColor.fromInt(0xFF555555);  // body sub-labels
  static const _ltgray  = PdfColor.fromInt(0xFF888888);  // BEAM / of N / yarns

  // ── Border weights (match Python thermal version) ─────────
  static const double _outerBorder  = 1.2;  // outer rect
  static const double _headerRule   = 1.2;  // header bottom line
  static const double _footerRule   = 0.6;  // footer top line
  static const double _dividerRule  = 0.8;  // beam-col vertical divider

  // ══════════════════════════════════════════════════════════
  //  PUBLIC ENTRY POINT
  // ══════════════════════════════════════════════════════════
  static Future<void> generate({
    required int    jobOrderNo,
    required String shade,
    required int    meters,
    required List<WarpingBeamDetail> beams,
  }) async {
    final pdf  = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();

    for (final beam in beams) {
      pdf.addPage(
        _buildPage(
          bold: bold,  reg: reg,
          jobOrderNo:  jobOrderNo,
          shade:       shade,
          meters:      meters,
          beam:        beam,
          totalBeams:  beams.length,
        ),
      );
    }

    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/beam_labels_job$jobOrderNo.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD ONE LABEL PAGE
  // ══════════════════════════════════════════════════════════
  static pw.Page _buildPage({
    required pw.Font bold,
    required pw.Font reg,
    required int    jobOrderNo,
    required String shade,
    required int    meters,
    required WarpingBeamDetail beam,
    required int    totalBeams,
  }) {
    // Collect unique yarn names from sections
    final yarns = beam.sections
        .map((s) => s.warpYarnName.trim())
        .where((n) => n.isNotEmpty && n != '—')
        .toSet()
        .join('  ·  ');
    final yarnStr  = yarns.isNotEmpty ? yarns : '—';

    // Trim shade to 14 chars
    final shadeStr = shade.length > 14
        ? '${shade.substring(0, 13)}\u2026'
        : shade;

    return pw.Page(
      pageFormat: PdfPageFormat(_w, _h),
      margin:     pw.EdgeInsets.zero,
      theme:      pw.ThemeData.withFont(base: reg, bold: bold),
      build: (_) => pw.Container(
        // ── Outer border: 1.2pt black (thermal-friendly thick) ──
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _black, width: _outerBorder),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [

            // ══════════════════════════════════════════
            //  HEADER  14 pt
            //  No fill. Separated from body by thick rule.
            //  Left : "Job #XXXX"   9pt bold black
            //  Right: "BEAM LABEL"  5pt ltgray
            // ══════════════════════════════════════════
            pw.Container(
              height: _headerH,
              // Thick bottom rule replaces coloured fill
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: _black, width: _headerRule),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5, vertical: 0),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // "Job #XXXX" — 9pt bold, black
                  pw.Text(
                    'Job #$jobOrderNo',
                    style: pw.TextStyle(
                      font:          bold,
                      fontSize:      9,
                      color:         _black,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // "BEAM LABEL" — 5pt light grey
                  pw.Text(
                    'BEAM LABEL',
                    style: pw.TextStyle(
                      font:          reg,
                      fontSize:      5,
                      color:         _ltgray,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // ══════════════════════════════════════════
            //  BODY  48 pt  (Expanded)
            //  Left 30pt  — beam number column
            //  Divider 0.8pt black
            //  Right flex — 2×2 field grid
            // ══════════════════════════════════════════
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [

                  // ── Beam number column (30pt) ──────────
                  pw.Container(
                    width: _beamColW,
                    // Thick right divider
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(
                            color: _black, width: _dividerRule),
                      ),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // "BEAM" — 4.5pt ltgray
                        pw.Text(
                          'BEAM',
                          style: pw.TextStyle(
                            font:          reg,
                            fontSize:      4.5,
                            color:         _ltgray,
                            letterSpacing: 0.6,
                          ),
                        ),
                        pw.SizedBox(height: 0.5),
                        // Big beam digit — 22pt bold black
                        pw.Text(
                          '${beam.beamNo}',
                          style: pw.TextStyle(
                            font:     bold,
                            fontSize: 22,
                            color:    _black,
                          ),
                        ),
                        // "of N" — 4.5pt gray
                        pw.Text(
                          'of $totalBeams',
                          style: pw.TextStyle(
                            font:     reg,
                            fontSize: 4.5,
                            color:    _gray,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Field grid (flex) ──────────────────
                  // Padding: left 6pt (= field_x - BEAM_COL)
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(6, 5, 5, 3),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Row 1 — SHADE | METER
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _field(shadeStr,     'SHADE', bold, reg),
                              _field('${meters}m', 'METER', bold, reg),
                            ],
                          ),
                          // Row 2 — ENDS | SECTIONS
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _field('${beam.totalEnds}',       'ENDS',     bold, reg),
                              _field('${beam.sections.length}', 'SECTIONS', bold, reg),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ══════════════════════════════════════════
            //  FOOTER  10 pt
            //  No fill. Thick top rule separates from body.
            //  Yarn names — 5pt gray
            // ══════════════════════════════════════════
            pw.Container(
              height: _footerH,
              // Thick top rule replaces grey fill
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                      color: _black, width: _footerRule),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5, vertical: 0),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  yarnStr,
                  style: pw.TextStyle(
                    font:     reg,
                    fontSize: 5,
                    color:    _gray,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  FIELD CELL
  //  label: 4.5pt ltgray (field name)
  //  value: 8pt bold black (field data)
  // ══════════════════════════════════════════════════════════
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
                font:          reg,
                fontSize:      4.5,
                color:         _ltgray,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              value,
              style: pw.TextStyle(
                font:     bold,
                fontSize: 8,
                color:    _black,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ],
        ),
      );
}
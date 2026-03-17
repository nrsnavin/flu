import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

// ══════════════════════════════════════════════════════════════
//  WARPING PLAN PDF
//
//  Design:
//   - A4, minimal, print-safe (no dark fills)
//   - Single flat table: one row per beam section
//   - Combined beams share a merged "Beam" cell with a bracket
//     connector line drawn via CustomPaint
//   - Columns: Beam | Section | Warp Yarn | Ends | Meter
// ══════════════════════════════════════════════════════════════
class WarpingPlanPdfService {
  // Palette — print safe (no solid fills)
  static const _dark    = PdfColor.fromInt(0xFF111111);
  static const _mid     = PdfColor.fromInt(0xFF555555);
  static const _lite    = PdfColor.fromInt(0xFF888888);
  static const _hdr     = PdfColor.fromInt(0xFFDDE3F0); // light blue-grey header
  static const _pair    = PdfColor.fromInt(0xFFE8F5E9); // very light green for paired rows
  static const _bdr     = PdfColor.fromInt(0xFFBBBBBB);
  static const _bdrDark = PdfColor.fromInt(0xFF777777);
  static const _white   = PdfColors.white;
  static const _connCol = PdfColor.fromInt(0xFF2563EB); // connector line colour

  // Column widths (pts)
  static const _wBeam    = 28.0;
  static const _wSec     = 14.0;
  static const _wYarn    = 120.0; // flex remainder
  static const _wEnds    = 28.0;
  static const _wMeter   = 28.0;

  static Future<void> generate({
    required String jobOrderNo,
    required WarpingPlanDetail plan,
    required List<ElasticWarpDetail> elastics,
    required DateTime date,
    required String status,
  }) async {
    final pdf  = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();
    final now  = DateTime.now();

    // Build pair map: beamNo → pairedBeamNo
    final pairMap = <int, int>{};
    for (final b in plan.beams) {
      if (b.pairedBeamNo != null) pairMap[b.beamNo] = b.pairedBeamNo!;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        theme: pw.ThemeData.withFont(base: reg, bold: bold),
        header: (_) => _header(jobOrderNo, date, status, plan, bold, reg),
        footer: (ctx) => _footer(ctx, reg),
        build: (ctx) => [
          pw.SizedBox(height: 6),
          if (elastics.isNotEmpty) ...[
            _elasticSummary(elastics, bold, reg),
            pw.SizedBox(height: 8),
          ],
          _beamTable(plan.beams, pairMap, bold, reg),
          pw.SizedBox(height: 6),
          _totalsBar(plan, bold),
          if ((plan.remarks ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _remarksRow(plan.remarks!, bold, reg),
          ],
        ],
      ),
    );

    final dir  = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/WarpingPlan_J${jobOrderNo}_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // ── Header ───────────────────────────────────────────────
  static pw.Widget _header(
      String jobNo, DateTime date, String status,
      WarpingPlanDetail plan, pw.Font bold, pw.Font reg,
      ) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('WARPING PLAN',
                style: pw.TextStyle(font: bold, fontSize: 13, color: _dark, letterSpacing: 0.6)),
            pw.SizedBox(height: 2),
            pw.Text('Job Order #$jobNo',
                style: pw.TextStyle(font: bold, fontSize: 9, color: _mid)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(_fmt(date),
                style: pw.TextStyle(font: reg, fontSize: 7.5, color: _mid)),
            pw.Text(status.toUpperCase().replaceAll('_', ' '),
                style: pw.TextStyle(font: bold, fontSize: 7, color: _mid, letterSpacing: 0.3)),
            pw.Text('${plan.noOfBeams} Beams  ·  ${plan.totalEnds} Total Ends',
                style: pw.TextStyle(font: reg, fontSize: 7, color: _lite)),
          ]),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Divider(thickness: 0.8, color: _bdrDark),
    ]);
  }

  // ── Footer ───────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, pw.Font reg) {
    return pw.Column(children: [
      pw.Divider(thickness: 0.4, color: _bdr),
      pw.SizedBox(height: 2),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Supreme Stitch ERP',
            style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
      ]),
    ]);
  }

  // ── Elastic summary (compact 1-line each) ────────────────
  static pw.Widget _elasticSummary(
      List<ElasticWarpDetail> elastics, pw.Font bold, pw.Font reg) {
    final colW = const {
      0: pw.FixedColumnWidth(16),
      1: pw.FlexColumnWidth(2.5),
      2: pw.FixedColumnWidth(30),
      3: pw.FlexColumnWidth(3),
    };
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _hdr),
        children: ['#', 'ELASTIC', 'QTY (m)', 'WARP YARNS']
            .map((h) => _cell(h, bold, 6, _mid, center: true))
            .toList(),
      ),
      ...elastics.asMap().entries.map((e) {
        final el  = e.value;
        final odd = e.key.isOdd;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: odd ? const PdfColor.fromInt(0xFFF7F7F7) : _white),
          children: [
            _cell('${e.key + 1}', reg, 6.5, _lite, center: true),
            _cell(el.elasticName, bold, 6.5, _dark),
            _cell('${el.plannedQty}', bold, 7, _dark, center: true),
            _cell(el.warpYarns.map((y) => '${y.name}(${y.ends}e)').join('  '), reg, 6, _dark),
          ],
        );
      }),
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.35),
      columnWidths: colW,
      children: rows,
    );
  }

  // ── Main beam table ──────────────────────────────────────
  // Combined beams are placed on adjacent rows with a left-side
  // bracket drawn via pw.CustomPaint, and their "Beam" cell spans
  // all their section rows.
  static pw.Widget _beamTable(
      List<WarpingBeamDetail> beams,
      Map<int, int> pairMap,
      pw.Font bold,
      pw.Font reg,
      ) {
    // We build a flat list of rows. For a paired group the beam-
    // number cell needs to span multiple rows — pw.Table doesn't
    // support rowspan, so we use a pw.Stack / pw.Column approach:
    // render the table without the beam column, then overlay a
    // separate narrow column on the left for beam labels.

    // Gather groups: list of (beams) where paired beams are in the same group
    final groups = _groupBeams(beams, pairMap);

    return pw.Column(children: [
      // ── Column header row ─────────────────────────────────
      pw.Table(
        border: pw.TableBorder.all(color: _bdrDark, width: 0.6),
        columnWidths: const {
          0: pw.FixedColumnWidth(_wBeam),
          1: pw.FixedColumnWidth(_wSec),
          2: pw.FlexColumnWidth(1),
          3: pw.FixedColumnWidth(_wEnds),
          4: pw.FixedColumnWidth(_wMeter),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _hdr),
            children: [
              _cell('BEAM',  bold, 6, _mid, center: true),
              _cell('SEC',   bold, 6, _mid, center: true),
              _cell('WARP YARN', bold, 6, _mid),
              _cell('ENDS',  bold, 6, _mid, center: true),
              _cell('METER', bold, 6, _mid, center: true),
            ],
          ),
        ],
      ),
      // ── Data rows by group ────────────────────────────────
      ...groups.map((group) => _beamGroupWidget(group, pairMap, bold, reg)),
    ]);
  }

  static pw.Widget _beamGroupWidget(
      List<WarpingBeamDetail> group,
      Map<int, int> pairMap,
      pw.Font bold,
      pw.Font reg,
      ) {
    final isPaired = group.length == 2;

    // Build section rows for each beam in the group
    // Left column: beam label (drawn separately as an overlay)
    final allSectionRows = <_SectionRowData>[];
    for (final beam in group) {
      for (var si = 0; si < beam.sections.length; si++) {
        allSectionRows.add(_SectionRowData(
          beam:         beam,
          section:      beam.sections[si],
          sectionIndex: si,
          isLastInBeam: si == beam.sections.length - 1,
          isPaired:     isPaired,
        ));
      }
    }

    // Build table without beam column
    final tableRows = allSectionRows.asMap().entries.map((e) {
      final row   = e.value;
      final isAlt = e.key.isOdd;
      PdfColor bg = _white;
      if (isPaired) bg = _pair;
      if (isAlt && isPaired) bg = const PdfColor.fromInt(0xFFDDF0DD);

      final mStr = row.section.maxMeters > 0
          ? (row.section.maxMeters == row.section.maxMeters.truncateToDouble()
          ? row.section.maxMeters.toInt().toString()
          : row.section.maxMeters.toStringAsFixed(1))
          : '—';

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          // Beam cell — blank (we draw the label overlay separately)
          pw.Container(
            height: 14,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: row.isLastInBeam ? _bdrDark : _bdr,
                  width: row.isLastInBeam ? 0.8 : 0.3,
                ),
              ),
            ),
          ),
          _cell('${row.sectionIndex + 1}', reg, 6.5, _lite, center: true),
          _cell(_trunc(row.section.warpYarnName, 28), reg, 6.5, _dark),
          _cell('${row.section.ends}', bold, 7, _dark, center: true),
          _cell(mStr, reg, 6.5, row.section.maxMeters > 0 ? _dark : _lite, center: true),
        ],
      );
    }).toList();

    // Compute row heights for beam label overlay
    // Each section row is 14pt high; we compute cumulative offsets per beam
    double beamAHeight = group[0].sections.length * 14.0;
    double beamBHeight = isPaired ? group[1].sections.length * 14.0 : 0;

    return pw.Stack(children: [
      // Data table (full width, beam column is blank)
      pw.Table(
        border: pw.TableBorder(
          left:   const pw.BorderSide(color: _bdrDark, width: 0.6),
          right:  const pw.BorderSide(color: _bdrDark, width: 0.6),
          bottom: const pw.BorderSide(color: _bdrDark, width: 0.6),
          verticalInside: const pw.BorderSide(color: _bdr, width: 0.35),
          horizontalInside: const pw.BorderSide(color: _bdr, width: 0.3),
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(_wBeam),
          1: pw.FixedColumnWidth(_wSec),
          2: pw.FlexColumnWidth(1),
          3: pw.FixedColumnWidth(_wEnds),
          4: pw.FixedColumnWidth(_wMeter),
        },
        children: tableRows,
      ),

      // Beam label column overlay (left side)
      pw.Positioned(
        left: 0,
        top:  0,
        child: pw.SizedBox(
          width: _wBeam,
          child: pw.Column(children: [
            // Beam A label
            _beamLabelCell(
              group[0], beamAHeight, bold, reg,
              isPaired: isPaired, isFirst: true,
              connectorBelow: isPaired,
            ),
            // Beam B label (paired only)
            if (isPaired)
              _beamLabelCell(
                group[1], beamBHeight, bold, reg,
                isPaired: true, isFirst: false,
                connectorAbove: true,
              ),
          ]),
        ),
      ),
    ]);
  }

  // Beam label cell with optional connector bracket
  static pw.Widget _beamLabelCell(
      WarpingBeamDetail beam,
      double height,
      pw.Font bold,
      pw.Font reg, {
        bool isPaired        = false,
        bool isFirst         = true,
        bool connectorBelow  = false,
        bool connectorAbove  = false,
      }) {
    return pw.SizedBox(
      width:  _wBeam,
      height: height,
      child: pw.Stack(children: [
        // Label centred in cell
        pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('B${beam.beamNo}',
                  style: pw.TextStyle(
                      font: bold, fontSize: 7, color: isPaired ? _connCol : _dark)),
              pw.Text('${beam.totalEnds}e',
                  style: pw.TextStyle(font: reg, fontSize: 5.5, color: _lite)),
            ],
          ),
        ),
        // Connector bracket drawn with CustomPaint
        if (isPaired)
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (PdfGraphics canvas, PdfPoint size) {
                const x = 3.0;

                canvas
                  ..setStrokeColor(_connCol)
                  ..setLineWidth(0.9);

                if (connectorBelow) {
                  // Vertical line from 10% to bottom, then small arrowhead
                  canvas
                    ..moveTo(x, size.y * 0.1)
                    ..lineTo(x, size.y)
                    ..strokePath()
                    ..moveTo(x - 2.5, size.y - 4.5)
                    ..lineTo(x, size.y)
                    ..lineTo(x + 2.5, size.y - 4.5)
                    ..strokePath();
                }

                if (connectorAbove) {
                  // Vertical line from top to 90%
                  canvas
                    ..moveTo(x, 0)
                    ..lineTo(x, size.y * 0.9)
                    ..strokePath();
                }
              },
            ),
          ),
      ]),
    );
  }

  // ── Totals bar ───────────────────────────────────────────
  static pw.Widget _totalsBar(WarpingPlanDetail plan, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: _bdrDark, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _hdr),
          children: [
            _cell('TOTAL BEAMS', bold, 6.5, _mid),
            _cell('${plan.noOfBeams}', bold, 9, _dark, center: true),
            _cell('GRAND TOTAL ENDS', bold, 6.5, _mid),
            _cell('${plan.totalEnds}', bold, 9, _dark, center: true),
          ],
        ),
      ],
    );
  }

  // ── Remarks ──────────────────────────────────────────────
  static pw.Widget _remarksRow(String remarks, pw.Font bold, pw.Font reg) {
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.35),
      columnWidths: const {
        0: pw.FixedColumnWidth(36),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            color: const PdfColor.fromInt(0xFFF5F5F5),
            child: pw.Text('REMARKS',
                style: pw.TextStyle(font: bold, fontSize: 6, color: _mid)),
          ),
          _cell(remarks, reg, 6.5, _dark),
        ]),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  static pw.Widget _cell(
      String text, pw.Font font, double size, PdfColor color, {
        bool center = false,
      }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: size, color: color),
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        ),
      );

  static String _trunc(String s, [int n = 28]) =>
      s.length <= n ? s : '${s.substring(0, n - 1)}…';

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Group beams: paired beams (same pairedBeamNo) go together.
  /// Unpaired beams are solo groups.
  static List<List<WarpingBeamDetail>> _groupBeams(
      List<WarpingBeamDetail> beams,
      Map<int, int> pairMap,
      ) {
    final result   = <List<WarpingBeamDetail>>[];
    final consumed = <int>{};

    for (final beam in beams) {
      if (consumed.contains(beam.beamNo)) continue;
      final paired = pairMap[beam.beamNo];
      if (paired != null) {
        final partner = beams.firstWhere(
              (b) => b.beamNo == paired,
          orElse: () => beam,
        );
        if (partner.beamNo != beam.beamNo && !consumed.contains(paired)) {
          result.add([beam, partner]);
          consumed.add(beam.beamNo);
          consumed.add(paired);
          continue;
        }
      }
      result.add([beam]);
      consumed.add(beam.beamNo);
    }
    return result;
  }
}

// Helper data class for section row rendering
class _SectionRowData {
  final WarpingBeamDetail beam;
  final WarpingBeamSectionDetail section;
  final int sectionIndex;
  final bool isLastInBeam;
  final bool isPaired;
  _SectionRowData({
    required this.beam,
    required this.section,
    required this.sectionIndex,
    required this.isLastInBeam,
    required this.isPaired,
  });
}
// ══════════════════════════════════════════════════════════════
//  COVERING BEAM LABEL PDF SERVICE  — thermal printer friendly
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
//    • Footer: date + "By <operator>" when known
// ══════════════════════════════════════════════════════════════
import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/covering.dart';

class CoveringBeamLabelPdf {
  static const double _w = 2.0 * PdfPageFormat.inch;
  static const double _h = 1.0 * PdfPageFormat.inch;

  static const double _headerH = 14.0;
  static const double _footerH = 12.0;

  static const double _beamColW = 30.0;

  static const _black  = PdfColors.black;
  static const _gray   = PdfColor.fromInt(0xFF555555);
  static const _ltgray = PdfColor.fromInt(0xFF888888);

  static const double _outerW   = 1.2;
  static const double _headerW  = 1.2;
  static const double _footerW  = 0.6;
  static const double _dividerW = 0.8;

  static Future<void> generate({
    required BeamEntry entry,
    required CoveringDetail covering,
  }) async {
    final pdf  = pw.Document();
    final bold = pw.Font.helveticaBold();
    final reg  = pw.Font.helvetica();

    final elastic = covering.elasticPlanned.isNotEmpty
        ? covering.elasticPlanned.first.elastic
        : null;

    final warpSpandex     = elastic?.warpSpandex;
    final spandexCovering = elastic?.spandexCovering;
    final spandexEnds     = elastic?.spandexEnds ?? 0;

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
    final wtStr = entry.weight == entry.weight.truncateToDouble()
        ? '${entry.weight.toInt()} kg'
        : '${entry.weight.toStringAsFixed(2)} kg';

    // Footer: prefer note (operator's freeform observation); otherwise
    // show the entry timestamp plus "By <name>" when the audit field
    // is populated. Both lines are squeezed into the 12pt strip.
    final dateLine = _fmtDate(entry.enteredAt);
    final byLine   = (entry.enteredByName != null &&
                      entry.enteredByName!.trim().isNotEmpty)
        ? 'By ${entry.enteredByName}'
        : null;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _black, width: _outerW),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

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

          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

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
                      pw.Text(
                        '${entry.beamNo}',
                        style: pw.TextStyle(
                          font: bold, fontSize: 22, color: _black,
                        ),
                      ),
                      pw.Text(
                        wtStr,
                        style: pw.TextStyle(
                          font: bold, fontSize: 5.5, color: _gray,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(6, 5, 5, 3),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
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
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _field(
                              '$spandexEnds',
                              'SP. ENDS',
                              bold, reg,
                            ),
                            _field(
                              '$warpSpandexEnds',
                              'WARP ENDS',
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

          // Footer: date and operator ("By <name>") on one line.
          pw.Container(
            height: _footerH,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _black, width: _footerW),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 5, vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  dateLine,
                  style: pw.TextStyle(
                    font: reg, fontSize: 5, color: _gray,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                if (byLine != null)
                  pw.Text(
                    _trim(byLine, 18),
                    style: pw.TextStyle(
                      font: bold, fontSize: 5, color: _black,
                    ),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  static String _trim(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 1)}…' : s;

  static String _fmtDate(DateTime d) {
    final p = (int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}  ${p(d.hour)}:${p(d.minute)}';
  }
}

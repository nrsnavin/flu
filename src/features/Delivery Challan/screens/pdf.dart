import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/dc_model.dart';

// ══════════════════════════════════════════════════════════════
//  DELIVERY CHALLAN PDF  —  Minimal bordered-table layout
//  Columns: S.No | Description | Unit | Quantity  (no Rate/Amount)
// ══════════════════════════════════════════════════════════════

class DCPdfService {
  // ── Company ────────────────────────────────────────────────
  static const _co       = 'ANU TAPES';
  static const _coTag    = 'Elastic & Tape Manufacturers';
  static const _coAddr   = 'Plot No. 47/A, Thiru Nagar, Tiruppur Bypass Road\nTiruppur – 641 604, Tamil Nadu';
  static const _coPhone  = '+91 98765 43210';
  static const _coEmail  = 'anutapes@gmail.com';
  static const _coGstin  = '33AAAAA0000A1Z5';
  static const _coState  = 'Tamil Nadu  |  State Code: 33';

  // ── Palette ────────────────────────────────────────────────
  static const _navy     = PdfColor.fromInt(0xFF0D1B2A);
  static const _blue     = PdfColor.fromInt(0xFF1D6FEB);
  static const _bgRow    = PdfColor.fromInt(0xFFF1F4FA);   // grey section headers
  static const _bdr      = PdfColor.fromInt(0xFF000000);   // solid black borders
  static const _bdrSoft  = PdfColor.fromInt(0xFFCDD5E3);
  static const _tPri     = PdfColor.fromInt(0xFF0D1B2A);
  static const _tSec     = PdfColor.fromInt(0xFF5A6A85);
  static const _tMut     = PdfColor.fromInt(0xFF94A3B8);
  static const _white    = PdfColors.white;

  static final _dtFmt  = DateFormat('dd-MM-yyyy');
  static final _numFmt = NumberFormat('#,##,###.##');

  // ══════════════════════════════════════════════════════════
  //  ENTRY POINT
  // ══════════════════════════════════════════════════════════
  static Future<Uint8List> generate(DCDetail dc) async {
    final doc = pw.Document(title: dc.dcNumber, author: _co);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
      header: (ctx) => _header(dc),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        _infoTable(dc),
        pw.SizedBox(height: 8),
        _itemsTable(dc),
        pw.SizedBox(height: 8),
        _totalsRow(dc),
        pw.SizedBox(height: 8),
        _declaration(),
        pw.SizedBox(height: 14),
        _signatures(),
      ],
    ));

    return doc.save();
  }

  // ══════════════════════════════════════════════════════════
  //  1. HEADER  — 3-column bordered table
  //     [Company info] | [DELIVERY CHALLAN title] | [DC meta]
  // ══════════════════════════════════════════════════════════
  static pw.Widget _header(DCDetail dc) {
    String date = dc.dispatchDate;
    try { date = _dtFmt.format(DateTime.parse(dc.dispatchDate)); } catch (_) {}

    final title = dc.isElastic ? 'DELIVERY CHALLAN' : 'SERVICE CHALLAN';

    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.7),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [

          // ── Company ────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_co,
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold,
                        color: _navy)),
                pw.SizedBox(height: 2),
                pw.Text(_coTag,
                    style: pw.TextStyle(fontSize: 7.5, color: _tSec)),
                pw.SizedBox(height: 7),
                pw.Text(_coAddr,
                    style: pw.TextStyle(fontSize: 7.5, color: _tPri, lineSpacing: 1.4)),
                pw.SizedBox(height: 5),
                _coRow('Ph',    _coPhone),
                _coRow('Email', _coEmail),
                _coRow('GSTIN', _coGstin),
                _coRow('State', _coState),
              ],
            ),
          ),

          // ── Centre title (dark bg) ─────────────────────────
          pw.Container(
            color: _navy,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(title,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold,
                        color: _white, letterSpacing: 0.6)),
                pw.SizedBox(height: 6),
                pw.Text('(Not a Tax Invoice)',
                    style: pw.TextStyle(fontSize: 7,
                        color: PdfColor.fromInt(0xFF8BAAC8))),
              ],
            ),
          ),

          // ── DC meta ────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _mRow('DC No',  dc.dcNumber, bold: true),
                _mRow('Date',   date),
                _mRow('FY',     dc.financialYear),
                if (dc.orderNo != null)
                  _mRow('Order No', '#${dc.orderNo}'),
                _mRow('Status', dc.status.toUpperCase()),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  2. INFO TABLE  — Consignee (left) | Transport (right)
  // ══════════════════════════════════════════════════════════
  static pw.Widget _infoTable(DCDetail dc) {
    String date = dc.dispatchDate;
    try { date = _dtFmt.format(DateTime.parse(dc.dispatchDate)); } catch (_) {}

    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.7),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        // Label row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgRow),
          children: [
            _secLabel('CONSIGNEE DETAILS'),
            _secLabel('TRANSPORT / DISPATCH DETAILS'),
          ],
        ),
        // Data row
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(9),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(dc.customerName,
                    style: pw.TextStyle(fontSize: 10,
                        fontWeight: pw.FontWeight.bold, color: _tPri)),
                pw.SizedBox(height: 5),
                if (dc.customerAddress.isNotEmpty)
                  _iRow('Address', dc.customerAddress),
                if (dc.customerPhone.isNotEmpty)
                  _iRow('Phone',   dc.customerPhone),
                if (dc.customerGstin.isNotEmpty)
                  _iRow('GSTIN',   dc.customerGstin),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(9),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _iRow('Dispatch Date', date),
                if (dc.vehicleNo.isNotEmpty)
                  _iRow('Vehicle No',  dc.vehicleNo),
                if (dc.driverName.isNotEmpty)
                  _iRow('Driver',      dc.driverName),
                if (dc.transporter.isNotEmpty)
                  _iRow('Transporter', dc.transporter),
                if (dc.lrNumber.isNotEmpty)
                  _iRow('LR / GR No',  dc.lrNumber),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  3. ITEMS TABLE  — S.No | Description | Unit | Qty
  // ══════════════════════════════════════════════════════════
  static pw.Widget _itemsTable(DCDetail dc) {
    const minEmpty = 8; // minimum visible rows
    final rowCount = dc.items.length < minEmpty ? minEmpty : dc.items.length;

    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.7),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),  // S.No
        1: const pw.FlexColumnWidth(5),    // Description
        2: const pw.FixedColumnWidth(48),  // Unit
        3: const pw.FixedColumnWidth(80),  // Qty
      },
      children: [
        // ── Header ──────────────────────────────────────────
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgRow),
          children: [
            _th('S.No',       pw.TextAlign.center),
            _th('DESCRIPTION OF GOODS'),
            _th('UNIT',       pw.TextAlign.center),
            _th('QUANTITY',   pw.TextAlign.center),
          ],
        ),
        // ── Rows ────────────────────────────────────────────
        ...List.generate(rowCount, (i) {
          if (i < dc.items.length) {
            final item = dc.items[i];
            return pw.TableRow(children: [
              _td((i + 1).toString(), pw.TextAlign.center, muted: true),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(item.displayName,
                    style: pw.TextStyle(fontSize: 9, color: _tPri)),
              ),
              _td(item.unit, pw.TextAlign.center),
              _td(_numFmt.format(item.quantity), pw.TextAlign.center, bold: true),
            ]);
          }
          // Empty row
          return pw.TableRow(children: [
            _emptyCell(), _emptyCell(), _emptyCell(), _emptyCell(),
          ]);
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  4. TOTALS ROW  — remarks (left) | total qty (right)
  // ══════════════════════════════════════════════════════════
  static pw.Widget _totalsRow(DCDetail dc) {
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.7),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(140),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgRow),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(9),
              child: dc.remarks.isNotEmpty
                  ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('REMARKS',
                      style: pw.TextStyle(fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _tMut, letterSpacing: 0.4)),
                  pw.SizedBox(height: 4),
                  pw.Text(dc.remarks,
                      style: pw.TextStyle(fontSize: 8.5, color: _tSec)),
                ],
              )
                  : pw.SizedBox(height: 10),
            ),
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('TOTAL QTY',
                      style: pw.TextStyle(fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _tMut, letterSpacing: 0.4)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_numFmt.format(dc.totalQuantity)}${dc.isElastic ? " m" : ""}',
                    style: pw.TextStyle(fontSize: 13,
                        fontWeight: pw.FontWeight.bold, color: _navy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  5. DECLARATION
  // ══════════════════════════════════════════════════════════
  static pw.Widget _declaration() {
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.7),
      children: [
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(9),
            child: pw.Text(
              'DECLARATION: Certified that the particulars given above are true and correct. '
                  'Goods dispatched are as per order. This document is not a tax invoice. '
                  'Goods once despatched will not be taken back without prior approval.',
              style: pw.TextStyle(fontSize: 7.5, color: _tSec, lineSpacing: 1.5),
            ),
          ),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  6. SIGNATURES
  // ══════════════════════════════════════════════════════════
  static pw.Widget _signatures() {
    return pw.Table(
      border: pw.TableBorder.all(color: _bdr, width: 0.7),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        // Label row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgRow),
          children: [
            _secLabel("RECEIVER'S SIGNATURE & STAMP"),
            _secLabel('FOR $_co'),
          ],
        ),
        // Signature space
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 40, 12, 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(height: 0.5, color: _bdrSoft),
                pw.SizedBox(height: 5),
                pw.Text('Name: ______________________________',
                    style: pw.TextStyle(fontSize: 7.5, color: _tMut)),
                pw.SizedBox(height: 4),
                pw.Text('Date:  ______________________________',
                    style: pw.TextStyle(fontSize: 7.5, color: _tMut)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 40, 12, 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(height: 0.5, color: _bdrSoft),
                pw.SizedBox(height: 5),
                pw.Text('Authorised Signatory',
                    style: pw.TextStyle(fontSize: 7.5, color: _tMut)),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PAGE FOOTER
  // ══════════════════════════════════════════════════════════
  static pw.Widget _footer(pw.Context ctx) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$_co  ·  GSTIN: $_coGstin  ·  $_coPhone',
              style: pw.TextStyle(fontSize: 7, color: _tMut)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _tMut)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════

  static pw.Widget _coRow(String lbl, String val) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(children: [
      pw.SizedBox(width: 34,
          child: pw.Text(lbl, style: pw.TextStyle(fontSize: 7.5,
              fontWeight: pw.FontWeight.bold, color: _tMut))),
      pw.Text(': ', style: pw.TextStyle(fontSize: 7.5, color: _tMut)),
      pw.Expanded(child: pw.Text(val,
          style: pw.TextStyle(fontSize: 7.5, color: _tSec))),
    ]),
  );

  static pw.Widget _mRow(String lbl, String val, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(lbl, style: pw.TextStyle(fontSize: 8, color: _tSec)),
        pw.Text(val, style: pw.TextStyle(
            fontSize: bold ? 9.5 : 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? _navy : _tSec)),
      ],
    ),
  );

  static pw.Widget _iRow(String lbl, String val) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 72,
          child: pw.Text(lbl, style: pw.TextStyle(fontSize: 8,
              fontWeight: pw.FontWeight.bold, color: _tMut))),
      pw.Text(': ', style: pw.TextStyle(fontSize: 8, color: _tMut)),
      pw.Expanded(child: pw.Text(val,
          style: pw.TextStyle(fontSize: 8, color: _tPri))),
    ]),
  );

  // Section label cell (grey header row)
  static pw.Widget _secLabel(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8,
        fontWeight: pw.FontWeight.bold, color: _tSec, letterSpacing: 0.3)),
  );

  // Table column header
  static pw.Widget _th(String text,
      [pw.TextAlign align = pw.TextAlign.left]) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                color: _tSec, letterSpacing: 0.3)),
      );

  // Table data cell
  static pw.Widget _td(String text, pw.TextAlign align,
      {bool bold = false, bool muted = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: muted ? _tMut : _tPri)),
      );

  // Empty row cell (keeps row height)
  static pw.Widget _emptyCell() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Text(' ', style: pw.TextStyle(fontSize: 9)),
  );
}
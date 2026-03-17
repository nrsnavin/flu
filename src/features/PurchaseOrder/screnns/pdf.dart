import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/po_models.dart';

// ══════════════════════════════════════════════════════════════
//  PO PDF Service
//  Generates a professional A4 Purchase Order PDF.
//  Call: final bytes = await POPdfService.generate(po, inwardHistory);
// ══════════════════════════════════════════════════════════════

class POPdfService {
  // ── Palette (mirrored from ErpColors) ─────────────────────
  static const _navyDark   = PdfColor.fromInt(0xFF0D1B2A);
  static const _navyMid    = PdfColor.fromInt(0xFF1B2B45);
  static const _accent     = PdfColor.fromInt(0xFF1D6FEB);
  static const _bgMuted    = PdfColor.fromInt(0xFFF1F4FA);
  static const _border     = PdfColor.fromInt(0xFFDDE3EE);
  static const _textPri    = PdfColor.fromInt(0xFF0D1B2A);
  static const _textSec    = PdfColor.fromInt(0xFF5A6A85);
  static const _textMuted  = PdfColor.fromInt(0xFF94A3B8);
  static const _green      = PdfColor.fromInt(0xFF16A34A);
  static const _amber      = PdfColor.fromInt(0xFFD97706);
  static const _red        = PdfColor.fromInt(0xFFDC2626);
  static const _white      = PdfColors.white;

  // ── Number formatters ──────────────────────────────────────
  static final _moneyFmt = NumberFormat('#,##,###.##');
  static final _qtyFmt   = NumberFormat('#,##,###.##');
  static final _dateFmt  = DateFormat('dd MMM yyyy');

  // ── Entry point ────────────────────────────────────────────
  static Future<Uint8List> generate(
      POModel po,
      List<InwardRecord> inwardHistory,
      ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) => [
          _header(po),
          pw.SizedBox(height: 20),
          _infoRow(po),
          pw.SizedBox(height: 20),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: _itemsSection(po),
          ),
          pw.SizedBox(height: 16),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: _totalsBlock(po),
          ),
          if (inwardHistory.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 36),
              child: _inwardSection(inwardHistory),
            ),
          ],
          pw.SizedBox(height: 28),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: _footer(),
          ),
          pw.SizedBox(height: 20),
        ],
      ),
    );

    return doc.save();
  }

  // ── PAGE HEADER ────────────────────────────────────────────
  static pw.Widget _header(POModel po) {
    final statusColor = _statusColor(po.status);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
      decoration: const pw.BoxDecoration(
        color: _navyDark,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: title + subtitle
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PURCHASE ORDER',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent,
                    letterSpacing: 2.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'PO #${po.poNo}',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _dateFmt.format(po.date),
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColor.fromInt(0xFFB0C4E0),
                  ),
                ),
              ],
            ),
          ),
          // Right: status badge
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),

                child: pw.Text(
                  po.status.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                '${po.items.length} Line Items',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFFB0C4E0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── INFO ROW: PO details + Supplier ───────────────────────
  static pw.Widget _infoRow(POModel po) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 36),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // PO Details box
          pw.Expanded(
            child: _infoBox(
              title: 'PO DETAILS',
              rows: [
                _InfoRow('PO Number', '#${po.poNo}', bold: true),
                _InfoRow('Date', _dateFmt.format(po.date)),
                _InfoRow('Status', po.status,
                    valueColor: _statusColor(po.status)),
                _InfoRow('Total Items', '${po.items.length} items'),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Supplier box
          pw.Expanded(
            child: _infoBox(
              title: 'SUPPLIER',
              rows: [
                _InfoRow(
                    'Name', po.supplier?.name ?? '—', bold: true),
                if (po.supplier?.phone != null)
                  _InfoRow('Phone', po.supplier!.phone!),
                if (po.supplier?.gstin != null)
                  _InfoRow('GSTIN', po.supplier!.gstin!),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Financial summary box
          pw.Expanded(
            child: _infoBox(
              title: 'FINANCIALS',
              accentColor: _accent,
              rows: [
                _InfoRow(
                  'Order Value',
                  '₹${_moneyFmt.format(po.totalOrderValue)}',
                  bold: true,
                  valueColor: _textPri,
                ),
                _InfoRow(
                  'Received',
                  '₹${_moneyFmt.format(po.totalOrderValue - po.totalPendingValue)}',
                  valueColor: _green,
                ),
                _InfoRow(
                  'Pending',
                  '₹${_moneyFmt.format(po.totalPendingValue)}',
                  valueColor: po.totalPendingValue > 0 ? _amber : _green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ITEMS TABLE ────────────────────────────────────────────
  static pw.Widget _itemsSection(POModel po) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('LINE ITEMS'),
        pw.SizedBox(height: 8),
        pw.Table(

          columnWidths: {
            0: const pw.FixedColumnWidth(28),   // #
            1: const pw.FlexColumnWidth(3),      // Material
            2: const pw.FlexColumnWidth(1.2),    // Price
            3: const pw.FlexColumnWidth(1.2),    // Ordered
            4: const pw.FlexColumnWidth(1.2),    // Received
            5: const pw.FlexColumnWidth(1.2),    // Pending
            6: const pw.FlexColumnWidth(1.4),    // Total
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _navyMid),
              children: [
                _th('#'),
                _th('MATERIAL'),
                _th('PRICE/UNIT', align: pw.TextAlign.right),
                _th('ORDERED', align: pw.TextAlign.right),
                _th('RECEIVED', align: pw.TextAlign.right),
                _th('PENDING', align: pw.TextAlign.right),
                _th('TOTAL', align: pw.TextAlign.right),
              ],
            ),
            // Data rows
            ...po.items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isAlt = i % 2 == 1;
              final pendingColor = item.pendingQuantity > 0
                  ? _amber
                  : _green;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isAlt
                      ? PdfColor.fromInt(0xFFF8FAFD)
                      : PdfColors.white,
                ),
                children: [
                  _td(
                    '${i + 1}',
                    align: pw.TextAlign.center,
                    color: _textMuted,
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.rawMaterial?.name ?? '—',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _textPri,
                          ),
                        ),
                        if (item.rawMaterial?.unit != null)
                          pw.Text(
                            item.rawMaterial!.unit!,
                            style: pw.TextStyle(
                                fontSize: 8, color: _textMuted),
                          ),
                      ],
                    ),
                  ),
                  _td('₹${_qtyFmt.format(item.price)}',
                      align: pw.TextAlign.right),
                  _td('${_qtyFmt.format(item.quantity)} kg',
                      align: pw.TextAlign.right),
                  _td(
                    '${_qtyFmt.format(item.receivedQuantity)} kg',
                    align: pw.TextAlign.right,
                    color: item.receivedQuantity > 0 ? _green : _textMuted,
                  ),
                  _td(
                    '${_qtyFmt.format(item.pendingQuantity)} kg',
                    align: pw.TextAlign.right,
                    color: pendingColor,
                    bold: item.pendingQuantity > 0,
                  ),
                  _td(
                    '₹${_moneyFmt.format(item.totalValue)}',
                    align: pw.TextAlign.right,
                    bold: true,
                    color: _textPri,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── TOTALS BLOCK ───────────────────────────────────────────
  static pw.Widget _totalsBlock(POModel po) {
    final received =
        po.totalOrderValue - po.totalPendingValue;
    final pct = po.totalOrderValue > 0
        ? (received / po.totalOrderValue * 100).toStringAsFixed(0)
        : '0';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 240,

          child: pw.Column(
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),

                child: pw.Text(
                  'ORDER SUMMARY',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _textSec,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // Rows
              _summaryRow('Order Value',
                  '₹${_moneyFmt.format(po.totalOrderValue)}'),
              _summaryRow(
                  'Received ($pct%)',
                  '₹${_moneyFmt.format(received)}',
                  valueColor: _green),
              _summaryRow(
                  'Pending',
                  '₹${_moneyFmt.format(po.totalPendingValue)}',
                  valueColor:
                  po.totalPendingValue > 0 ? _amber : _green),
              // Grand total divider row
              pw.Container(
                width: double.infinity,
                height: 0.5,
                color: _border,
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                child: pw.Row(
                  mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _textPri,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.Text(
                      '₹${_moneyFmt.format(po.totalOrderValue)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── INWARD HISTORY TABLE ───────────────────────────────────
  static pw.Widget _inwardSection(List<InwardRecord> history) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('INWARD HISTORY'),
        pw.SizedBox(height: 8),
        pw.Table(

          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _navyMid),
              children: [
                _th('#'),
                _th('MATERIAL'),
                _th('QUANTITY', align: pw.TextAlign.right),
                _th('DATE'),
                _th('REMARKS'),
              ],
            ),
            ...history.asMap().entries.map((e) {
              final i = e.key;
              final rec = e.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i % 2 == 1
                      ? PdfColor.fromInt(0xFFF8FAFD)
                      : PdfColors.white,
                ),
                children: [
                  _td('${i + 1}',
                      align: pw.TextAlign.center,
                      color: _textMuted),
                  _td(rec.rawMaterial?.name ?? '—'),
                  _td(
                    '${_qtyFmt.format(rec.quantity)} kg',
                    align: pw.TextAlign.right,
                    color: _green,
                    bold: true,
                  ),
                  _td(_dateFmt.format(rec.inwardDate),
                      color: _textSec),
                  _td(rec.remarks?.isNotEmpty == true
                      ? rec.remarks!
                      : '—', color: _textMuted),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── FOOTER ─────────────────────────────────────────────────
  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),

      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${_dateFmt.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: _textMuted),
          ),
          pw.Text(
            'This is a system-generated document.',
            style: pw.TextStyle(fontSize: 8, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // ── SHARED HELPERS ─────────────────────────────────────────

  static pw.Widget _infoBox({
    required String title,
    required List<_InfoRow> rows,
    PdfColor accentColor = _accent,
  }) {
    return pw.Container(

      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),

            child: pw.Row(
              children: [
                pw.Container(
                    width: 2,
                    height: 10,
                    color: accentColor,
                    margin:
                    const pw.EdgeInsets.only(right: 6)),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _textSec,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows.map((r) => _infoCell(r)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoCell(_InfoRow row) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              row.label,
              style: pw.TextStyle(fontSize: 8, color: _textMuted),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              row.value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: row.bold ? pw.FontWeight.bold : null,
                color: row.valueColor ?? _textPri,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionLabel(String text) {
    return pw.Row(
      children: [
        pw.Container(
            width: 3,
            height: 12,
            color: _accent,
            margin: const pw.EdgeInsets.only(right: 8)),
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _textSec,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
            child: pw.Divider(thickness: 0.5, color: _border)),
      ],
    );
  }

  // Table header cell
  static pw.Widget _th(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFFB0C4E0),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // Table data cell
  static pw.Widget _td(
      String text, {
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor? color,
        bool bold = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? _textPri,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
      String label,
      String value, {
        PdfColor? valueColor,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 14, vertical: 6),

      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: _textSec)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? _textPri,
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _statusColor(String status) {
    switch (status) {
      case 'Open':
        return const PdfColor.fromInt(0xFF1D6FEB);
      case 'Partial':
        return const PdfColor.fromInt(0xFFD97706);
      case 'Completed':
        return const PdfColor.fromInt(0xFF16A34A);
      default:
        return const PdfColor.fromInt(0xFF94A3B8);
    }
  }
}

// ── Internal data class ────────────────────────────────────────
class _InfoRow {
  final String label;
  final String value;
  final bool bold;
  final PdfColor? valueColor;

  const _InfoRow(this.label, this.value,
      {this.bold = false, this.valueColor});
}
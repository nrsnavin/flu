import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PackingSlipPdf {
  static Future<void> generate({
    required String packingId,
    required String elasticName,
    required String customerName,
    required String po,
    required String jobOrderNo,
    required int joints,
    required String checkedBy,
    required String packedBy,
    required double meters,
    required String stretch,
    required double netWeight,
    required double tareWeight,
    required double grossWeight,
    String? size,
    DateTime? date,
  }) async {
    final pdf = pw.Document();

    final pageFormat =
    PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch);

    final serialNo =
        'PKG-$jobOrderNo-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final dateStr =
    DateFormat('dd-MMM-yyyy').format(date ?? DateTime.now());

    final qrData = jsonEncode({
      'jobOrderNo': jobOrderNo,
      'packingId': packingId,
      'serial': serialNo,
      'meters': meters,
      'date': dateStr,
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => [
          _buildHeader(serialNo, dateStr),
          pw.SizedBox(height: 5),
          _buildOrderTable(dateStr, customerName, po, jobOrderNo),
          pw.SizedBox(height: 5),
          _elasticBanner(elasticName),
          pw.SizedBox(height: 5),
          _buildProductionTable(meters, joints, stretch, size),
          pw.SizedBox(height: 5),
          _buildWeightTable(netWeight, tareWeight, grossWeight),
          pw.SizedBox(height: 5),
          _buildQCTable(checkedBy, packedBy),
          pw.SizedBox(height: 8),
          _buildSignatureRow(),
          pw.SizedBox(height: 8),
          _buildQR(qrData, serialNo),
          pw.SizedBox(height: 5),
          _buildFooter(),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Packing_$jobOrderNo.pdf');

    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // HEADER
  static pw.Widget _buildHeader(String serialNo, String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      color: PdfColors.blueGrey800,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'ANU TAPES',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PACKING SLIP',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                serialNo,
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ORDER TABLE
  static pw.Widget _buildOrderTable(
      String date,
      String customer,
      String po,
      String jobOrder) {
    return _table([
      _row('Date', date),
      _row('Customer', customer),
      _row('PO No.', po),
      _row('Job Order', jobOrder),
    ]);
  }

  // ELASTIC NAME BANNER
  static pw.Widget _elasticBanner(String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      color: PdfColors.blueGrey50,
      child: pw.Center(
        child: pw.Text(
          name,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      ),
    );
  }

  // PRODUCTION TABLE
  static pw.Widget _buildProductionTable(
      double meters,
      int joints,
      String stretch,
      String? size) {
    final rows = [
      _row('Meters', '${meters.toStringAsFixed(2)} m'),
      _row('Joints', joints.toString()),
      _row('Stretch', stretch.isNotEmpty ? '$stretch%' : '-'),
    ];

    if (size != null && size.isNotEmpty) {
      rows.add(_row('Size', size));
    }

    return _table(rows);
  }

  // WEIGHT TABLE
  static pw.Widget _buildWeightTable(
      double net,
      double tare,
      double gross) {
    return _table([
      _row('Net Weight', '${net.toStringAsFixed(3)} kg'),
      _row('Tare Weight', '${tare.toStringAsFixed(3)} kg'),
      _row('Gross Weight', '${gross.toStringAsFixed(3)} kg'),
    ]);
  }

  // QC TABLE
  static pw.Widget _buildQCTable(
      String checkedBy,
      String packedBy) {
    return _table([
      _row('Checked By', checkedBy),
      _row('Packed By', packedBy),
    ]);
  }

  // SIGNATURE SECTION
  static pw.Widget _buildSignatureRow() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signatureBox('Checker Signature'),
        pw.SizedBox(width: 8),
        _signatureBox('Supervisor Signature'),
      ],
    );
  }

  // QR SECTION
  static pw.Widget _buildQR(String qrData, String serialNo) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: 60,
            height: 60,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Scan to verify - $serialNo',
            style: const pw.TextStyle(
              fontSize: 6,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // FOOTER
  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'ANU TAPES | Quality Elastic Manufacturer',
        style: const pw.TextStyle(
          fontSize: 6,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  // TABLE GENERATOR
  static pw.Widget _table(List<pw.TableRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(1.8),
      },
      children: rows,
    );
  }

  static pw.TableRow _row(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.blueGrey900,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureBox(String label) {
    return pw.Expanded(
      child: pw.Container(
        height: 30,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
        ),
        child: pw.Align(
          alignment: pw.Alignment.bottomCenter,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
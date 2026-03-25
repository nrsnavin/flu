import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';


import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_plan_detail_controller.dart';

class ShiftPlanSummaryPdf extends StatelessWidget {
  final controller = Get.find<ShiftPlanDetailController>();

  ShiftPlanSummaryPdf({super.key});

  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final shift = controller.shiftDetail.value;

    if (shift == null) return;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Supervisor Signature: ________________________',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        build: (context) => [
          // ── HEADER ──────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ANU TAPES',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Shift Plan Summary Report',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(shift.date)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Shift: ${shift.shift}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),
          pw.Divider(),

          // ── SHIFT SUMMARY ────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey200,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Machines: ${shift.machines.length}',
                    style: pw.TextStyle(fontSize: 10)),
                pw.Text('Operators: ${shift.machines.length}',
                    style: pw.TextStyle(fontSize: 10)),
                pw.Text(
                  'Total Production: ${shift.totalProduction} mtrs',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 15),

          // ── MACHINE TABLE ────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(0.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _header("Machine"),
                  _header("Job Order"),
                  _header("Operator"),
                  _header("Production"),
                  _header("Run Time"),
                  _header("Status"),
                ],
              ),
              ...shift.machines.map((m) {
                final bool lowProd = m.production < 500;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: lowProd ? PdfColors.red100 : PdfColors.white,
                  ),
                  children: [
                    _cell(m.machineName),
                    _cell("Job #${m.jobOrderNo}"),
                    _cell(m.operatorName),
                    _cell("${m.production} m", align: pw.TextAlign.right),
                    _cell(m.timer),
                    _cell(m.status.toUpperCase(), align: pw.TextAlign.center),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── PERFORMANCE ──────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              "Production Efficiency Snapshot:\n"
                  "- Shift Utilization: ${(shift.totalProduction / (shift.machines.length * 1000) * 100).toStringAsFixed(1)}%\n"
                  "- Machines Running: ${shift.machines.length}\n"
                  "- Operators Engaged: ${shift.machines.length}",
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );

    // BUG FIX: Declare directory inside the method properly (was declared before pdf init before)
    final Directory? directory;
    if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory();
    }

    if (directory == null) return;

    final String myFile = '${directory.path}/ShiftPlan-${shift.shift}-${DateFormat('yyyyMMdd').format(shift.date)}.pdf';
    final file = File(myFile);
    await file.writeAsBytes(await pdf.save());
    OpenFile.open(myFile);
  }

  pw.Widget _header(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _cell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 8)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: "Shift Plan PDF", subtitle: "Generating report..."),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ErpColors.navyMid,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf, color: ErpColors.accentLight, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                "Shift Plan Report",
                style: TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Your PDF will be generated and opened automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ErpPrimaryButton(
                label: "Generate & Open PDF",
                icon: Icons.download_outlined,
                onPressed: generatePdf,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
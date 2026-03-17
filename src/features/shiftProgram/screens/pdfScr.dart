import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:get/get.dart';

import '../controllers/shift_controller.dart';
import '../models/ProductionDataModel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';




class AnuTapesProductionPdf extends StatefulWidget {
  @override
  State<AnuTapesProductionPdf> createState() => _AnuTapesProductionPdf();
}

class _AnuTapesProductionPdf extends State<AnuTapesProductionPdf> {
  var  productionData;
  final shiftController = Get.put(ShiftController());
  @override
  void initState() {
    productionData=shiftController.productionData;
    super.initState();
  }

  var arg=Get.arguments;

  String formatHHmmss(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }


  void generatePdf(List<ProductionRow> data) async {
    final Directory? directory;
    try {
      final pdf = pw.Document();

      // Group by operator
      final Map<String, List<ProductionRow>> grouped = {};
      for (var row in data) {
        grouped.putIfAbsent(row.operatorName, () => []).add(row);
      }
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Supervisor / In-charge Signature: ________________________',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          build: (context) {
            return [
              // ================= HEADER =================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ANU TAPES',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.Text(
                            'Daily Production Report : Elastic Division',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Text(
                    'Date: ${(shiftController.shiftDetail.value.date)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Shift: ${(shiftController.shiftDetail.value.shift)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(),

              // ================= OPERATOR GROUPS =================
              ...grouped.entries.map((entry) {
                final avgEfficiency =
                    entry.value
                        .map((e) => e.efficiency)
                        .reduce((a, b) => a + b) /
                    entry.value.length;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 12),

                    // Operator title
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(6),
                      color: PdfColors.grey300,
                      child: pw.Text(
                        'Operator: ${entry.key}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),

                    pw.Table(
                      border: pw.TableBorder.all(
                        width: 0.5,
                        color: PdfColors.grey400,
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.3), // Machine
                        1: const pw.FlexColumnWidth(0.9), // Heads
                        2: const pw.FlexColumnWidth(0.9), // Hooks
                        3: const pw.FlexColumnWidth(1.1), // Prod
                        4: const pw.FlexColumnWidth(1.3), // Total
                        5: const pw.FlexColumnWidth(1.0), // Timer
                        6: const pw.FlexColumnWidth(1.0), // Downtime
                        7: const pw.FlexColumnWidth(1.2), // Eff
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            header('Machine'),
                            header('Heads'),
                            header('Hooks'),
                            header('Prod'),
                            header('Total'),
                            header('Timer'),
                            header('DT (min)'),
                            header('Eff %'),
                          ],
                        ),

                        ...entry.value.map((e) {
                          final low = e.efficiency < 70;
                          final critical = e.efficiency < 60;

                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: low ? PdfColors.red100 : PdfColors.white,
                            ),
                            children: [
                              cell(e.machineCode),
                              cell(
                                e.heads.toString(),
                                align: pw.TextAlign.center,
                              ),
                              cell(
                                e.hooks.toString(),
                                align: pw.TextAlign.center,
                              ),
                              cell(
                                e.production.toString(),
                                align: pw.TextAlign.right,
                              ),
                              cell(
                                e.totalProduction.toString(),
                                align: pw.TextAlign.right,
                              ),
                              cell( formatHHmmss(e.timer) , align: pw.TextAlign.center),
                              cell(
                                e.downtimeMinutes.toString(),
                                align: pw.TextAlign.center,
                              ),

                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.end,
                                  children: [
                                    if (critical)
                                      pw.Text(
                                        '⚠ ',
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColors.red,
                                        ),
                                      ),
                                    pw.Text(
                                      '${e.efficiency.toStringAsFixed(1)}%',
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: low
                                            ? PdfColors.red
                                            : PdfColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),

                    // Average efficiency
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.only(top: 6, right: 6),
                      child: pw.Text(
                        'Average Efficiency: ${avgEfficiency.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: avgEfficiency < 70
                              ? PdfColors.red
                              : PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ];
          },
        ),
      );

      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        return;
      }
      String path = directory.path;
      String myFile = '${path}/Tingsapp-statement.pdf';
      final file = File(myFile);
      await file.writeAsBytes(await pdf.save());
      OpenFile.open(myFile);
    } catch (e) {
      debugPrint("$e");
    }
  }

  pw.Widget header(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          textAlign: align,
          style: const pw.TextStyle(fontSize: 8),
        ),
      );

  @override
  Widget build(BuildContext context) {
    generatePdf(productionData);
    return Scaffold(
      appBar: AppBar(title: const Text('ANU TAPES Production PDF')),
    );
  }
}

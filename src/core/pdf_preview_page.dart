import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../features/PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  A DOCUMENT ON SCREEN, WITH SHARE AND PRINT
//
//  The purchase order and the challan each grew a private copy of
//  this page. New documents (the invoice first) use this one, fed the
//  SERVER's bytes — the PDF the customer receives, not a second
//  rendering of it — so sharing from the phone sends exactly the
//  paper the web prints.
// ══════════════════════════════════════════════════════════════

/// A file name that a share sheet and a mail client both accept:
/// "Invoice BE/25-26/0007" becomes "Invoice BE-25-26-0007.pdf".
String pdfFileName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
  final name = cleaned.isEmpty ? 'document' : cleaned;
  return name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf';
}

class DocumentPdfPage extends StatelessWidget {
  const DocumentPdfPage({
    super.key,
    required this.bytes,
    required this.title,
    this.subtitle = '',
  });

  final Uint8List bytes;

  /// What the document is called — the app bar, the shared file's
  /// name and the print job's name all read from it.
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: ErpTextStyles.pageTitle),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
      ),
      // The preview's own share and print buttons, named after the
      // document — adding actions of our own as well showed each twice.
      body: PdfPreview(
        build: (_) => bytes,
        pdfFileName: pdfFileName(title),
        pdfPreviewPageDecoration: const BoxDecoration(color: Color(0xFFE5E8EF)),
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        loadingWidget: Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue),
        ),
      ),
    );
  }
}

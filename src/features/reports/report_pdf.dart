import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../core/lock/open_externally.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  Report PDF download (mobile)
//
//  Fetches the server-generated report PDF (?format=pdf) with the auth
//  cookie, writes it to a temp file, and opens it in the device's PDF
//  viewer. Same document the web downloads — no screen capture.
// ══════════════════════════════════════════════════════════════
Future<void> downloadReportPdf({
  required String path, // e.g. '/reports/dispatch'
  required Map<String, dynamic> query, // preset, groupBy
  required String filename, // e.g. 'dispatch-sales-report'
}) async {
  Get.snackbar(
    'Generating PDF…',
    'Preparing your report',
    backgroundColor: const Color(0xFF1D6FEB),
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 2),
  );
  try {
    final dio = ApiClient.buildClient(
      baseUrl: ApiConfig.baseUrl,
    );
    final res = await dio.get(
      path,
      queryParameters: {...query, 'format': 'pdf'},
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(res.data as List<int>);
    final result = await openExternally(file.path);
    if (result.type != ResultType.done) {
      Get.snackbar(
        'Saved',
        'PDF saved to ${file.path}',
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  } catch (e) {
    Get.snackbar(
      'Error',
      'Could not generate the PDF',
      backgroundColor: const Color(0xFFDC2626),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_config.dart';
import 'job_qr_label_doc.dart';

export 'job_qr_label_doc.dart' show jobLabelPayload, kLabelInches;

// ══════════════════════════════════════════════════════════════
//  THE 2in JOB LABEL
//
//  The same label the web prints, on the phone — because the person
//  who needs one is usually standing at the trolley that has lost its
//  label, not at the desk that has the printer.
//
//  It has to be more than visually similar: SCANNABLE by the same
//  reader and resolving to the same job. So the payload follows
//  exactly the rule jobUrl() uses in JobQrPrint.tsx, and the origin
//  comes from the API base this build is pointed at rather than a
//  constant — otherwise a sandbox build prints labels that scan into
//  production.
//
//  The drawing lives in job_qr_label_doc.dart, which imports no
//  Flutter plugins and is therefore testable; this file is only the
//  part that needs a file system.
// ══════════════════════════════════════════════════════════════

class JobQrLabelPdf {
  /// [jobNo] is printed verbatim. A String, not an int: the screens
  /// carry it as one, and parsing it to a number here only to print it
  /// again would turn an unexpected format into a 0 on a label.
  static Future<void> generate({
    required String jobId,
    required String jobNo,
  }) async {
    final doc = buildJobLabelDocument(
      payload: jobLabelPayload(ApiConfig.baseUrl, jobId),
      jobNo: jobNo,
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/JobLabel_${_safe(jobNo)}.pdf');
    await file.writeAsBytes(await doc.save());
    await OpenFile.open(file.path);
  }

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

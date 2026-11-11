// ══════════════════════════════════════════════════════════════
//  SERVER-RENDERED PDFs
//
//  Documents whose layout is designed in Settings → PDF Designer are
//  rendered SERVER-side, so the app must download those bytes rather
//  than drawing its own layout — otherwise the designed template is
//  ignored and every device prints something different.
//
//  fetchServerPdf() returns the rendered bytes, or null when the
//  request fails (offline, older server, no route). Callers fall back
//  to their built-in generator so a PDF always opens.
//
//  ── Two contracts, because there are two situations ────────────
//  The null-on-failure contract above is exactly right for the PO and
//  the delivery challan: this app can draw both itself, so a failed
//  download should quietly become a locally drawn document rather
//  than an error. Swallowing the reason costs nothing when there is a
//  working fallback behind it.
//
//  It is exactly WRONG for a document with no local generator — the
//  quotation and the order status report, whose layouts exist only on
//  the server. There, null means the person taps a button and nothing
//  at all happens, with no way to tell "you are signed out" from "no
//  signal" from "this quote has no PDF". So openServerPdf() throws
//  with words instead, and the two live side by side on purpose.
// ══════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'lock/open_externally.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';
import 'app_config.dart';

final _pdfDio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

/// GETs [path] (relative to the API base) expecting a PDF body.
/// Returns null on any failure so the caller can fall back locally.
Future<Uint8List?> fetchServerPdf(String path) async {
  try {
    final res = await _pdfDio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        // A JSON error body is a valid response we want to inspect, not throw on.
        validateStatus: (s) => s != null && s < 500,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final data = res.data;
    if (res.statusCode != 200 || data == null || data.isEmpty) return null;

    final bytes = Uint8List.fromList(data);
    // A PDF always starts with "%PDF"; anything else is an error payload.
    if (bytes.length < 4 ||
        bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
      return null;
    }
    return bytes;
  } catch (_) {
    return null;
  }
}

/// The printable production sheet for a shift plan.
///
/// ── Why this is worth a round trip ─────────────────────────────
/// The phone can draw a shift plan itself, and did. What it cannot
/// draw is the QR code the server puts on every row — utils/
/// shiftSheetPdf.js encodes `SHIFTROW|<shift detail id>|…` per line,
/// which is what the app's scanner reads to open a row. A locally
/// drawn sheet looks nearly identical and is unscannable, so the
/// supervisor carrying it finds the scan feature simply does not
/// work on their copy.
///
/// Null on failure, like the PO and the challan: there IS a local
/// generator behind this one, and a sheet without codes beats no
/// sheet at all on a bad connection.
Future<Uint8List?> fetchShiftSheetPdf(String shiftPlanId) =>
    fetchServerPdf(shiftSheetPdfPath(shiftPlanId));

/// Purchase order — rendered from the "purchase-order" template.
Future<Uint8List?> fetchPoPdf(String poId) => fetchServerPdf(poPdfPath(poId));

/// Delivery challan — rendered from the "delivery-challan" template.
Future<Uint8List?> fetchDcPdf(String dcId) => fetchServerPdf(dcPdfPath(dcId));

/// One employee's payslip for a month — services/payslipPdf.js, the
/// copy the web prints, with the name in Tamil where one is set. Null
/// on failure: the phone can still draw a payslip itself.
Future<Uint8List?> fetchPayslipPdf(String employeeId,
        {required int year, required int month}) =>
    fetchServerPdf(payslipPdfPath(employeeId, year: year, month: month));

// ── Where each document lives on the server ────────────────────
// Plain functions, so a test can hold them to the server's routes.
// The shift sheet's once read '/shift/\$shiftPlanId/…' — the escaped
// dollar sent those words instead of the id, the server refused them,
// and every sheet printed from the phone came out without QR codes.
String shiftSheetPdfPath(String shiftPlanId) =>
    '/shift/$shiftPlanId/production-sheet.pdf';
String poPdfPath(String poId) => '/supplier/po/$poId/pdf';
String dcPdfPath(String dcId) => '/dc/$dcId/pdf';
String payslipPdfPath(String employeeId,
        {required int year, required int month}) =>
    '/payroll/slip/$employeeId/pdf?year=$year&month=$month';
String invoicePdfPath(String invoiceId) => '/invoice/$invoiceId/pdf';

/// The bytes of a server PDF, or a [ServerPdfError] with words — for a
/// preview with share and print, where a silent null would leave a
/// button that does nothing. Same checks as [openServerPdf].
Future<Uint8List> serverPdfBytes(String path) => _strictFetch(path);

// ── For documents the app cannot draw itself ──────────────────

/// Thrown with a message already fit to show somebody.
class ServerPdfError implements Exception {
  ServerPdfError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Download [path], write it to the cache, and hand it to whatever on
/// this phone opens PDFs. Throws [ServerPdfError] with a usable
/// message rather than returning null.
///
/// [filename] is what the viewer's title bar and the share sheet
/// show, so it should read like a document and not like an id —
/// "Quotation QT-25-26-0007.pdf", not "6a85c9.pdf".
Future<void> openServerPdf(String path, {required String filename}) async {
  final bytes = await _strictFetch(path);

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_safeName(filename)}');
  await file.writeAsBytes(bytes, flush: true);

  final res = await openExternally(file.path);
  if (res.type != ResultType.done) {
    // Plenty of Android builds ship with no PDF viewer at all, and
    // OpenFile reports that rather than throwing.
    throw ServerPdfError(res.message.isNotEmpty
        ? res.message
        : 'No app on this phone can open a PDF.');
  }
}

Future<Uint8List> _strictFetch(String path) async {
  late final Response<List<int>> res;
  try {
    res = await _pdfDio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
  } on DioException catch (e) {
    throw ServerPdfError(_messageFor(e));
  }

  final data = res.data ?? const <int>[];
  final bytes = Uint8List.fromList(data);
  // A 200 that is not a PDF is nearly always an auth redirect or a
  // JSON error. Written to disk it opens as a blank page, and the
  // person reports "the PDF is empty" — which sends everybody looking
  // at the renderer instead of at the session.
  if (bytes.length < 4 ||
      bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
    throw ServerPdfError(bytes.isEmpty
        ? 'The server returned an empty document.'
        : 'The server did not return a PDF — you may have been signed out. '
            'Sign in again and retry.');
  }
  return bytes;
}

String _messageFor(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401 || code == 403) {
    return 'You do not have permission to download this document.';
  }
  if (code == 404) return 'The server has no document for this record.';
  // An error BODY on a bytes request arrives as bytes, so the usual
  // data['message'] read finds nothing. Naming the status plainly
  // beats "Instance of DioException".
  if (code != null) return 'The server refused the download ($code).';
  return 'Could not reach the server. Check the connection and retry.';
}

String _safeName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9 ._-]'), '_').trim();
  if (cleaned.isEmpty) return 'document.pdf';
  return cleaned.toLowerCase().endsWith('.pdf') ? cleaned : '$cleaned.pdf';
}

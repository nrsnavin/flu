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
// ══════════════════════════════════════════════════════════════
import 'dart:typed_data';

import 'package:dio/dio.dart';

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

/// Purchase order — rendered from the "purchase-order" template.
Future<Uint8List?> fetchPoPdf(String poId) => fetchServerPdf('/supplier/po/$poId/pdf');

/// Delivery challan — rendered from the "delivery-challan" template.
Future<Uint8List?> fetchDcPdf(String dcId) => fetchServerPdf('/dc/$dcId/pdf');

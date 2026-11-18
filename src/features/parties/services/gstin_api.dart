import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/gstin_models.dart';

// ══════════════════════════════════════════════════════════════
//  GSTIN CHECK API — mounted inside /customer and /supplier
//
//    POST /gstin/:gstin/verify   checked with the GST system; the answer
//                                is kept. { fresh: true } asks again when
//                                a recent answer is kept.
//    GET  /gstin/:gstin/check    the last answer kept (nobody is asked)
//
//  The same two routes on both, so the form's own module decides who
//  may use them: a login without Customers cannot verify from there.
// ══════════════════════════════════════════════════════════════

String gstinMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check the connection and try again.';
    }
  }
  return fallback;
}

class GstinApi {
  // The server gives the provider up to thirty seconds to answer; the
  // app's ordinary fifteen would give up on an answer about to arrive.
  static final Map<String, Dio> _clients = {
    for (final kind in const ['customer', 'supplier'])
      kind: ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/$kind', timeout: const Duration(seconds: 45)),
  };

  static Dio _dio(String kind) => _clients[kind == 'supplier' ? 'supplier' : 'customer']!;

  /// Check [gstin] with the GST system. [fresh] asks again even when a
  /// recent answer is kept.
  static Future<GstinAnswer> verify(String kind, String gstin, {bool fresh = false}) async {
    final res = await _dio(kind).post('/gstin/${Uri.encodeComponent(gstin)}/verify', data: {if (fresh) 'fresh': true});
    return GstinAnswer.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// The last answer kept for [gstin], or null when it was never checked.
  static Future<GstinAnswer?> lastCheck(String kind, String gstin) async {
    final res = await _dio(kind).get('/gstin/${Uri.encodeComponent(gstin)}/check');
    final check = res.data is Map ? (res.data as Map)['check'] : null;
    return check is Map ? GstinAnswer.fromJson(Map<String, dynamic>.from(check)) : null;
  }
}

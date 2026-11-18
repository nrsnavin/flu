import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/dispatch_models.dart';

// ══════════════════════════════════════════════════════════════
//  DISPATCH QUEUE API — /api/v2/dispatch
//
//    GET   /queue                   what is waiting, most urgent first
//    GET   /queue?view=dispatched   what has gone, newest first
//    PATCH /:id/urgency             admin / marketing — when it must leave
//    POST  /:id/dispatched          it has gone
//    POST  /:id/cancel              admin — off the queue, with a reason
//
//  The server keeps the order (awaiting first, then deadline) and says
//  what is late; the phone shows it as sent.
// ══════════════════════════════════════════════════════════════

String dispatchMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check the connection and try again.';
    }
  }
  return fallback;
}

class DispatchApi {
  static final Dio _dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/dispatch');

  static DispatchItem _item(Response res) =>
      DispatchItem.fromJson(Map<String, dynamic>.from((res.data as Map)['item'] as Map));

  /// The open queue, or — with [dispatched] — the latest that have gone.
  static Future<DispatchQueue> queue({bool dispatched = false}) async {
    final res = await _dio.get('/queue', queryParameters: {if (dispatched) 'view': 'dispatched'});
    return DispatchQueue.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<DispatchItem> setUrgency(String id, String urgency) async =>
      _item(await _dio.patch('/$id/urgency', data: {'urgency': urgency}));

  static Future<DispatchItem> markDispatched(String id, {String note = ''}) async =>
      _item(await _dio.post('/$id/dispatched', data: {if (note.trim().isNotEmpty) 'note': note.trim()}));

  static Future<DispatchItem> cancel(String id, String reason) async =>
      _item(await _dio.post('/$id/cancel', data: {'reason': reason.trim()}));
}

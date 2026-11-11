import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../../core/server_pdf.dart';
import '../gst.dart';
import '../models/invoice_models.dart';

// ══════════════════════════════════════════════════════════════
//  INVOICE API — /api/v2/invoice
//
//  Reading needs Invoices, Orders or Customers; raising and cancelling
//  need Invoices (app.js mounts it so). Raising carries a request id,
//  kept across retries of one submission, so a timeout on a factory
//  floor connection and a second tap cannot raise the invoice twice:
//  the server hands back the one it already made.
// ══════════════════════════════════════════════════════════════

/// A message fit to show, from whatever went wrong.
String invoiceMessage(Object e, String fallback) {
  if (e is ServerPdfError) return e.message;
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.response?.statusCode == 403) return 'You do not have access to invoices.';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check the connection and try again.';
    }
  }
  return fallback;
}

/// The customer is on credit hold: an admin can release this one
/// invoice with a reason; anyone else has to collect first.
bool isCreditHold(Object e) =>
    e is DioException &&
    e.response?.statusCode == 409 &&
    e.response?.data is Map &&
    (e.response!.data as Map)['code'] == 'CREDIT_HOLD';

class InvoiceApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/invoice');

  static Map<String, dynamic> _body(Response res) =>
      Map<String, dynamic>.from(res.data as Map);

  static Future<InvoicePage> list({
    int page = 1,
    String? search,
    String? status,
    String? einvoice,
  }) async {
    final res = await _dio.get('/list', queryParameters: {
      'page': page,
      'limit': 20,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null) 'status': status,
      if (einvoice != null) 'einvoice': einvoice,
    });
    return InvoicePage.fromJson(_body(res));
  }

  static Future<Invoice> detail(String id) async {
    final res = await _dio.get('/detail', queryParameters: {'id': id});
    return Invoice.fromJson(Map<String, dynamic>.from(_body(res)['invoice'] as Map));
  }

  static Future<InvoiceOrderInfo> orderInfo(String orderId) async {
    final res = await _dio.get('/order-info', queryParameters: {'id': orderId});
    return InvoiceOrderInfo.fromJson(_body(res));
  }

  static Future<OrderInvoices> byOrder(String orderId) async {
    final res = await _dio.get('/by-order', queryParameters: {'id': orderId});
    return OrderInvoices.fromJson(_body(res));
  }

  static Future<Invoice> create({
    required String orderId,
    required List<String> dcIds,
    required DateTime invoiceDate,
    required String requestId,
    Map<String, LineOverride> overrides = const {},
    String? notes,
    String? shipTo,
    String? creditOverride,
  }) async {
    final lines = [
      for (final e in overrides.entries)
        if (!e.value.isEmpty) e.value.toJson(e.key),
    ];
    final res = await _dio.post('/create', data: {
      'orderId': orderId,
      'dcIds': dcIds,
      // The day as the person sees it on their phone, which in India is
      // the day the invoice belongs to.
      'invoiceDate': DateFormat('yyyy-MM-dd').format(invoiceDate),
      'requestId': requestId,
      if (lines.isNotEmpty) 'lines': lines,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (shipTo != null && shipTo.trim().isNotEmpty) 'shipTo': shipTo.trim(),
      if (creditOverride != null) 'creditOverride': creditOverride,
    });
    return Invoice.fromJson(Map<String, dynamic>.from(_body(res)['invoice'] as Map));
  }

  /// [portalNote] is set when the IRN was pasted in by hand and has to
  /// be cancelled on the portal too.
  static Future<({Invoice invoice, String portalNote})> cancel(String id, String reason) async {
    final res = await _dio.post('/$id/cancel', data: {'reason': reason});
    final body = _body(res);
    return (
      invoice: Invoice.fromJson(Map<String, dynamic>.from(body['invoice'] as Map)),
      portalNote: body['portalNote']?.toString() ?? '',
    );
  }

  /// The server's PDF — the paper the customer receives.
  static Future<Uint8List> pdf(String id) => serverPdfBytes(invoicePdfPath(id));
}

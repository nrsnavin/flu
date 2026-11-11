import 'dart:typed_data';

import 'package:dio/dio.dart';
// Not in the app's own dependencies, but every Dio release depends on
// it, and its MediaType is the one type both old and new Dio accept for
// a part's content type (newer Dio names it DioMediaType; older Dio has
// no such name).
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/claim_models.dart';

// ══════════════════════════════════════════════════════════════
//  EXPENSE CLAIMS API — /api/v2/claims (every signed-in person)
//
//  A person sees and withdraws only their own claims. The receipt goes
//  up labelled JPEG, PNG, WebP or PDF: the server keeps it only when the
//  label and the bytes agree, and an unlabelled part (Dio's default is
//  application/octet-stream) would be refused.
// ══════════════════════════════════════════════════════════════

String claimMessage(Object e, String fallback) {
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

/// The content type for a receipt file, from its name.
MediaType receiptType(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  return switch (ext) {
    'png' => MediaType('image', 'png'),
    'webp' => MediaType('image', 'webp'),
    'pdf' => MediaType('application', 'pdf'),
    _ => MediaType('image', 'jpeg'),
  };
}

class ClaimsApi {
  static final Dio _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/claims',
    // Reading a receipt is an AI call and can take a while.
    timeout: const Duration(seconds: 60),
  );

  static FormData _file(Uint8List bytes, String filename) => FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: receiptType(filename)),
      });

  static Future<List<ClaimCategory>> categories() async {
    final res = await _dio.get('/categories');
    return ((res.data as Map)['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ClaimCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<MyClaims> mine() async {
    final res = await _dio.get('/');
    return MyClaims.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Read a receipt into a claim; nothing is saved.
  static Future<ClaimScan> scan(Uint8List bytes, String filename) async {
    final res = await _dio.post('/scan', data: _file(bytes, filename));
    return ClaimScan.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<Claim> create({
    required String category,
    required String description,
    required double amount,
    required DateTime date,
    required String requestId,
    String refNo = '',
    String? aiSuggestion,
  }) async {
    final res = await _dio.post('/', data: {
      'category': category,
      'description': description.trim(),
      'amount': amount,
      // The day on the claimant's phone, which is the day they spent it.
      'date': DateFormat('yyyy-MM-dd').format(date),
      'requestId': requestId,
      if (refNo.trim().isNotEmpty) 'refNo': refNo.trim(),
      if (aiSuggestion != null) 'aiSuggestion': aiSuggestion,
    });
    return Claim.fromJson(Map<String, dynamic>.from((res.data as Map)['claim'] as Map));
  }

  static Future<void> attachPhoto(String claimId, Uint8List bytes, String filename) =>
      _dio.post('/$claimId/photo', data: _file(bytes, filename));

  static Future<Claim> withdraw(String claimId) async {
    final res = await _dio.post('/$claimId/withdraw');
    return Claim.fromJson(Map<String, dynamic>.from((res.data as Map)['claim'] as Map));
  }
}

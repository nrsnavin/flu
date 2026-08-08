import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/sample.dart';

// ══════════════════════════════════════════════════════════════
//  SAMPLE REQUEST API  —  /api/v2/sample
//
//  Routed through ApiClient.buildClient so the JWT cookie rides along;
//  a bare Dio would 401 against the gated backend.
// ══════════════════════════════════════════════════════════════
class SampleApi {
  SampleApi._();

  static final Dio _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/sample',
    // Photos are up to 5 MB and go up over whatever the factory's
    // connection happens to be, so the default 15s is not enough.
    timeout: const Duration(seconds: 60),
  );

  static Future<SampleListPage> list({
    String status = 'active',
    String query = '',
    int page = 1,
    int limit = 25,
  }) async {
    final res = await _dio.get('/', queryParameters: {
      if (status.isNotEmpty && status != 'all') 'status': status,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'page': page,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return SampleListPage(
      samples: (data['samples'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SampleRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
      counts: data['counts'] is Map
          ? SampleCounts.fromJson(Map<String, dynamic>.from(data['counts']))
          : const SampleCounts(),
    );
  }

  static Future<SampleDetail> detail(String id) async {
    final res = await _dio.get('/$id');
    return SampleDetail.fromJson(
        Map<String, dynamic>.from((res.data as Map)['sample'] as Map));
  }

  static Future<SampleDetail> create({
    required String title,
    required String details,
    String? customerId,
    String? customerName,
    double? quantity,
    String? targetDate,
    String priority = 'normal',
  }) async {
    final res = await _dio.post('/', data: {
      'title': title,
      'details': details,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      if (customerName != null && customerName.trim().isNotEmpty)
        'customerName': customerName.trim(),
      if (quantity != null && quantity > 0) 'quantity': quantity,
      if (targetDate != null && targetDate.isNotEmpty) 'targetDate': targetDate,
      'priority': priority,
    });
    return SampleDetail.fromJson(
        Map<String, dynamic>.from((res.data as Map)['sample'] as Map));
  }

  static Future<SampleDetail> addLog(String id, String note) async {
    final res = await _dio.post('/$id/log', data: {'note': note});
    return SampleDetail.fromJson(
        Map<String, dynamic>.from((res.data as Map)['sample'] as Map));
  }

  static Future<SampleDetail> setStatus(
      String id, String status, String note) async {
    final res = await _dio.put('/$id/status', data: {
      'status': status,
      'note': note,
    });
    return SampleDetail.fromJson(
        Map<String, dynamic>.from((res.data as Map)['sample'] as Map));
  }

  /// The part carries no content type on purpose: Dio's MultipartFile
  /// labels every part application/octet-stream unless given a media
  /// type, and the class that represents one moved between Dio releases.
  /// The server resolves an unlabelled photo from its extension and
  /// validates that against the same allow-list, so the filename has to
  /// keep its extension — which is why it is passed through rather than
  /// generated.
  static Future<SampleDetail> addPhoto(
    String id, {
    required Uint8List bytes,
    required String filename,
    String caption = '',
  }) async {
    final form = FormData.fromMap({
      'caption': caption,
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/$id/photo', data: form);
    return SampleDetail.fromJson(
        Map<String, dynamic>.from((res.data as Map)['sample'] as Map));
  }

  static Future<SampleDetail> removePhoto(String photoId, String reason) async {
    // The reason goes in the query string: a DELETE body is dropped by
    // some proxies, and requireReason() on the server reads either.
    final res = await _dio.delete('/photo/$photoId',
        queryParameters: {'reason': reason});
    return SampleDetail.fromJson(
        Map<String, dynamic>.from((res.data as Map)['sample'] as Map));
  }

  /// The bytes of one photo.
  ///
  /// Fetched rather than handed to Image.network: the route is behind the
  /// auth gate and the cookie lives on this Dio, not on Flutter's image
  /// loader — an <img>-style fetch would come back 401 and render an
  /// empty box with no explanation.
  static Future<Uint8List> photoBytes(String photoId) async {
    final res = await _dio.get<List<int>>(
      '/photo/$photoId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }
}

class SampleListPage {
  final List<SampleRow> samples;
  final int total;
  final int page;
  final int pages;
  final SampleCounts counts;

  const SampleListPage({
    required this.samples,
    required this.total,
    required this.page,
    required this.pages,
    required this.counts,
  });
}

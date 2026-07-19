import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

/// Result of an import run, mirrored from the backend report.
class ImportResult {
  final int suppliers;
  final int materials;
  final int elastics;
  final List<String> skipped;
  final String message;

  const ImportResult({
    required this.suppliers,
    required this.materials,
    required this.elastics,
    required this.skipped,
    required this.message,
  });

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
        suppliers: (j['suppliers'] as num?)?.toInt() ?? 0,
        materials: (j['materials'] as num?)?.toInt() ?? 0,
        elastics:  (j['elastics']  as num?)?.toInt() ?? 0,
        skipped:   List<String>.from((j['skipped'] as List?) ?? const []),
        message:   j['message']?.toString() ?? 'Import complete',
      );
}

/// Drives the Raw Material + Elastic Excel import screen.
/// Picks an .xlsx, uploads it to `/api/v2/io/import`, and surfaces
/// the backend's upsert report (counts + any skipped rows).
class DataIoController extends GetxController {
  final busy       = false.obs;
  final errorMsg   = Rxn<String>();
  final lastResult = Rxn<ImportResult>();
  final pickedName = Rxn<String>();

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/io',
  );

  Future<void> pickAndImport() async {
    errorMsg.value = null;
    lastResult.value = null;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // ensures bytes are available on every platform
    );
    if (picked == null || picked.files.isEmpty) return; // user cancelled

    final file = picked.files.single;
    pickedName.value = file.name;

    busy.value = true;
    try {
      // Prefer in-memory bytes (works on web + mobile); fall back to
      // the file path when bytes aren't loaded.
      final MultipartFile part = file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name);

      final form = FormData.fromMap({'file': part});
      final res = await _dio.post('/import', data: form);

      final body = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      lastResult.value = ImportResult.fromJson(body);
    } on DioException catch (e) {
      errorMsg.value = e.response?.data is Map
          ? (e.response?.data['message'] as String?) ?? 'Import failed'
          : 'Import failed — could not reach the server';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      busy.value = false;
    }
  }
}

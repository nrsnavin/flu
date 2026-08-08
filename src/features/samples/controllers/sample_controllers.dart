import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;

import '../../authentication/controllers/login_controller.dart';
import '../models/sample.dart';
import 'sample_api.dart';

// ══════════════════════════════════════════════════════════════
//  SAMPLE REQUEST CONTROLLERS
//
//  Two of them: the list, and one open request. Kept apart because a
//  detail refresh after adding an update should not re-page the list
//  behind it.
// ══════════════════════════════════════════════════════════════

/// The server's own words when it sent any, the fallback otherwise.
/// A DioException stringifies to a stack-trace-ish blob that helps
/// nobody standing at a loom.
String apiMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return fallback;
}

/// The signed-in user's role. Completing, closing and reopening are an
/// admin's call, and the buttons are hidden rather than shown-and-refused.
bool get isAdminUser =>
    LoginController.find.user.value.role.toLowerCase() == 'admin';

class SampleListController extends GetxController {
  final items = <SampleRow>[].obs;
  final counts = const SampleCounts().obs;
  final loading = false.obs;
  final errorMsg = RxnString();

  /// active · open · in_progress · completed · closed · all
  final filter = 'active'.obs;
  final query = ''.obs;
  final page = 1.obs;
  final pages = 1.obs;
  final total = 0.obs;

  Timer? _debounce;

  static const filters = [
    'active',
    'open',
    'in_progress',
    'completed',
    'closed',
    'all',
  ];

  static String filterLabel(String f) {
    switch (f) {
      case 'active':
        return 'Live';
      case 'all':
        return 'All';
      default:
        return sampleStatusLabel(f);
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetch();
    ever(filter, (_) {
      page.value = 1;
      fetch();
    });
  }

  /// Typing should not fire a request per keystroke.
  void search(String value) {
    query.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      page.value = 1;
      fetch();
    });
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await SampleApi.list(
        status: filter.value,
        query: query.value,
        page: page.value,
      );
      items.value = res.samples;
      counts.value = res.counts;
      total.value = res.total;
      pages.value = res.pages;
    } catch (e) {
      errorMsg.value = apiMessage(e, 'Failed to load sample requests');
    } finally {
      loading.value = false;
    }
  }

  Future<void> goToPage(int p) async {
    if (p < 1 || p > pages.value || p == page.value) return;
    page.value = p;
    await fetch();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}

class SampleDetailController extends GetxController {
  final String sampleId;
  SampleDetailController(this.sampleId);

  final sample = Rxn<SampleDetail>();
  final loading = false.obs;
  final busy = false.obs;
  final errorMsg = RxnString();

  /// Cached photo FETCHES, not bytes.
  ///
  /// A FutureBuilder handed a new future on every rebuild re-runs it —
  /// the tile would flicker back to its spinner each time the screen
  /// rebuilt, and re-download on a phone data plan. Holding the future
  /// itself means the same one is returned for the life of the screen.
  final _photoFetches = <String, Future<Uint8List>>{};

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      sample.value = await SampleApi.detail(sampleId);
    } catch (e) {
      errorMsg.value = apiMessage(e, 'Failed to load the sample');
    } finally {
      loading.value = false;
    }
  }

  /// Returns null on success, or a message to show.
  Future<String?> addUpdate(String note) async {
    if (note.trim().isEmpty) return 'Write the update first';
    busy.value = true;
    try {
      sample.value = await SampleApi.addLog(sampleId, note.trim());
      return null;
    } catch (e) {
      return apiMessage(e, 'Could not add the update');
    } finally {
      busy.value = false;
    }
  }

  Future<String?> setStatus(String status, String note) async {
    busy.value = true;
    try {
      sample.value = await SampleApi.setStatus(sampleId, status, note.trim());
      return null;
    } catch (e) {
      return apiMessage(e, 'Could not change the status');
    } finally {
      busy.value = false;
    }
  }

  /// Pick a photo and send it. The picker is the only image source this
  /// app has a dependency for; on Android its sheet offers the camera,
  /// on iOS it is the photo library.
  Future<String?> addPhoto(String caption) async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } catch (_) {
      return 'Could not open the photo picker';
    }
    if (picked == null || picked.files.isEmpty) return null; // cancelled
    final f = picked.files.first;
    if (f.bytes == null) return 'Could not read that photo';

    // The server resolves an unlabelled part by its extension, so the
    // filename has to keep one.
    final name = f.name.contains('.') ? f.name : '${f.name}.jpg';

    busy.value = true;
    try {
      sample.value = await SampleApi.addPhoto(
        sampleId,
        bytes: f.bytes!,
        filename: name,
        caption: caption.trim(),
      );
      return null;
    } catch (e) {
      return apiMessage(e, 'Could not add the photo');
    } finally {
      busy.value = false;
    }
  }

  Future<String?> removePhoto(String photoId, String reason) async {
    if (reason.trim().length < 3) return 'Say why it is being removed';
    busy.value = true;
    try {
      sample.value = await SampleApi.removePhoto(photoId, reason.trim());
      _photoFetches.remove(photoId);
      return null;
    } catch (e) {
      return apiMessage(e, 'Could not remove the photo');
    } finally {
      busy.value = false;
    }
  }

  /// The bytes of one photo, fetched at most once per screen.
  Future<Uint8List> photo(String photoId) =>
      _photoFetches[photoId] ??= SampleApi.photoBytes(photoId);
}

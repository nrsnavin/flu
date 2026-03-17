import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/Job/models/JobListModel.dart';

class JobListController extends GetxController {
  static final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final jobs           = <JobListModel>[].obs;
  final isLoading      = false.obs;
  final selectedStatus = "all".obs;
  final searchText     = "".obs;

  final scrollController = ScrollController();
  final searchController = TextEditingController();

  int  _page    = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    // FIX: super.onInit() first
    super.onInit();
    fetchJobs();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // FIX: was `==` exact pixel match — can miss on some devices
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !isLoading.value) {
      _page++;
      fetchJobs();
    }
  }

  Future<void> fetchJobs({bool reset = false}) async {
    if (reset) {
      _page    = 1;
      _hasMore = true;
      jobs.clear();
    }
    if (!_hasMore) return;

    try {
      isLoading.value = true;
      final res = await _dio.get("/job/jobs", queryParameters: {
        "page":   _page,
        "limit":  10,
        "status": selectedStatus.value,
        "search": searchText.value,
      });

      final List data = res.data["jobs"] ?? [];
      final newJobs   = data.map((e) => JobListModel.fromJson(e)).toList();
      jobs.addAll(newJobs);
      if (newJobs.length < 10) _hasMore = false;
    } on DioException catch (e) {
      // FIX: was missing catch — isLoading stuck true forever on error
      final msg = e.response?.data?['message'] ?? "Failed to load jobs";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void changeStatus(String status) {
    selectedStatus.value = status;
    fetchJobs(reset: true);
  }

  void searchJob(String value) {
    searchText.value = value;
    fetchJobs(reset: true);
  }

  @override
  void onClose() {
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }
}
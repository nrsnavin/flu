
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:production/src/core/api_client.dart';
// import 'package:production/src/features/job/controllers/new_job_controller.dart';
// import 'package:production/src/features/job/screens/jobDetailScreen.dart';
import 'package:production/src/features/shiftProgram/models/employee.dart';
import 'package:production/src/features/shiftProgram/models/shiftDetailModel.dart';
import 'package:production/src/features/shiftProgram/models/shiftOpenListModel.dart';
import 'package:production/src/features/shiftProgram/models/shiftPlanlModel.dart';
import 'package:production/src/features/shiftProgram/screens/shiftPlanScreen.dart';

import '../models/ProductionDataModel.dart';
import '../../../core/app_config.dart';

class ShiftController extends GetxController {
  static ShiftController get find => Get.find();

  // Route Dio through ApiClient.buildClient so the JWT cookie
  // attaches; bare Dio() 401s on the admin-gated shift routes.
  final _dio = ApiClient.buildClient(
    baseUrl: ApiConfig.baseUrl,
  );

  RxList<Employee> employeesWeave = (List<Employee>.of([])).obs;
  RxList<ShiftOpenListModel> shiftsOpen = (List<ShiftOpenListModel>.of([])).obs;

  RxBool isLoading = true.obs;
  RxBool isLoadingSp = false.obs;

  Rx<ShiftDetailModel> shiftDetail = ShiftDetailModel(
    elastics: "",
    status: "open",
    description: "open",

    shift: "12",
    date: DateTime.now().toString(),
    id: "test",
    employee: "",
    production: 0,
    machine: "1",
    noOfHooks: 190,
    noOfHeads: 7,
  ).obs;

  Rx<ShiftPlanModel> shiftPLanRX = ShiftPlanModel(
    plan: [
      ShiftOpenListModel(
        id: "id",
        employee: "employee",
        machine: "machine",
        shift: "shift",
        date: "date",
        heads: 8,
        elastic: "elastic",
        production: 0,
      ),
    ],

    description: "open",

    shift: "12",
    date: DateTime.now().toString(),
    id: "test",

    production: 0,
  ).obs;

  RxList<ProductionRow> productionData = [
    ProductionRow(
      operatorName: 'Ramesh',
      machineCode: 'MC-01',
      heads: 16,
      hooks: 48,
      production: 420,
      totalProduction: 1240,
      timer: Duration(hours: 6),
      efficiency: 87.5,
      downtimeMinutes: Duration(minutes: 2),
    ),
    ProductionRow(
      operatorName: 'Ramesh',
      machineCode: 'MC-03',
      heads: 16,
      hooks: 48,
      production: 300,
      totalProduction: 980,
      timer: Duration(hours: 6),
      efficiency: 58.2,
      downtimeMinutes: Duration(hours: 6),
    ),
    ProductionRow(
      operatorName: 'Suresh',
      machineCode: 'MC-08',
      heads: 12,
      hooks: 36,
      production: 380,
      totalProduction: 1105,
      timer: Duration(hours: 6),
      efficiency: 82.3,
      downtimeMinutes: Duration(hours: 6),
    ),
  ].obs;

  // void tryPost(
  //   String jobId,
  //   DateTime date,
  //   String shift,
  //   String description,
  //   String employee,
  // ) async {
  //   final response = await Dio().post(
  //     'http://10.0.2.2:2701/api/v2/shift/create-shift',
  //     data: {
  //       'job': jobId,
  //       'date': date.toString(),
  //       'shift': shift,
  //       'description': description,
  //       'employee': employee,
  //     },
  //   );
  //
  //   if (response.statusCode == 201) {
  //     // If the server did return a 201 CREATED response,
  //     // then parse the JSON.
  //   } else {
  //     // If the server did not return a 201 CREATED response,
  //     // then throw an exception.
  //     throw Exception('Failed to Login.');
  //   }
  // }

  void tryPost(
    var plan,
    DateTime date,
    String shift,
    String description,
  ) async {
    try {
      isLoadingSp.value = true;
      final response = await _dio.post(
        '/shift/create-shift',
        data: {
          'plan': plan,
          'date': date.toString(),
          'shift': shift,
          'description': description,
        },
      );

      if (response.statusCode == 201) {
        // If the server did return a 201 CREATED response,
        // then parse the JSON.
        Get.snackbar(
          'Success',
          'Shift plan created successfully',
          snackPosition: SnackPosition.BOTTOM,
          animationDuration: Duration(milliseconds: 100),
        );
        final Map<String, dynamic> body = response.data;

        var x = body['sp']['_id'];

        Get.to(ShiftPlanScreen(), arguments: [x]);
      }
    } catch (e) {
      if (e.toString().contains('409')) {
        Get.snackbar(
          'Already Exists',
          'Shift plan already exists for selected date & shift',
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar(
          'Error',
          'Something went wrong while saving shift plan',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isLoadingSp.value = false;
    }
  }

  void postProduction(
    String id,
    int production,
    String timer,
    String feedback,
  ) async {
    final response = await _dio.post(
      '/shift/enter-shift-production',
      data: {
        'production': production,
        'id': id,
        'timer': timer,
        'feedback': feedback,
      },
    );

    if (response.statusCode == 201) {
      // If the server did return a 201 CREATED response,
      // then parse the JSON.
      final Map<String, dynamic> body = response.data;

      getOpenShiftDetail(body['shift']['_id']);
    } else {
      // If the server did not return a 201 CREATED response,
      // then throw an exception.
      throw Exception('Failed to Login.');
    }
  }

  // Five fetches below previously used bare `http.get` / `http.delete`
  // against the hardcoded backend URL, bypassing the JWT cookie
  // interceptor. Route everything through the `_dio` declared at
  // the top of the class (built via ApiClient.buildClient).

  /// The server's own message when it sent one, so a failure says
  /// "shift already closed" rather than a house-brand "Failed to
  /// load". Every catch below used to discard the response entirely.
  String _reason(DioException e, String fallback) {
    final data = e.response?.data;
    final msg = data is Map ? data['message']?.toString() : null;
    if (msg != null && msg.trim().isNotEmpty) return msg;
    return e.message?.trim().isNotEmpty == true ? e.message! : fallback;
  }

  void getWeavingEmployees() async {
    try {
      final res = await _dio.get('/employee/get-employee-weave');
      final body = res.data is Map ? res.data : const {};
      final list = (body['employees'] as List?) ?? const [];
      employeesWeave.value = list
          .whereType<Map>()
          .map((e) => Employee.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      Get.snackbar('Error', _reason(e, 'Failed to load weaving employees'));
    }
  }

  void getShiftPlan(String id) async {
    try {
      final res = await _dio.get('/shift/shiftPlan', queryParameters: {'id': id});
      final body = res.data is Map ? res.data : const {};
      final shift = (body['shift'] as Map?) ?? const {};
      final planList = (shift['plan'] as List?) ?? const [];

      final x = planList
          .whereType<Map>()
          .map((e) => ShiftOpenListModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      shiftPLanRX.value = ShiftPlanModel(
        id: id,
        description: shift['description'],
        production: shift['totalProduction'],
        shift: shift['shift'],
        date: shift['date'],
        plan: x,
      );

      productionData.value = planList
          .whereType<Map>()
          .map((e) => ProductionRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      Get.snackbar('Error', _reason(e, 'Failed to load shift plan'));
    }
  }

  void getOpenShifts() async {
    try {
      final res = await _dio.get('/shift/all-open-shifts');
      final body = res.data is Map ? res.data : const {};
      final list = (body['shifts'] as List?) ?? const [];
      shiftsOpen.value = list
          .whereType<Map>()
          .map((e) => ShiftOpenListModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      Get.snackbar('Error', _reason(e, 'Failed to load open shifts'));
    }
  }

  void deleteShift(String id) async {
    try {
      final res = await _dio.delete('/shift/deletePlan', queryParameters: {'id': id});
      if (res.statusCode == 200) {
        Get.snackbar('Success', 'Deleted Successfully');
      } else {
        Get.snackbar('Failed', 'Not Deleted');
      }
    } catch (e) {
      Get.snackbar('Failed',
          e is DioException ? _reason(e, 'Not Deleted') : 'Not Deleted: $e');
    }
  }

  void getOpenShiftDetail(String id) async {
    try {
      isLoading.value = true;
      final res = await _dio.get('/shift/shiftDetail', queryParameters: {'id': id});
      final body = res.data is Map ? res.data : const {};
      final shift = body['shift'];
      if (shift is Map) {
        shiftDetail.value =
            ShiftDetailModel.fromJson(Map<String, dynamic>.from(shift));
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load shift detail');
    } finally {
      isLoading.value = false;
    }
  }

  // shiftsOpen.value = x;
}

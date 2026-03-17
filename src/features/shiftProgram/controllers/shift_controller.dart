import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
// import 'package:production/src/features/job/controllers/new_job_controller.dart';
// import 'package:production/src/features/job/screens/jobDetailScreen.dart';
import 'package:production/src/features/shiftProgram/models/employee.dart';
import 'package:production/src/features/shiftProgram/models/shiftDetailModel.dart';
import 'package:production/src/features/shiftProgram/models/shiftOpenListModel.dart';
import 'package:production/src/features/shiftProgram/models/shiftPlanlModel.dart';
import 'package:production/src/features/shiftProgram/screens/shiftPlanScreen.dart';
import 'package:production/src/splash_screen.dart';
import 'package:restart_app/restart_app.dart';

import '../models/ProductionDataModel.dart';

class ShiftController extends GetxController {
  static ShiftController get find => Get.find();
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
      final response = await Dio().post(
        'http://13.233.117.153:2701/api/v2/shift/create-shift',
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
    final response = await Dio().post(
      'http://13.233.117.153:2701/api/v2/shift/enter-shift-production',
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

  void getWeavingEmployees() async {
    var url = Uri.parse(
      "http://13.233.117.153:2701/api/v2/employee/get-employee-weave",
    );
    final response = await http.get(
      url,
      headers: {"Content-Type": "application/json"},
    );
    final Map<String, dynamic> body = json.decode(response.body);

    var x = body['employees']
        .map<Employee>((e) => Employee.fromJson(e))
        .toList();

    employeesWeave.value = x;
  }

  void getShiftPlan(String id) async {
    var url = Uri.parse(
      "http://13.233.117.153:2701/api/v2/shift/shiftPlan?id=$id",
    );
    final response = await http.get(
      url,
      headers: {"Content-Type": "application/json"},
    );
    final Map<String, dynamic> body = json.decode(response.body);

    var x = body['shift']['plan']
        .map<ShiftOpenListModel>((e) => ShiftOpenListModel.fromJson(e))
        .toList();

    var sPlan = ShiftPlanModel(
      id: id,
      description: body['shift']['description'],
      production: body['shift']['totalProduction'],
      shift: body['shift']['shift'],
      date: body['shift']['date'],
      plan: x,
    );

    productionData.value = body['shift']['plan']
        .map<ProductionRow>((e) => ProductionRow.fromJson(e))
        .toList();

    shiftPLanRX.value = sPlan;

    // shiftsOpen.value = x;
  }

  void getOpenShifts() async {
    var url = Uri.parse(
      "http://13.233.117.153:2701/api/v2/shift/all-open-shifts",
    );
    final response = await http.get(
      url,
      headers: {"Content-Type": "application/json"},
    );
    final Map<String, dynamic> body = json.decode(response.body);

    var x = body['shifts']
        .map<ShiftOpenListModel>((e) => ShiftOpenListModel.fromJson(e))
        .toList();

    shiftsOpen.value = x;
  }

  void deleteShift(String id) async {
    try {
      var url = Uri.parse(
        "http://13.233.117.153:2701/api/v2/shift/deletePlan?id=" + id,
      );
      final response = await http.delete(
        url,
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
       // Get.to(SplashPage());
        Get.snackbar("Success", "Deleted Successfully");
        // exit(0);
      }
    } catch (e) {
      Get.snackbar("Failed", "Not Deleteed ");
    }
  }

  void getOpenShiftDetail(String id) async {
    try {
      isLoading.value = true;

      var url = Uri.parse(
        "http://13.233.117.153:2701/api/v2/shift/shiftDetail?id=$id",
      );
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );
      final Map<String, dynamic> body = json.decode(response.body);

      shiftDetail.value = ShiftDetailModel.fromJson(body['shift']);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load machines');
    } finally {
      isLoading.value = false;
    }
  }

  // shiftsOpen.value = x;
}

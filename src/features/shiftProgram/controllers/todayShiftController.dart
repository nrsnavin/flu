import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:production/src/features/shiftProgram/models/shiftPlanlModel.dart';


class TodayShiftController extends GetxController {
  var isLoading = true.obs;

  Rx<ShiftPlanModel> dayShiftPLanRX = ShiftPlanModel(


    description: "open",

    shift: "12",
    date: DateTime.now().toString(),
    id: "test",

    production: 0, plan: [],
  ).obs;
  Rx<ShiftPlanModel> nightShiftPLanRX = ShiftPlanModel(

    plan: [],
    description: "open",

    shift: "12",
    date: DateTime.now().toString(),
    id: "test",

    production: 0,
  ).obs;

  @override
  void onInit() {
    fetchTodayShiftPlans();
    super.onInit();
  }

  Future<void> fetchTodayShiftPlans() async {
    try {
      isLoading.value = true;

      var url = Uri.parse(
        "http://13.233.117.153:2701/api/v2/shift/shiftPlanToday?date=${DateTime.now().toString()}",
      );
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );
      final Map<String, dynamic> body = json.decode(response.body);

      final data = body['shift'];

      List<dynamic> x = data
          .map<ShiftPlanModel>((e) => ShiftPlanModel.fromJson(e))
          .toList();

      for (ShiftPlanModel ele in x) {
        if(ele.shift=="DAY"){
          dayShiftPLanRX.value= ele;
        }

        if(ele.shift=="NIGHT"){
          nightShiftPLanRX.value=ele;
        }
      }

      // nightShift.value = data['NIGHT'];

    } catch (e) {
      Get.snackbar('Error', 'Failed to load shift plans');
    } finally {
      isLoading.value = false;
    }
  }
}

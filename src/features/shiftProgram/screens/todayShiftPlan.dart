import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../common_widgets/appBar.dart';
import '../controllers/shift_controller.dart';

class TodayShiftsScreen extends StatefulWidget {
  const TodayShiftsScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _TodayShiftsScreen();
  }
}

class _TodayShiftsScreen extends State<TodayShiftsScreen> {
  final shiftController = Get.put(ShiftController());

  void dispose() {
    // Dispose all controllers

    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            NAppBar(showBackArrow: false),

         buildWidget(context)
          ],
        ),
      ),
    );
  }

  Widget buildWidget(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Container(child: Text("data"))],
      ),
    );
  }
}

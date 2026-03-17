import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:production/src/common_widgets/appBar.dart';
import 'package:production/src/features/shiftProgram/screens/pdfScr.dart';
import 'package:production/src/features/shiftProgram/screens/shiftDetailScreen.dart';

import '../controllers/shift_controller.dart';
import '../models/shiftPlanlModel.dart';

class ShiftPlanScreen extends StatefulWidget {
  const ShiftPlanScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ShiftPlanScreen();
  }
}

class _ShiftPlanScreen extends State<ShiftPlanScreen> {
  final shiftController = Get.put(ShiftController());

  var args = Get.arguments;

  @override
  void initState() {
    // TODO: implement initState

    shiftController.getShiftPlan(
      args != null ? args[0] : "6970f9e6647e64e5ffee571a",
    );

    super.initState();
  }
  // Source - https://stackoverflow.com/a
  // Posted by Zia, modified by community. See post 'Timeline' for change history
  // Retrieved 2026-01-18, License - CC BY-SA 4.0

  @override
  Widget build(BuildContext context) {
    // _printScreen();
    // shiftController.getShiftPlan(args!=null ?args[0]: "6970f9e6647e64e5ffee571a");
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => shiftController.getShiftPlan(args[0]),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              NAppBar(
                showBackArrow: true,
                actions: [
                  TextButton(
                    onPressed: () => {
                      Get.to(
                        AnuTapesProductionPdf(),
                        arguments: [
                          shiftController.shiftDetail.value.date,
                          shiftController.shiftDetail.value.shift,
                        ],
                      ),
                    },
                    child: const Text("View Report"),
                  ),
                ],
              ),
              Obx(
                () => buildWidget(shiftController.shiftPLanRX.value, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildWidget(ShiftPlanModel sDetail, BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      "Date-",
                    ),
                    Text(
                      style: const TextStyle(fontSize: 18),
                      DateFormat(
                        "dd-MM-yyyy",
                      ).format(DateTime.parse(sDetail.date).toLocal()),
                    ),
                  ],
                ),

                Row(
                  children: [
                    const Text(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      "Shift-",
                    ),
                    Text(style: const TextStyle(fontSize: 18), sDetail.shift),
                  ],
                ),

                Row(
                  children: [
                    const Text(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      "Production-",
                    ),
                    Text(
                      style: const TextStyle(fontSize: 18),
                      sDetail.production.toString(),
                    ),
                  ],
                ),

                Row(
                  children: [
                    const Text(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      "Description-",
                    ),
                    Text(
                      style: const TextStyle(fontSize: 18),
                      sDetail.description,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            "Machines Running",
          ),
          Table(
            border: TableBorder.all(width: 2),
            children: [
              TableRow(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "ID",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Operator",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Elastics",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Production",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Actions",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              for (int i = 0; i < sDetail.plan.length; i++)
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey),
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(sDetail.plan[i].machine),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(sDetail.plan[i].employee),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(sDetail.plan[i].elastic),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(sDetail.plan[i].production.toString()),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextButton(
                          onPressed: () {
                            Get.to(
                              ShiftDetailScreen(),
                              arguments: [sDetail.plan[i].id],
                            );
                          },
                          child: Text("view"),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(

            child: Text("Delete The PLan",style: TextStyle(color: Colors.white),),
            style:  ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed:  () {
              _showDeleteConfirm();
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );


  }

  void _showDeleteConfirm() {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Get.back(); // close dialog
              shiftController.deleteShift(args[0]);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

}






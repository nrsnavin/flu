import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_time_duration_picker/flutter_time_duration_picker.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/common_widgets/appBar.dart';
// import 'package:production/src/features/elastics/screens/elasticDetailScreen.dart';
import 'package:production/src/features/shiftProgram/models/shiftDetailModel.dart';

import '../controllers/shift_controller.dart';

class ShiftDetailScreen extends StatefulWidget {
  const ShiftDetailScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ShiftDetailScreen();
  }
}

class _ShiftDetailScreen extends State<ShiftDetailScreen> {
  final shiftController = Get.put(ShiftController());

  final feedbackController = TextEditingController();
  final productionController = TextEditingController();

   TimeColumnController hourController=TimeColumnController(
    initialValue: 0,
    minValue: 0,
    maxValue: 23,
  );
   TimeColumnController minuteController=TimeColumnController(
    initialValue: 0,
    minValue: 0,
    maxValue: 59,
  );
   TimeColumnController secondsController=TimeColumnController(
    initialValue: 0,
    minValue: 0,
    maxValue: 59,
  );

  String timer = "";

  void dispose() {
    // Dispose all controllers

    super.dispose();
  }

  var args = Get.arguments;

  @override
  void initState() {
    // TODO: implement initState

    shiftController.getOpenShiftDetail(args[0]);


    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: ()async=>shiftController.getOpenShiftDetail(args[0]),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              NAppBar(showBackArrow: true),
              Obx(
                () {
                  if(shiftController.isLoading.value){
                    return const Center(child: CircularProgressIndicator());
                  }
                  else{
        
                    return RefreshIndicator(
                      onRefresh: () async => shiftController.getOpenShiftDetail(args[0]),
                      child: Container(
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
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        "Date-",
                                      ),
                                      Text(
                                        style: const TextStyle(fontSize: 18),
                                        DateFormat("dd-MM-yyyy").format(
                                          DateTime.parse(
                                            shiftController.shiftDetail.value.date,
                                          ).toLocal(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),
                                  Row(
                                    children: [
                                      const Text(
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        "Employee-",
                                      ),
                                      Text(
                                        style: const TextStyle(fontSize: 18),
                                        shiftController.shiftDetail.value.employee
                                            .toString(),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),
                                  Row(
                                    children: [
                                      const Text(
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        "Machine-",
                                      ),
                                      Text(
                                        style: const TextStyle(fontSize: 18),
                                        shiftController.shiftDetail.value.machine
                                            .toString(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Text(
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        "Shift-",
                                      ),
                                      Text(
                                        style: const TextStyle(fontSize: 18),
                                        shiftController.shiftDetail.value.shift,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
        
                                  SizedBox(height: 15),
                                  Row(
                                    children: [
                                      const Text(
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        "Production-",
                                      ),
                                      Text(
                                        style: const TextStyle(fontSize: 18),
                                        shiftController.shiftDetail.value.production
                                            .toString(),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),
                                  Row(
                                    children: [
                                      const Text(
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        "Description-",
                                      ),
                                      Text(
                                        style: const TextStyle(fontSize: 18),
                                        shiftController.shiftDetail.value.description,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 15),
                            Row(
                              children: [
                                const Text(
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  "Elastic Running-",
                                ),
                                Text(
                                  style: const TextStyle(fontSize: 18),
                                  shiftController.shiftDetail.value.elastics,
                                ),
                              ],
                            ),
        
                            const SizedBox(height: 20),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      shiftController.shiftDetail.value.status == "open"
                                          ? ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          enableFeedback: true,
                                          backgroundColor: Colors.black,
                                          textStyle: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () {
                                          showModalBottomSheet<void>(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return Container(
                                                height: MediaQuery.sizeOf(
                                                  context,
                                                ).height,
                                                width:  MediaQuery.sizeOf(
                                                  context,
                                                ).width-20,
                                                color: Colors.amber,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    const Text(
                                                      'Enter Production',
                                                      style: TextStyle(
                                                        color: Colors.redAccent,
                                                        fontSize: 20,
                                                        fontWeight:
                                                        FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: MediaQuery.sizeOf(
                                                        context,
                                                      ).width-50,
                                                      child: TextFormField(
                                                        controller:
                                                        productionController,
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            return 'Please enter some text';
                                                          }
                                                          return null;
                                                        },
                                                        keyboardType:
                                                        TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: "Production",
                                                          hintText:
                                                          "Enter Production in Meters",
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                            BorderRadius.all(
                                                              Radius.circular(
                                                                2,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 10),
        
                                                    TimeDurationPicker(
                                                      height: 150,
                                                      columns: [
                                                        TimeColumnConfig.hours(
                                                          controller:
                                                          hourController,
                                                          separator: ':',
                                                        ),
                                                        TimeColumnConfig.minutes(
                                                          controller:
                                                          minuteController,
                                                          separator: ':',
                                                        ),
                                                        TimeColumnConfig.seconds(
                                                          controller:
                                                          secondsController,
                                                        ),
                                                      ],
                                                      onChanged: (values) {
                                                        setState(() {
                                                          timer =
                                                              hourController.value
                                                                  .toString() +
                                                                  ":" +
                                                                  minuteController
                                                                      .value
                                                                      .toString() +
                                                                  ":" +
                                                                  secondsController
                                                                      .value
                                                                      .toString();
                                                        });
                                                      },
                                                    ),
        
                                                    const SizedBox(height: 8),
        
                                                    SizedBox(
                                                      width: MediaQuery.sizeOf(
                                                        context,
                                                      ).width-50,
                                                      child: TextFormField(
                                                        controller:
                                                        feedbackController,
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            return 'Please enter some text';
                                                          }
                                                          return null;
                                                        },
        
                                                        decoration: const InputDecoration(
                                                          labelText: "FeedBack",
                                                          hintText:
                                                          "Enter Feedback ",
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                            BorderRadius.all(
                                                              Radius.circular(
                                                                2,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 25),
                                                    ElevatedButton(
                                                      child: const Text(
                                                        "Enter Production",
                                                      ),
                                                      onPressed: () {
                                                        shiftController
                                                            .postProduction(
                                                          shiftController
                                                              .shiftDetail
                                                              .value
                                                              .id,
                                                          int.parse(productionController
                                                              .value
                                                              .text)
                                                          ,
                                                          timer,
                                                          feedbackController
                                                              .value
                                                              .text,
                                                        );
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: const Text(
                                          style: TextStyle(color: Colors.white),
                                          "Add Production",
                                        ),
                                      )
                                          : Text("Shift Closed"),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
        
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}

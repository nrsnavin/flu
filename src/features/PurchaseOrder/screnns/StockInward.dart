import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class StockInwardPage extends StatelessWidget {
  final String poId = Get.arguments;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://10.0.2.2:2701/api/v2", // 🔁 CHANGE
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stock Inward")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _dio.post("/inward-stock",data:  {
              "poId": poId,
              "items": [
                {
                  "rawMaterial": "id",
                  "quantity": 50
                }
              ]
            });

            Get.snackbar("Success", "Stock Updated");
          },
          child: const Text("Submit Inward"),
        ),
      ),
    );
  }
}

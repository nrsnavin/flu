import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import '../../../core/api_client.dart';

class StockInwardPage extends StatelessWidget {
  final String poId = Get.arguments;

  final Dio _dio = ApiClient.buildClient(baseUrl: "http://10.0.2.2:2701/api/v2");

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

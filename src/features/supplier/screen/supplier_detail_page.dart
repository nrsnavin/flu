import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

import '../services/api_service.dart';
import 'edit_supplier_page.dart';

class SupplierDetailPage extends StatelessWidget {
  final Map supplier;
  SupplierDetailPage({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supplier["name"]),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              Get.defaultDialog(
                title: "Delete Supplier?",
                middleText: "This action cannot be undone",
                confirm: ElevatedButton(
                  onPressed: () async {
                    await SupplierApiService.dio.delete(
                      "/delete-supplier",
                      queryParameters: {"id": supplier["_id"]},
                    );
                    Get.back(); // dialog
                    Get.back(result: true); // page
                  },
                  child: const Text("Delete"),
                ),
                cancel: TextButton(
                  onPressed: Get.back,
                  child: const Text("Cancel"),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("GSTIN: ${supplier["gstin"]}"),
          Text("Phone: ${supplier["phoneNumber"]}"),
          Text("Email: ${supplier["email"] ?? "-"}"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final res = await Get.to(
                    () => EditSupplierPage(supplier: supplier),
              );
              if (res == true) Get.back(result: true);
            },
            child: const Text("Edit Supplier"),
          ),
        ],
      ),
    );
  }
}

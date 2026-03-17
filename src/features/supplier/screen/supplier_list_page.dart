import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:production/src/features/supplier/screen/supplier_detail_page.dart';

import '../controller/supplier_list_controller.dart';
import 'add_supplier_page.dart';

class SupplierListPage extends StatelessWidget {
  final c = Get.put(SupplierListController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Suppliers")),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Get.to(() => AddSupplierPage());
          if (res == true) c.fetchSuppliers();
        },
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: c.suppliers.length,
          itemBuilder: (_, i) {
            final s = c.suppliers[i];
            return Card(
              child: ListTile(
                title: Text(s["name"]),
                subtitle: Text(s["contactPerson"]),
                onTap: () async {
                  final res = await Get.to(
                        () => SupplierDetailPage(supplier: s),
                  );
                  if (res == true) c.fetchSuppliers();
                },
              ),
            );
          },
        );
      }),
    );
  }
}

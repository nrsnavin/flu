import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/add_supplier_controller.dart';


class AddSupplierPage extends StatelessWidget {
  AddSupplierPage({super.key});

  final c = Get.put(AddSupplierController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Supplier")),
      body: Obx(() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: "Supplier Name *",
              ),
              onChanged: (v) => c.nameCtrl.value = v,
            ),

            const SizedBox(height: 12),

            TextField(
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number *",
              ),
              onChanged: (v) => c.phoneCtrl.value = v,
            ),

            const SizedBox(height: 12),

            TextField(
              decoration: const InputDecoration(
                labelText: "GSTIN *",
                hintText: "15 character GSTIN",
              ),
              onChanged: (v) => c.gstinCtrl.value = v,
            ),

            const SizedBox(height: 12),

            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
              ),
              onChanged: (v) => c.emailCtrl.value = v,
            ),

            const SizedBox(height: 12),

            TextField(
              decoration: const InputDecoration(
                labelText: "Contact Person",
              ),
              onChanged: (v) => c.contactPersonCtrl.value = v,
            ),

            const SizedBox(height: 12),

            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Address",
              ),
              onChanged: (v) => c.addressCtrl.value = v,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: c.loading.value ? null : c.submit,
                child: c.loading.value
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text("Save Supplier"),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

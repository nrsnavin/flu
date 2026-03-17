import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/edit_supplier_controller.dart';


class EditSupplierPage extends StatelessWidget {
  final Map supplier;

  const EditSupplierPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EditSupplierController(supplier));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Supplier"),
      ),
      body: Obx(() {
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field("Supplier Name", c.nameCtrl),
                _field("Contact Name", c.contactCtrl),
                _field("Phone Number", c.phoneCtrl,
                    keyboard: TextInputType.phone),
                _field("Email", c.emailCtrl,
                    keyboard: TextInputType.emailAddress),
                _field("GSTIN", c.gstinCtrl),

                const SizedBox(height: 12),

                const Text("Payment Terms"),
                const SizedBox(height: 4),
                Obx(() => DropdownButtonFormField<String>(
                  value: c.paymentTerms.value,
                  items: c.paymentOptions
                      .map(
                        (e) => DropdownMenuItem(
                      value: e,
                      child: Text("$e Days"),
                    ),
                  )
                      .toList(),
                  onChanged: (v) => c.paymentTerms.value = v!,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                )),

                const SizedBox(height: 12),

                const Text("Status"),
                const SizedBox(height: 4),
                Obx(() => DropdownButtonFormField<String>(
                  value: c.status.value,
                  items: c.statusOptions
                      .map(
                        (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ),
                  )
                      .toList(),
                  onChanged: (v) => c.status.value = v!,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                )),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: c.updateSupplier,
                  child: const Text("Update Supplier"),
                ),
              ],
            ),

            if (c.loading.value)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      }),
    );
  }

  Widget _field(
      String label,
      TextEditingController ctrl, {
        TextInputType keyboard = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

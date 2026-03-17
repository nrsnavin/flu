import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/customer/screens/edit_customer_page.dart';
import '../controllers/customerDetailController.dart';



class CustomerDetailPageLegacy extends StatelessWidget {
  final String customerId;



  const CustomerDetailPageLegacy({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final controller =
    Get.put(CustomerDetailController(customerId: customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Get.to(() => EditCustomerPage(customer: controller.customer));
            },
          ),

        ],
      ),

      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final c = controller.customer;
        if (c.isEmpty) {
          return const Center(child: Text("Customer not found"));
        }

        return RefreshIndicator(
          onRefresh: controller.fetchCustomer,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(c),
                const SizedBox(height: 16),

                _section("Primary Contact", [
                  _row("Contact Name", c['contactName']),
                  _row("Phone", c['phoneNumber']),
                  _row("Email", c['email']),
                ]),

                _section("Commercial", [
                  _row("GSTIN", c['gstin']),
                  _row("Payment Terms", "${c['paymentTerms']} Days"),
                  _row("Status", c['status']),
                ]),

                _contactSection("Purchase", c['purchase']),
                _contactSection("Accounts", c['accountant']),
                _contactSection("Merchandiser", c['merchandiser']),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _header(Map c) {
    final active = c['status'] == "Active";
    return Card(
      child: ListTile(
        title: Text(
          c['name'],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Created: ${c['createdAt']?.toString().split('T')[0]}"),
        trailing: Chip(
          label: Text(c['status']),
          backgroundColor:
          active ? Colors.green.shade100 : Colors.red.shade100,
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _contactSection(String title, Map? data) {
    if (data == null || data.isEmpty) return const SizedBox();

    return _section(title, [
      _row("Name", data['name']),
      _row("Mobile", data['mobile']),
      _row("Email", data['email']),
    ]);
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 5,
            child: Text(value?.isNotEmpty == true ? value! : "-"),
          ),
        ],
      ),
    );
  }
}


// void _confirmDelete(CustomerDetailController controller) {
//   Get.defaultDialog(
//     title: "Delete Customer",
//     middleText: "This action cannot be undone.\nAre you sure?",
//     confirm: ElevatedButton(
//       style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//       onPressed: () async {
//         // await controller.deleteCustomer();
//         Get.back(); // close dialog
//         Get.back(); // back to list
//       },
//       child: const Text("Delete"),
//     ),
//     cancel: TextButton(
//       onPressed: Get.back,
//       child: const Text("Cancel"),
//     ),
//   );
// }

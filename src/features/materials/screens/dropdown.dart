import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/supplier_controller.dart';

class SearchableSupplierDropdown extends StatefulWidget {
  final Function(String id) onSelected;

  const SearchableSupplierDropdown({super.key, required this.onSelected});

  @override
  State<SearchableSupplierDropdown> createState() =>
      _SearchableSupplierDropdownState();
}

class _SearchableSupplierDropdownState
    extends State<SearchableSupplierDropdown> {
  final SupplierController controller = Get.put(SupplierController());
  String? selectedSupplierName;

  @override
  void initState() {
    super.initState();
    controller.fetchSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openBottomSheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "Supplier",
          border: OutlineInputBorder(),
        ),
        child: Text(
          selectedSupplierName ?? "Select Supplier",
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: "Search supplier...",
                ),
                onChanged: (v) => controller.fetchSuppliers(search: v),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    itemCount: controller.suppliers.length,
                    itemBuilder: (_, i) {
                      final s = controller.suppliers[i];
                      return ListTile(
                        title: Text(s["name"]),
                        onTap: () {
                          widget.onSelected(s["_id"]);
                          setState(() => selectedSupplierName = s["name"]);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              )
            ],
          ),
        );
      },
    );
  }
}

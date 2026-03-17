// import 'package:get/get_core/src/get_main.dart';
//
// import '../services/api_service.dart';
//
// class AddPurchaseOrderController extends GetxController {
//   final suppliers = <Map<String, dynamic>>[].obs;
//   final materials = <Map<String, dynamic>>[].obs;
//
//   final selectedSupplier = Rxn<Map>();
//   final rows = <Map<String, dynamic>>[].obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     fetchSuppliers();
//     fetchMaterials();
//     addRow();
//   }
//
//   void addRow() {
//     rows.add({
//       "material": null,
//       "quantity": 0.0,
//       "price": 0.0,
//     });
//   }
//
//   Future<void> submit() async {
//     final payload = rows
//         .where((r) => r["material"] != null && r["quantity"] > 0)
//         .map((r) => {
//       "rawMaterial": r["material"]["_id"],
//       "quantity": r["quantity"],
//       "price": r["price"],
//     })
//         .toList();
//
//     await SupplierApiService.dio.post("/create-po", data: {
//       "supplier": selectedSupplier.value!["_id"],
//       "materials": payload,
//     });
//
//     Get.back(result: true);
//   }
// }

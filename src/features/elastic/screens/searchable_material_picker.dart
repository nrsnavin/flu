import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/elastic/controllers/add_elastic_controller.dart';
import 'package:production/src/features/elastic/models/raw_material.dart';


import '../../PurchaseOrder/services/theme.dart';

void showMaterialPicker({
  required String title,
  required List<RawMaterialMini> materials,
  required Function(RawMaterialMini) onSelected,
}) {
  final c = Get.find<AddElasticController>();
  c.searchQuery.value = "";

  Get.bottomSheet(
    _MaterialPickerSheet(
      title: title,
      materials: materials,
      controller: c,
      onSelected: (m) {
        onSelected(m);
        Get.back();
      },
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _MaterialPickerSheet extends StatelessWidget {
  final String title;
  final List<RawMaterialMini> materials;
  final AddElasticController controller;
  final Function(RawMaterialMini) onSelected;

  const _MaterialPickerSheet({
    required this.title,
    required this.materials,
    required this.controller,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ErpColors.borderMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close,
                      color: ErpColors.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: (v) => controller.searchQuery.value = v,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search materials…",
                  hintStyle: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: ErpColors.textMuted),
                  filled: true,
                  fillColor: ErpColors.bgMuted,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: ErpColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: ErpColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: ErpColors.accentBlue, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          // Material count
          Obx(() {
            final count =
                controller.filteredMaterials(materials).length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    "$count material${count == 1 ? '' : 's'}",
                    style: const TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
          // List
          Expanded(
            child: Obx(() {
              final filtered =
              controller.filteredMaterials(materials);
              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 32, color: ErpColors.textMuted),
                      SizedBox(height: 8),
                      Text("No materials found",
                          style: TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 14)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final m = filtered[i];
                  return GestureDetector(
                    onTap: () => onSelected(m),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: ErpColors.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border:
                        Border.all(color: ErpColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: ErpColors.navyDark.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                              ErpColors.accentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.line_axis,
                                size: 18, color: ErpColors.accentBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: ErpColors.textPrimary),
                                    overflow: TextOverflow.ellipsis),
                                Text(m.category,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: ErpColors.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ErpColors.statusCompletedBg,
                              border: Border.all(
                                  color:
                                  ErpColors.statusCompletedBorder),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "₹${m.price}/kg",
                              style: const TextStyle(
                                  color: ErpColors.successGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
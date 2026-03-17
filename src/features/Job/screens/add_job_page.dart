import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/Job/controllers/add_job_controller.dart';
import 'package:production/src/features/Job/models/order_model.dart';


import '../../PurchaseOrder/services/theme.dart';

class AddJobOrderPage extends StatefulWidget {
  final OrderModel order;
  const AddJobOrderPage({super.key, required this.order});

  @override
  State<AddJobOrderPage> createState() => _AddJobOrderPageState();
}

class _AddJobOrderPageState extends State<AddJobOrderPage> {
  late final AddJobOrderController _c;

  @override
  void initState() {
    super.initState();
    Get.delete<AddJobOrderController>(force: true);
    _c = Get.put(AddJobOrderController(
      onSuccess: () => Navigator.of(context).pop(true),
    ));
    _c.initFromOrder(widget.order);
  }

  @override
  void dispose() {
    Get.delete<AddJobOrderController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Create Job Order", style: ErpTextStyles.pageTitle),
            Text(
              "Order #${widget.order.orderNo}  ›  New Job",
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_c.elasticInputs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_outlined,
                            size: 48, color: ErpColors.textMuted),
                        SizedBox(height: 12),
                        Text("No pending elastics",
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text("All elastics are fulfilled for this order",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: ErpColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: ErpColors.statusApprovedBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: ErpColors.statusApprovedBorder),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: ErpColors.accentBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Enter qty to allocate to this job. Cannot exceed pending quantity. Leave blank to skip an elastic.",
                            style: const TextStyle(
                                color: ErpColors.accentBlue,
                                fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Elastic cards
                    ErpSectionCard(
                      title: "ELASTIC ALLOCATION",
                      icon: Icons.layers_outlined,
                      child: Column(
                        children:
                        _c.elasticInputs.asMap().entries.map((entry) {
                          final i   = entry.key;
                          final e   = entry.value;
                          return _ElasticAllocationRow(
                              index: i, input: e);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Order reference card
                    ErpSectionCard(
                      title: "JOB WILL CREATE",
                      icon: Icons.account_tree_outlined,
                      child: const Column(
                        children: [
                          _ProcessRow(
                              icon: Icons.grain_outlined,
                              label: "Warping Program",
                              description:
                              "Auto-created for warp yarn preparation"),
                          SizedBox(height: 8),
                          _ProcessRow(
                              icon: Icons.loop_outlined,
                              label: "Covering Program",
                              description:
                              "Auto-created for spandex covering"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          _FooterBar(c: _c),
        ],
      ),
    );
  }
}

// ── Single elastic row ──────────────────────────────────────────
class _ElasticAllocationRow extends StatelessWidget {
  final int index;
  final ElasticInput input;
  const _ElasticAllocationRow({required this.index, required this.input});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text("${index + 1}",
                style: const TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(input.elasticName,
                    style: ErpTextStyles.cardTitle,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.pending_outlined,
                      size: 12, color: ErpColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    "Pending: ${input.maxQty} m",
                    style: const TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: input.qtyController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Qty (m)",
                labelStyle: ErpTextStyles.fieldLabel,
                filled: true,
                fillColor: ErpColors.bgSurface,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                    const BorderSide(color: ErpColors.borderLight)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                    const BorderSide(color: ErpColors.borderLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                        color: ErpColors.accentBlue, width: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Process info row ───────────────────────────────────────────
class _ProcessRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  const _ProcessRow(
      {required this.icon,
        required this.label,
        required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: ErpColors.accentBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 17, color: ErpColors.accentBlue),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ErpColors.textPrimary)),
            Text(description,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
      const Icon(Icons.auto_awesome,
          size: 14, color: ErpColors.successGreen),
    ]);
  }
}

// ── Footer ─────────────────────────────────────────────────────
class _FooterBar extends StatelessWidget {
  final AddJobOrderController c;
  const _FooterBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: const Border(top: BorderSide(color: ErpColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Obx(() => SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: c.isSubmitting.value ? null : c.submitJobOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                disabledBackgroundColor:
                ErpColors.accentBlue.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: c.isSubmitting.value
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16, color: Colors.white),
              label: Text(
                c.isSubmitting.value ? "Creating…" : "Create Job",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          )),
        ),
      ]),
    );
  }
}
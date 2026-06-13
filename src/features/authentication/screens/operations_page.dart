import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/nav_registry.dart';

/// "What's happening on the floor right now" — groups Production and
/// Shift Management modules. Pulled out of the More waterfall so daily
/// operators land one tap away from Warping, Shift, Wastage, etc.
class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  static const _sections = ['PRODUCTION', 'SHIFT MANAGEMENT'];

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: 'Operations', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          for (final s in _sections)
            _SectionBlock(title: s, modules: reg.modulesInSection(s)),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final List<NavModule> modules;
  const _SectionBlock({required this.title, required this.modules});

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionLabel(text: title),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (_, i) => ModuleTile(module: modules[i]),
          ),
        ],
      ),
    );
  }
}

/// Compact module tile — shared by Operations, Catalog and More.
class ModuleTile extends StatelessWidget {
  final NavModule module;
  const ModuleTile({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => reg.open(module.id),
        onLongPress: () => reg.togglePin(module.id),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ErpColors.borderLight),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(module.icon,
                    color: ErpColors.accentBlue, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                module.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ErpColors.textPrimary,
                ),
              ),
              Obx(() {
                if (!reg.pinned.contains(module.id)) {
                  return const SizedBox.shrink();
                }
                return const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.push_pin_rounded,
                      size: 11, color: ErpColors.accentBlue),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

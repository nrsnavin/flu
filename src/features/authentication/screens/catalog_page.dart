import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/nav_registry.dart';
import 'operations_page.dart' show ModuleTile;

/// Catalogue tab — the master file side of the app. Customers, Orders,
/// Suppliers, Purchase Orders, Packing/Shipping. Mirrors the Operations
/// page layout so muscle memory carries.
class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  static const _sections = [
    'CUSTOMERS & ORDERS',
    'PACKING & SHIPPING',
    'PEOPLE',
  ];

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: 'Catalogue', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          for (final s in _sections) ...[
            ErpSectionLabel(text: s),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reg.modulesInSection(s).length,
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (_, i) => ModuleTile(
                module: reg.modulesInSection(s)[i],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

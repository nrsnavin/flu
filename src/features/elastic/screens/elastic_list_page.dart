import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/elastic/controllers/elastic_list_controller.dart';
import 'package:production/src/features/elastic/models/elastic_list_model.dart';
import 'package:production/src/features/elastic/screens/elastic_detail_page.dart';


import '../../PurchaseOrder/services/theme.dart';
import 'addElastic.dart';

// FIX: StatefulWidget so the controller and scroll listener are created
//      once in initState and disposed cleanly — not at class-field level
//      in a StatelessWidget where there's no lifecycle control.
class ElasticListPage extends StatefulWidget {
  const ElasticListPage({super.key});

  @override
  State<ElasticListPage> createState() => _ElasticListPageState();
}

class _ElasticListPageState extends State<ElasticListPage> {
  late final ElasticListController _c;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Get.delete<ElasticListController>(force: true);
    _c = Get.put(ElasticListController());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _c.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text("Elastics",
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          Obx(() => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "${_c.elastics.length} items",
                style: const TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 12),
              ),
            ),
          )),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Elastic",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () async {
          final res = await Get.to(() => AddElasticPage());
          if (res == true) _c.fetchElastics(reset: true);
        },
      ),
      body: Column(
        children: [
          _SearchBar(c: _c),
          Expanded(child: _Body(c: _c, scroll: _scroll)),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ElasticListController c;
  const _SearchBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border(bottom: BorderSide(color: ErpColors.borderLight))),
      child: SizedBox(
        height: 40,
        child: TextField(
          onChanged: c.onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search elastics…",
            hintStyle: const TextStyle(
                color: ErpColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                size: 19, color: ErpColors.textMuted),
            filled: true,
            fillColor: ErpColors.bgMuted,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
              const BorderSide(color: ErpColors.accentBlue, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ElasticListController c;
  final ScrollController scroll;
  const _Body({required this.c, required this.scroll});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.loading.value && c.elastics.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.elastics.isEmpty) {
        return _EmptyState(onRefresh: () => c.fetchElastics(reset: true));
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetchElastics(reset: true),
        child: ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: c.elastics.length + (c.hasMore.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == c.elastics.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(
                        color: ErpColors.accentBlue)),
              );
            }
            return _ElasticCard(e: c.elastics[i]);
          },
        ),
      );
    });
  }
}

class _ElasticCard extends StatelessWidget {
  final ElasticListModel e;
  const _ElasticCard({required this.e});

  @override
  Widget build(BuildContext context) {
    final hasStock   = e.stock > 0;
    final stockColor = hasStock ? ErpColors.successGreen : ErpColors.errorRed;
    final stockBg    = hasStock
        ? ErpColors.statusCompletedBg
        : const Color(0xFFFEF2F2);
    final stockBorder = hasStock
        ? ErpColors.statusCompletedBorder
        : const Color(0xFFFECACA);

    return GestureDetector(
      onTap: () => Get.to(() => ElasticDetailPage(elasticId: e.id)),
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.layers_outlined,
                        size: 20, color: ErpColors.accentBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ErpColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        Text("Weave Type: ${e.weaveType}",
                            style: const TextStyle(
                                fontSize: 12,
                                color: ErpColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: stockBg,
                      border: Border.all(color: stockBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${e.stock.toStringAsFixed(1)} m",
                      style: TextStyle(
                          color: stockColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
              decoration: const BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(8)),
                border:
                Border(top: BorderSide(color: ErpColors.borderLight)),
              ),
              child: Row(
                children: [
                  Icon(
                    hasStock
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 13,
                    color: stockColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    hasStock ? "In Stock" : "Out of Stock",
                    style: TextStyle(
                        color: stockColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 16, color: ErpColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.layers_outlined,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text("No Elastics Found",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text("Tap + to create your first elastic",
              style:
              TextStyle(color: ErpColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid)),
            icon: const Icon(Icons.refresh,
                size: 16, color: ErpColors.textSecondary),
            label: const Text("Refresh",
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
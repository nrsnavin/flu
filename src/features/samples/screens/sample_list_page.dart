import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/sample_controllers.dart';
import '../models/sample.dart';
import 'raise_sample_page.dart';
import 'sample_detail_page.dart';

// ══════════════════════════════════════════════════════════════
//  SAMPLE REQUESTS — the list
//
//  A row leads with the LAST thing that happened rather than the title
//  and a date, because a list of titles makes people open all of them
//  to find the one that moved.
// ══════════════════════════════════════════════════════════════
class SampleListPageView extends StatefulWidget {
  const SampleListPageView({super.key});

  @override
  State<SampleListPageView> createState() => _SampleListPageViewState();
}

class _SampleListPageViewState extends State<SampleListPageView> {
  late final SampleListController c;

  @override
  void initState() {
    super.initState();
    // In build(), Get.put would re-register the controller on every
    // rebuild and re-run onInit — a fetch per frame.
    c = Get.put(SampleListController());
  }

  @override
  void dispose() {
    Get.delete<SampleListController>(force: true);
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Sample Requests", style: ErpTextStyles.pageTitle),
            Obx(() => Text(
                  c.total.value == 1 ? "1 request" : "${c.total.value} requests",
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10),
                )),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
            onPressed: c.fetch,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: const Text("Raise sample",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const RaiseSamplePage()),
          );
          if (created == true) c.fetch();
        },
      ),
      body: Column(
        children: [
          _SearchAndFilters(c: c),
          Expanded(
            child: Obx(() {
              if (c.loading.value && c.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.errorMsg.value != null) {
                return _Message(
                  icon: Icons.error_outline,
                  title: "Could not load",
                  body: c.errorMsg.value!,
                  action: TextButton(
                      onPressed: c.fetch, child: const Text("Try again")),
                );
              }
              if (c.items.isEmpty) {
                return const _Message(
                  icon: Icons.science_outlined,
                  title: "No sample requests",
                  body: "Raise one when a customer asks for a trial piece.",
                );
              }
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: c.items.length + (c.pages.value > 1 ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= c.items.length) return _Pager(c: c);
                    final row = c.items[i];
                    return _SampleCard(
                      row: row,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SampleDetailPage(sampleId: row.id),
                          ),
                        );
                        c.fetch();
                      },
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  final SampleListController c;
  const _SearchAndFilters({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            onChanged: c.search,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search title, customer or sample number…",
              hintStyle:
                  const TextStyle(color: ErpColors.textMuted, fontSize: 12.5),
              prefixIcon:
                  const Icon(Icons.search, size: 18, color: ErpColors.textMuted),
              isDense: true,
              filled: true,
              fillColor: ErpColors.bgMuted,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: ErpColors.borderLight)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: ErpColors.borderLight)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: ErpColors.accentBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: Obx(() => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: SampleListController.filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final f = SampleListController.filters[i];
                    final selected = c.filter.value == f;
                    final n = c.counts.value.forFilter(f);
                    final label = f == 'all'
                        ? SampleListController.filterLabel(f)
                        : "${SampleListController.filterLabel(f)} ($n)";
                    return ChoiceChip(
                      label: Text(label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? ErpColors.accentBlue
                                : ErpColors.textSecondary,
                          )),
                      selected: selected,
                      onSelected: (_) => c.filter.value = f,
                      backgroundColor: ErpColors.bgMuted,
                      selectedColor: ErpColors.accentBlue.withOpacity(0.12),
                      side: BorderSide(
                          color: selected
                              ? ErpColors.accentBlue
                              : ErpColors.borderLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                )),
          ),
        ],
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  final SampleRow row;
  final VoidCallback onTap;
  const _SampleCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.title,
                          style: ErpTextStyles.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        row.customerName.isEmpty
                            ? "No customer named"
                            : row.customerName,
                        style: const TextStyle(
                            color: ErpColors.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SampleStatusChip(status: row.status),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(row.lastLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textPrimary, fontSize: 11.5, height: 1.3)),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text(row.code,
                  style: const TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              const Icon(Icons.forum_outlined,
                  size: 12, color: ErpColors.textMuted),
              const SizedBox(width: 3),
              Text("${row.logCount}",
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
              if (row.photoCount > 0) ...[
                const SizedBox(width: 10),
                const Icon(Icons.photo_camera_outlined,
                    size: 12, color: ErpColors.textMuted),
                const SizedBox(width: 3),
                Text("${row.photoCount}",
                    style: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 11)),
              ],
              const Spacer(),
              Text(
                row.lastEntry?.at != null
                    ? DateFormat('dd MMM').format(row.lastEntry!.at!)
                    : (row.createdAt != null
                        ? DateFormat('dd MMM').format(row.createdAt!)
                        : ""),
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 11),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class SampleStatusChip extends StatelessWidget {
  final String status;
  const SampleStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    switch (status) {
      case 'completed':
        fg = ErpColors.successGreen;
        break;
      case 'in_progress':
        fg = ErpColors.warningAmber;
        break;
      case 'closed':
        fg = ErpColors.textMuted;
        break;
      default:
        fg = ErpColors.accentBlue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        sampleStatusLabel(status).toUpperCase(),
        style: TextStyle(
            color: fg,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final SampleListController c;
  const _Pager({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: c.page.value > 1
                    ? () => c.goToPage(c.page.value - 1)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Text("Page ${c.page.value} of ${c.pages.value}",
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12)),
              IconButton(
                onPressed: c.page.value < c.pages.value
                    ? () => c.goToPage(c.page.value + 1)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ));
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: ErpColors.textMuted),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 13)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

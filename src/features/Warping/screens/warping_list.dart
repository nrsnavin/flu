import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/controllers.dart';
import '../models/models.dart';
import 'Warping_detail.dart';

// ══════════════════════════════════════════════════════════════
//  WARPING LIST PAGE
// ══════════════════════════════════════════════════════════════

class WarpingListPage extends StatefulWidget {
  const WarpingListPage({super.key});
  @override
  State<WarpingListPage> createState() => _WarpingListPageState();
}

class _WarpingListPageState extends State<WarpingListPage> {
  late final WarpingListController c;
  final _searchCtrl = TextEditingController();

  static const _statuses = ['open', 'in_progress', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    // FIX: was StatelessWidget with Get.put() at class field → stale controller
    Get.delete<WarpingListController>(force: true);
    c = Get.put(WarpingListController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Column(
        children: [
          _SearchBar(ctrl: _searchCtrl, c: c),
          _StatusFilter(c: c, statuses: _statuses),
          _SummaryStrip(c: c),
          Expanded(child: _Body(c: c)),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
      onPressed: Get.back,
    ),
    titleSpacing: 4,
    title: Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Warping', style: ErpTextStyles.pageTitle),
          Text(
            '${c.warpings.length} records',
            style: const TextStyle(
              color: ErpColors.textOnDarkSub,
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
    actions: [
      Obx(
        () => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
          onPressed: c.isLoading.value ? null : () => c.fetch(reset: true),
        ),
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final WarpingListController c;
  const _SearchBar({required this.ctrl, required this.c});
  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: ErpColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search job order no…',
        hintStyle: const TextStyle(color: ErpColors.textMuted, fontSize: 12),
        prefixIcon: const Icon(
          Icons.search,
          size: 16,
          color: ErpColors.textMuted,
        ),
        suffixIcon: ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 14,
                  color: ErpColors.textMuted,
                ),
                onPressed: () {
                  ctrl.clear();
                  c.onSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: ErpColors.bgMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ErpColors.accentBlue, width: 1.4),
        ),
      ),
      onChanged: c.onSearch,
    ),
  );
}

class _StatusFilter extends StatelessWidget {
  final WarpingListController c;
  final List<String> statuses;
  const _StatusFilter({required this.c, required this.statuses});

  Color _color(String s) {
    switch (s) {
      case 'open':
        return ErpColors.accentBlue;
      case 'in_progress':
        return const Color(0xFF7C3AED);
      case 'completed':
        return ErpColors.successGreen;
      case 'cancelled':
        return ErpColors.errorRed;
      default:
        return ErpColors.accentBlue;
    }
  }

  String _label(String s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Obx(
        () => Row(
          children: statuses.map((s) {
            final active = c.statusFilter.value == s;
            final col = _color(s);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => c.changeStatus(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active ? col : ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? col : ErpColors.borderLight,
                    ),
                  ),
                  child: Text(
                    _label(s),
                    style: TextStyle(
                      color: active ? Colors.white : ErpColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

class _SummaryStrip extends StatelessWidget {
  final WarpingListController c;
  const _SummaryStrip({required this.c});
  @override
  Widget build(BuildContext context) => Obx(
    () => Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          _Pill('${c.warpings.length}', 'Total', ErpColors.accentBlue),
          const SizedBox(width: 8),
          _Pill(
            '${c.warpings.where((w) => w.hasPlan).length}',
            'With Plan',
            ErpColors.successGreen,
          ),
          const SizedBox(width: 8),
          _Pill(
            '${c.warpings.where((w) => !w.hasPlan && w.status == "open").length}',
            'Pending Plan',
            ErpColors.warningAmber,
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Pill(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  final WarpingListController c;
  const _Body({required this.c});
  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value && c.warpings.isEmpty)
      return const Center(
        child: CircularProgressIndicator(color: ErpColors.accentBlue),
      );
    if (c.errorMsg.value != null)
      return _ErrorState(
        msg: c.errorMsg.value!,
        retry: () => c.fetch(reset: true),
      );
    if (c.warpings.isEmpty) return const _EmptyState();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) c.fetch();
        return false;
      },
      child: RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetch(reset: true),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
          itemCount: c.warpings.length + (c.hasMore.value ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= c.warpings.length)
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: ErpColors.accentBlue),
                ),
              );
            return _WarpingCard(w: c.warpings[i]);
          },
        ),
      ),
    );
  });
}

class _WarpingCard extends StatelessWidget {
  final WarpingListItem w;
  const _WarpingCard({required this.w});

  Color get _statusColor {
    switch (w.status) {
      case 'open':
        return ErpColors.accentBlue;
      case 'in_progress':
        return const Color(0xFF7C3AED);
      case 'completed':
        return ErpColors.successGreen;
      case 'cancelled':
        return ErpColors.errorRed;
      default:
        return ErpColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Get.to(() => WarpingDetailPage(warpingId: w.id)),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: ErpColors.navyDark.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'W',
                      style: const TextStyle(
                        color: ErpColors.accentBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job #${w.jobOrderNo}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(w.date),
                        style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(w.status, _statusColor),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: w.hasPlan
                            ? ErpColors.successGreen.withOpacity(0.1)
                            : ErpColors.warningAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        w.hasPlan ? '✓ Plan' : 'No Plan',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: w.hasPlan
                              ? ErpColors.successGreen
                              : ErpColors.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.work_outline,
                  size: 12,
                  color: ErpColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Job status: ${w.jobStatus}',
                  style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                const Text(
                  'View Details',
                  style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: ErpColors.accentBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusPill(this.status, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      status
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' '),
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.layers_outlined, size: 44, color: ErpColors.textMuted),
        SizedBox(height: 12),
        Text(
          'No warping records',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: ErpColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'All warpings will appear here',
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 40, color: ErpColors.textMuted),
        const SizedBox(height: 12),
        const Text(
          'Failed to load',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: ErpColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          msg,
          style: const TextStyle(color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: retry,
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue,
            elevation: 0,
          ),
          icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
          label: const Text(
            'Retry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

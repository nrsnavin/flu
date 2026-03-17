import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../models/dc_model.dart';
import 'DCdetail.dart';
import 'addDCpage.dart';

// ════════════════════════════════════════════════════════════════
//  CONTROLLER
// ════════════════════════════════════════════════════════════════
class DCListController extends GetxController {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final isLoading  = false.obs;
  final dcs        = <DCListItem>[].obs;
  final hasMore    = true.obs;
  final typeFilter = Rx<String?>(''); // '' = all
  final searchCtrl = TextEditingController();
  String _lastSearch = '';
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    fetch(reset: true);
  }

  Future<void> fetch({bool reset = false}) async {
    if (isLoading.value) return;
    if (reset) {
      _page = 1;
      hasMore.value = true;
      dcs.clear();
    }
    if (!hasMore.value) return;

    try {
      isLoading.value = true;
      final params = <String, dynamic>{
        'page': _page, 'limit': 20,
        if ((typeFilter.value ?? '').isNotEmpty) 'type': typeFilter.value,
        if (searchCtrl.text.trim().isNotEmpty) 'search': searchCtrl.text.trim(),
      };
      final res = await _dio.get('/dc/list', queryParameters: params);
      final list = (res.data['dcs'] as List)
          .map((e) => DCListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      dcs.addAll(list);
      hasMore.value = list.length == 20;
      _page++;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to load';
      Get.snackbar('Error', msg,
          backgroundColor: ErpColors.errorRed,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void setType(String? t) {
    typeFilter.value = t ?? '';
    fetch(reset: true);
  }

  void onSearch(String v) {
    if (v == _lastSearch) return;
    _lastSearch = v;
    fetch(reset: true);
  }

  @override
  void onClose() {
    searchCtrl.dispose();
    super.onClose();
  }
}

// ════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════
class DCListPage extends StatefulWidget {
  const DCListPage({super.key});
  @override
  State<DCListPage> createState() => _DCListPageState();
}

class _DCListPageState extends State<DCListPage> {
  late final DCListController c;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Get.delete<DCListController>(force: true);
    c = Get.put(DCListController());
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        c.fetch();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    Get.delete<DCListController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Column(children: [
        _SearchAndFilter(c: c),
        Expanded(child: _Body(c: c, scroll: _scroll)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New DC',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddDCPage()));
          c.fetch(reset: true);
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
      onPressed: () => Navigator.maybePop(context),
    ),
    titleSpacing: 4,
    title: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Delivery Challans', style: ErpTextStyles.pageTitle),
        Text('Dispatch  ›  All DCs',
            style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
      ],
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

// ── Search + filter bar ───────────────────────────────────────
class _SearchAndFilter extends StatelessWidget {
  final DCListController c;
  const _SearchAndFilter({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        // Search
        TextField(
          controller: c.searchCtrl,
          style: ErpTextStyles.fieldValue,
          onChanged: c.onSearch,
          decoration: ErpDecorations.formInput(
            'Search DC number, customer…',
            prefix: const Icon(Icons.search, size: 18, color: ErpColors.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        // Type chips
        Obx(() => Row(children: [
          _Chip(label: 'All',          active: (c.typeFilter.value ?? '').isEmpty,         color: ErpColors.textSecondary, onTap: () => c.setType(null)),
          const SizedBox(width: 8),
          _Chip(label: 'Elastic',      active: c.typeFilter.value == 'elastic',             color: ErpColors.accentBlue,    onTap: () => c.setType('elastic')),
          const SizedBox(width: 8),
          _Chip(label: 'Machine Part', active: c.typeFilter.value == 'machine_part',        color: const Color(0xFF7C3AED), onTap: () => c.setType('machine_part')),
        ])),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:  active ? color.withOpacity(0.10) : ErpColors.bgMuted,
        border: Border.all(color: active ? color : ErpColors.borderLight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? color : ErpColors.textSecondary)),
    ),
  );
}

// ── Body ──────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final DCListController c;
  final ScrollController scroll;
  const _Body({required this.c, required this.scroll});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value && c.dcs.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.dcs.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_outlined, size: 52, color: ErpColors.textMuted),
            const SizedBox(height: 12),
            const Text('No delivery challans found',
                style: TextStyle(color: ErpColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => c.fetch(reset: true), child: const Text('Retry')),
          ]),
        );
      }

      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetch(reset: true),
        child: ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
          itemCount: c.dcs.length + (c.hasMore.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            if (i == c.dcs.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(
                    color: ErpColors.accentBlue, strokeWidth: 2)),
              );
            }
            final dc = c.dcs[i];
            return _DCCard(
              dc: dc,
              onTap: () async {
                await Navigator.of(ctx).push(
                    MaterialPageRoute(builder: (_) => DCDetailPage(dcId: dc.id)));
                c.fetch(reset: true);
              },
            );
          },
        ),
      );
    });
  }
}

// ── DC card ───────────────────────────────────────────────────
class _DCCard extends StatelessWidget {
  final DCListItem dc;
  final VoidCallback onTap;
  const _DCCard({required this.dc, required this.onTap});

  static Color _statusColor(String s) => switch (s) {
    'draft'      => ErpColors.warningAmber,
    'dispatched' => ErpColors.accentBlue,
    'delivered'  => ErpColors.successGreen,
    'cancelled'  => ErpColors.errorRed,
    _            => ErpColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final typeColor = dc.isElastic ? ErpColors.accentBlue : const Color(0xFF7C3AED);
    final typeLabel = dc.isElastic ? 'ELASTIC' : 'MACHINE PART';
    final statusColor = _statusColor(dc.status);

    String dateStr = '—';
    try { dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(dc.dispatchDate)); } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // ── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: typeColor.withOpacity(0.12))),
            ),
            child: Row(children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: typeColor.withOpacity(0.25)),
                ),
                child: Text(typeLabel, style: TextStyle(
                    color: typeColor, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 10),
              // DC number
              Text(dc.dcNumber, style: TextStyle(
                  color: typeColor, fontSize: 16,
                  fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.30)),
                ),
                child: Text(dc.status.toUpperCase(), style: TextStyle(
                    color: statusColor, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ),
            ]),
          ),
          // ── Body ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(children: [
              // Customer + Date
              Row(children: [
                const Icon(Icons.person_outline, size: 14, color: ErpColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(dc.customerName, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: ErpColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: ErpColors.textMuted)),
              ]),
              if (dc.orderNo != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.receipt_outlined, size: 13, color: ErpColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Order #${dc.orderNo}',
                      style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
                ]),
              ],
              const SizedBox(height: 10),
              // Stats row
              Row(children: [
                _StatPill(
                  label: dc.isElastic ? 'QTY' : 'ITEMS',
                  value: dc.isElastic
                      ? '${dc.totalQuantity.toStringAsFixed(0)} m'
                      : dc.totalQuantity.toStringAsFixed(0),
                  color: typeColor,
                ),
                const SizedBox(width: 8),
                if (dc.totalAmount > 0)
                  _StatPill(
                    label: 'AMOUNT',
                    value: '₹${_fmt(dc.totalAmount)}',
                    color: ErpColors.successGreen,
                  ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 12, color: ErpColors.textMuted),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
  String _fmt(double v) => NumberFormat('#,##0.##').format(v);
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
          color: color.withOpacity(0.7), letterSpacing: 0.4)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
    ]),
  );
}
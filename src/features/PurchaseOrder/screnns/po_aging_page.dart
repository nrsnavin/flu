import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  PO RECEIPT AGING PAGE
//  Open/Partial POs with outstanding receipts, bucketed by age:
//  fresh 0–7d · watch 8–30d · late 31–60d · critical 60d+.
//  Backend: GET /supplier/po-receipt-aging
// ══════════════════════════════════════════════════════════════
class POAgingController extends GetxController {
  final rows     = <Map<String, dynamic>>[].obs;
  final summary  = <String, int>{}.obs;
  final loading  = false.obs;
  final errorMsg = Rxn<String>();
  final bucket   = 'all'.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/supplier',
  );

  List<Map<String, dynamic>> get visible => bucket.value == 'all'
      ? rows
      : rows.where((r) => r['bucket'] == bucket.value).toList();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/po-receipt-aging');
      final body = res.data is Map ? res.data : const {};
      final raw = (body['data'] as List?) ?? const [];
      rows.value = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final s = body['summary'];
      if (s is Map) {
        summary.assignAll({
          for (final e in s.entries) e.key.toString(): (e.value as num).toInt(),
        });
      }
    } on DioException catch (e) {
      errorMsg.value = (e.response?.data is Map
              ? e.response?.data['message']?.toString()
              : null) ??
          'Failed to load receipt aging';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}

class POAgingPage extends StatelessWidget {
  const POAgingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(POAgingController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'PO Receipt Aging',
        subtitle: 'Outstanding supplier deliveries',
      ),
      body: Column(children: [
        _BucketChips(c: c),
        Expanded(
          child: Obx(() {
            if (c.loading.value && c.rows.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: ErpColors.accentBlue),
              );
            }
            if (c.errorMsg.value != null && c.rows.isEmpty) {
              return _CenterMsg(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load',
                subtitle: c.errorMsg.value!,
                cta: 'Retry',
                onTap: c.fetch,
              );
            }
            final visible = c.visible;
            if (visible.isEmpty) {
              return _CenterMsg(
                icon: Icons.task_alt_outlined,
                title: 'Nothing outstanding',
                subtitle: c.bucket.value == 'all'
                    ? 'Every PO line has been fully received.'
                    : 'No POs in this bucket.',
                cta: 'Refresh',
                onTap: c.fetch,
              );
            }
            return RefreshIndicator(
              onRefresh: c.fetch,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _POCard(row: visible[i]),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

const _bucketMeta = {
  'fresh':    (Color(0xFFDCFCE7), Color(0xFF15803D), 'FRESH'),
  'watch':    (Color(0xFFEFF6FF), Color(0xFF1D6FEB), 'WATCH'),
  'late':     (Color(0xFFFEF3C7), Color(0xFFB45309), 'LATE'),
  'critical': (Color(0xFFFEE2E2), Color(0xFFB91C1C), 'CRITICAL'),
};

class _BucketChips extends StatelessWidget {
  final POAgingController c;
  const _BucketChips({required this.c});

  @override
  Widget build(BuildContext context) {
    const buckets = ['all', 'fresh', 'watch', 'late', 'critical'];
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: buckets.map((b) {
                final selected = c.bucket.value == b;
                final count =
                    b == 'all' ? c.rows.length : (c.summary[b] ?? 0);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${b == 'all' ? 'All' : b} ($count)'),
                    selected: selected,
                    selectedColor: ErpColors.accentBlue,
                    backgroundColor: ErpColors.bgMuted,
                    labelStyle: TextStyle(
                      color:
                          selected ? Colors.white : ErpColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) => c.bucket.value = b,
                  ),
                );
              }).toList(),
            ),
          )),
    );
  }
}

class _POCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _POCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final poNo = row['poNo']?.toString() ?? '—';
    final supplier = row['supplierName']?.toString() ?? '—';
    final ageDays = (row['ageDays'] as num?)?.toInt() ?? 0;
    final bucket = row['bucket']?.toString() ?? 'fresh';
    final pending = (row['totalPending'] as num?)?.toDouble() ?? 0;
    final items = (row['pendingItems'] as List?) ?? const [];

    String created = '—';
    final raw = row['createdAt']?.toString();
    if (raw != null) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) created = DateFormat('dd MMM yyyy').format(dt.toLocal());
    }

    final (bg, fg, label) = _bucketMeta[bucket] ??
        (ErpColors.bgMuted, ErpColors.textMuted, bucket.toUpperCase());

    return Container(
      decoration: ErpDecorations.card,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(children: [
            Expanded(
              child: Text('PO #$poNo · $supplier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: fg,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4)),
            ),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Raised $created · $ageDays days ago · '
              '${pending.toStringAsFixed(pending == pending.roundToDouble() ? 0 : 2)} kg pending',
              style:
                  const TextStyle(color: ErpColors.textMuted, fontSize: 11),
            ),
          ),
          children: items
              .whereType<Map>()
              .map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const Icon(Icons.circle,
                          size: 5, color: ErpColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i['rawMaterialName']?.toString() ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: ErpColors.textPrimary, fontSize: 12),
                        ),
                      ),
                      Text(
                        '${i['received'] ?? 0} / ${i['ordered'] ?? 0} kg',
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _CenterMsg extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, cta;
  final VoidCallback onTap;
  const _CenterMsg({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: ErpColors.textMuted),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.accentBlue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(cta,
                style: const TextStyle(
                    color: ErpColors.accentBlue,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

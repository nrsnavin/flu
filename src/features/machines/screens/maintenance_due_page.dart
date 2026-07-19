import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  MAINTENANCE DUE PAGE
//  Lists machines whose latest service log's nextServiceDate is
//  overdue or due within the horizon (default 14 days).
//  Backend: GET /machine/maintenance-due?days=N
// ══════════════════════════════════════════════════════════════
class MaintenanceDueController extends GetxController {
  final items        = <Map<String, dynamic>>[].obs;
  final loading      = false.obs;
  final errorMsg     = Rxn<String>();
  final overdueCount = 0.obs;
  final days         = 14.obs;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/machine',
  );

  @override
  void onInit() {
    super.onInit();
    fetch();
    ever(days, (_) => fetch());
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get(
        '/maintenance-due',
        queryParameters: {'days': days.value},
      );
      final body = res.data is Map ? res.data : const {};
      final raw = (body['data'] as List?) ?? const [];
      items.value = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      overdueCount.value = (body['overdueCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      errorMsg.value = (e.response?.data is Map
              ? e.response?.data['message']?.toString()
              : null) ??
          'Failed to load maintenance schedule';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}

class MaintenanceDuePage extends StatelessWidget {
  const MaintenanceDuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MaintenanceDueController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Maintenance Due',
        subtitle: 'Machines needing service',
      ),
      body: Column(children: [
        _HorizonChips(c: c),
        Expanded(
          child: Obx(() {
            if (c.loading.value && c.items.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: ErpColors.accentBlue),
              );
            }
            if (c.errorMsg.value != null && c.items.isEmpty) {
              return _CenterMsg(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load',
                subtitle: c.errorMsg.value!,
                cta: 'Retry',
                onTap: c.fetch,
              );
            }
            if (c.items.isEmpty) {
              return _CenterMsg(
                icon: Icons.verified_outlined,
                title: 'All machines serviced',
                subtitle:
                    'No machine is due for service within ${c.days.value} days.',
                cta: 'Refresh',
                onTap: c.fetch,
              );
            }
            return RefreshIndicator(
              onRefresh: c.fetch,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                itemCount: c.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _MachineCard(item: c.items[i]),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _HorizonChips extends StatelessWidget {
  final MaintenanceDueController c;
  const _HorizonChips({required this.c});

  @override
  Widget build(BuildContext context) {
    const horizons = [7, 14, 30, 60];
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => Row(children: [
            ...horizons.map((h) {
              final selected = c.days.value == h;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$h days'),
                  selected: selected,
                  selectedColor: ErpColors.accentBlue,
                  backgroundColor: ErpColors.bgMuted,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  onSelected: (_) => c.days.value = h,
                ),
              );
            }),
            const Spacer(),
            if (c.overdueCount.value > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${c.overdueCount.value} OVERDUE',
                    style: const TextStyle(
                        color: ErpColors.errorRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
          ])),
    );
  }
}

class _MachineCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MachineCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final id = item['ID']?.toString() ?? '—';
    final manufacturer = item['manufacturer']?.toString() ?? '';
    final overdue = item['overdue'] == true;
    final daysUntil = (item['daysUntil'] as num?)?.toInt() ?? 0;
    final lastType = item['lastServiceType']?.toString() ?? '';

    String dateLabel = '—';
    final raw = item['nextServiceDate']?.toString();
    if (raw != null) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) dateLabel = DateFormat('dd MMM yyyy').format(dt.toLocal());
    }

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (overdue ? ErpColors.errorRed : ErpColors.warningAmber)
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            overdue ? Icons.error_outline : Icons.schedule,
            color: overdue ? ErpColors.errorRed : ErpColors.warningAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('M-$id',
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            if (manufacturer.isNotEmpty)
              Text(manufacturer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              'Service due $dateLabel'
              '${lastType.isNotEmpty ? ' · last: $lastType' : ''}',
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 11),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: overdue ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            overdue ? '${-daysUntil}d OVERDUE' : 'in ${daysUntil}d',
            style: TextStyle(
                color: overdue ? ErpColors.errorRed : ErpColors.warningAmber,
                fontSize: 10,
                fontWeight: FontWeight.w900),
          ),
        ),
      ]),
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

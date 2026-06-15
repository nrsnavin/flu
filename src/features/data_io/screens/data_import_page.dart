import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/data_io_controller.dart';

/// Admin screen to bulk-import Raw Materials + Elastics from an Excel
/// workbook. Pick a `.xlsx` (the same format the export / template
/// produce), upload it, and read back the upsert report.
class DataImportPage extends StatelessWidget {
  const DataImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DataIoController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Import data', style: ErpTextStyles.pageTitle),
            Text('Raw materials & elastics from Excel',
                style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _HelpCard(),
          const SizedBox(height: 14),
          _PickCard(c: c),
          const SizedBox(height: 14),
          Obx(() {
            if (c.errorMsg.value != null) {
              return _ErrorCard(message: c.errorMsg.value!);
            }
            final r = c.lastResult.value;
            if (r == null) return const SizedBox.shrink();
            return _ResultCard(result: r);
          }),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.accentBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.accentBlue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: ErpColors.accentBlue),
            SizedBox(width: 8),
            Text('How it works',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary)),
          ]),
          SizedBox(height: 8),
          Text(
            'Upload the same .xlsx the export / template produces. Rows are '
            'matched by name (upsert): existing names update in place, new '
            'names are created. Elastics reference materials by name; any row '
            'pointing at a missing material is skipped and listed below.',
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final DataIoController c;
  const _PickCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Obx(() => Column(
            children: [
              if (c.pickedName.value != null) ...[
                Row(children: [
                  const Icon(Icons.description_outlined,
                      size: 18, color: ErpColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c.pickedName.value!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: ErpColors.textSecondary)),
                  ),
                ]),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: c.busy.value ? null : c.pickAndImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: c.busy.value
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(c.busy.value
                      ? 'Importing…'
                      : 'Pick .xlsx & import'),
                ),
              ),
            ],
          )),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ImportResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.skipped.isEmpty;
    final tone = ok ? ErpColors.successGreen : ErpColors.warningAmber;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 18, color: tone),
            const SizedBox(width: 8),
            Expanded(
              child: Text(result.message,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Suppliers', value: result.suppliers),
              _Stat(label: 'Materials', value: result.materials),
              _Stat(label: 'Elastics',  value: result.elastics),
            ],
          ),
          if (result.skipped.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Skipped rows',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: ErpColors.warningAmber, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            ...result.skipped.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ',
                          style: TextStyle(
                              fontSize: 12, color: ErpColors.textMuted)),
                      Expanded(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 11, color: ErpColors.textSecondary)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: ErpColors.accentBlue)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: ErpColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.errorRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.errorRed.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            size: 18, color: ErpColors.errorRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary)),
        ),
      ]),
    );
  }
}

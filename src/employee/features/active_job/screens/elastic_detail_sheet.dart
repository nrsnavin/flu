import 'package:flutter/material.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';

/// Bottom sheet that shows EVERY field on an Elastic document
/// (except `costing`), translated from production-jargon into
/// plain-English labels a floor worker can follow.
///
/// Sections are ordered the way a weaver would think about a
/// piece: identity → composition → threads → weave → testing →
/// inventory → warping plan.
///
/// The `elastic` map is the JSON shape returned by
/// `GET /shift/active-job/:empId`'s deep populate. Missing fields
/// are silently skipped so older Elastic records still render.
class ElasticDetailSheet extends StatelessWidget {
  /// Full Elastic JSON.
  final Map<String, dynamic> elastic;

  /// Optional head number — when present, used in the title.
  final int? headNo;

  const ElasticDetailSheet({
    super.key,
    required this.elastic,
    this.headNo,
  });

  static Future<void> show(BuildContext context, {
    required Map<String, dynamic> elastic,
    int? headNo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ElasticDetailSheet(elastic: elastic, headNo: headNo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(maxHeight: h * 0.95),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: ErpColors.borderMid,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            _Header(elastic: elastic, headNo: headNo),
            const Divider(height: 1, color: ErpColors.borderLight),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _CompositionSection(elastic: elastic),
                  const SizedBox(height: 12),
                  _ThreadsSection(elastic: elastic),
                  const SizedBox(height: 12),
                  _WeaveSection(elastic: elastic),
                  const SizedBox(height: 12),
                  _TestingSection(elastic: elastic),
                  const SizedBox(height: 12),
                  _InventorySection(elastic: elastic),
                  const SizedBox(height: 12),
                  _WarpingPlanSection(elastic: elastic),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Map<String, dynamic> elastic;
  final int? headNo;
  const _Header({required this.elastic, this.headNo});
  @override
  Widget build(BuildContext context) {
    final name      = SafeJson.asString(elastic['name'], '—');
    final weaveType = SafeJson.asString(elastic['weaveType'], '—');
    final image     = SafeJson.asStringOrNull(elastic['image']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(children: [
        if (image != null && image.isNotEmpty)
          Container(
            width: 56, height: 56,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(image),
                fit: BoxFit.cover,
                onError: (_, __) {},
              ),
            ),
          )
        else
          Container(
            width: 56, height: 56,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.line_axis_outlined,
                color: ErpColors.accentBlue, size: 28),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (headNo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('Head $headNo',
                        style: const TextStyle(
                            color: ErpColors.accentBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('Weave pattern · $weaveType-shaft',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Composition (warp spandex + covering + weft) ───────────────
class _CompositionSection extends StatelessWidget {
  final Map<String, dynamic> elastic;
  const _CompositionSection({required this.elastic});

  @override
  Widget build(BuildContext context) {
    final warpSpandex = SafeJson.asMapOrNull(elastic['warpSpandex']);
    final covering    = SafeJson.asMapOrNull(elastic['spandexCovering']);
    final weft        = SafeJson.asMapOrNull(elastic['weftYarn']);

    return ErpSectionCard(
      title: 'WHAT IT\'S MADE OF',
      icon: Icons.science_outlined,
      child: Column(children: [
        _MaterialRow(
          label: 'Stretchy core (warp spandex)',
          help:  'The rubber thread that gives the elastic its stretch.',
          materialRef: warpSpandex?['id'],
          extra: [
            if (SafeJson.asNum(warpSpandex?['ends']) != null)
              ('Number of threads', '${SafeJson.asNum(warpSpandex?['ends'])}'),
            if (SafeJson.asNum(warpSpandex?['weight']) != null)
              ('Weight', '${SafeJson.asNum(warpSpandex?['weight'])} g'),
          ],
        ),
        const _Divider(),
        _MaterialRow(
          label: 'Cover yarn around the rubber',
          help:  'Wraps the rubber so it feels soft and holds the colour.',
          materialRef: covering?['id'],
          extra: [
            if (SafeJson.asNum(covering?['weight']) != null)
              ('Weight', '${SafeJson.asNum(covering?['weight'])} g'),
          ],
        ),
        const _Divider(),
        _MaterialRow(
          label: 'Crosswise yarn (weft)',
          help:  'Threads woven side-to-side; holds the warp together.',
          materialRef: weft?['id'],
          extra: [
            if (SafeJson.asNum(weft?['weight']) != null)
              ('Weight', '${SafeJson.asNum(weft?['weight'])} g'),
          ],
        ),
      ]),
    );
  }
}

// ── Threads (warp yarn list, spandex/yarn ends) ───────────────
class _ThreadsSection extends StatelessWidget {
  final Map<String, dynamic> elastic;
  const _ThreadsSection({required this.elastic});

  @override
  Widget build(BuildContext context) {
    final warpYarn    = SafeJson.asMapList(elastic['warpYarn']);
    final spandexEnds = SafeJson.asNum(elastic['spandexEnds']);
    final yarnEnds    = SafeJson.asNum(elastic['yarnEnds']);

    return ErpSectionCard(
      title: 'THREAD COUNT',
      icon: Icons.line_weight_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Total rubber threads',
              spandexEnds?.toString(),
              help: 'How many spandex threads run lengthwise.'),
          if (yarnEnds != null)
            _kv('Total yarn threads',
                yarnEnds.toString(),
                help: 'How many yarn threads run lengthwise.'),
          if (warpYarn.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('LENGTHWISE YARNS USED',
                style: ErpTextStyles.fieldLabel),
            const SizedBox(height: 6),
            ...warpYarn.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final y = entry.value;
              final mat   = SafeJson.asMapOrNull(y['id']);
              final name  = SafeJson.asString(mat?['name'], 'Yarn $i');
              final ends  = SafeJson.asNum(y['ends'])?.toString();
              final type  = SafeJson.asStringOrNull(y['type']);
              final wt    = SafeJson.asNum(y['weight'])?.toString();
              final parts = <String>[];
              if (ends   != null) parts.add('$ends threads');
              if (type   != null && type.isNotEmpty) parts.add('type $type');
              if (wt     != null) parts.add('$wt g');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text('$i',
                          style: const TextStyle(
                              color: ErpColors.accentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: ErpColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          if (parts.isNotEmpty)
                            Text(parts.join('  ·  '),
                                style: const TextStyle(
                                    color: ErpColors.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                  ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Weave settings ─────────────────────────────────────────────
class _WeaveSection extends StatelessWidget {
  final Map<String, dynamic> elastic;
  const _WeaveSection({required this.elastic});
  @override
  Widget build(BuildContext context) {
    final pick   = SafeJson.asNum(elastic['pick']);
    final hooks  = SafeJson.asNum(elastic['noOfHook']);
    final weight = SafeJson.asNum(elastic['weight']);
    return ErpSectionCard(
      title: 'WEAVE SETTINGS',
      icon: Icons.settings_input_component_outlined,
      child: Column(children: [
        _kv('Picks per inch (PPI)', pick?.toString(),
            help: 'How tightly the crosswise yarns are packed. '
                  'Higher number = tighter, firmer elastic.'),
        _kv('Hooks on machine head', hooks?.toString(),
            help: 'How many hooks the elastic uses per machine head. '
                  'Should match the head you\'re running.'),
        _kv('Weight per meter', weight != null ? '$weight g' : null,
            help: 'Reference weight of finished elastic per meter.'),
      ]),
    );
  }
}

// ── Testing parameters ─────────────────────────────────────────
class _TestingSection extends StatelessWidget {
  final Map<String, dynamic> elastic;
  const _TestingSection({required this.elastic});
  @override
  Widget build(BuildContext context) {
    final t = SafeJson.asMap(elastic['testingParameters']);
    final width      = SafeJson.asNum(t['width']);
    final elongation = SafeJson.asNum(t['elongation']);
    final recovery   = SafeJson.asNum(t['recovery']);
    final strech     = SafeJson.asStringOrNull(t['strech']);
    return ErpSectionCard(
      title: 'QUALITY TARGETS',
      icon: Icons.rule_outlined,
      child: Column(children: [
        _kv('Finished width', width != null ? '$width mm' : null,
            help: 'How wide the elastic should be after weaving.'),
        _kv('Maximum stretch',
            elongation != null ? '$elongation%' : null,
            help: 'How much it can stretch before snapping back. '
                  'Higher = stretchier.'),
        _kv('Snap-back (recovery)',
            recovery != null ? '$recovery%' : null,
            help: 'How well it returns to its original size. '
                  '100% = perfect rebound.'),
        _kv('Stretch class', strech,
            help: 'Grade for how stretchy the finished elastic is.'),
      ]),
    );
  }
}

// ── Inventory ──────────────────────────────────────────────────
class _InventorySection extends StatelessWidget {
  final Map<String, dynamic> elastic;
  const _InventorySection({required this.elastic});
  @override
  Widget build(BuildContext context) {
    final produced = SafeJson.asNum(elastic['quantityProduced']);
    // Worker portal is admin-only for stock visibility. Show
    // lifetime production (useful context for the loom operator)
    // but suppress current warehouse stock.
    return ErpSectionCard(
      title: 'INVENTORY',
      icon: Icons.inventory_2_outlined,
      child: Column(children: [
        _kv('Total produced so far',
            produced != null ? '$produced m' : null,
            help: 'Lifetime production of this elastic.'),
      ]),
    );
  }
}

// ── Warping plan ───────────────────────────────────────────────
class _WarpingPlanSection extends StatelessWidget {
  final Map<String, dynamic> elastic;
  const _WarpingPlanSection({required this.elastic});
  @override
  Widget build(BuildContext context) {
    final plan = SafeJson.asMapOrNull(elastic['warpingPlanTemplate']);
    if (plan == null || plan.isEmpty) {
      return ErpSectionCard(
        title: 'BEAM SETUP',
        icon: Icons.view_column_outlined,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No standard beam setup defined for this elastic.',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12)),
        ),
      );
    }
    final beams     = SafeJson.asMapList(plan['beams']);
    final beamCount = SafeJson.asNum(plan['noOfBeams']);

    return ErpSectionCard(
      title: 'BEAM SETUP',
      icon: Icons.view_column_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Beams needed', beamCount?.toString(),
              help: 'Number of warp beams to load on the machine.'),
          if (beams.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...beams.map((b) {
              final no       = SafeJson.asString(b['beamNo'], '—');
              final ends     = SafeJson.asNum(b['totalEnds'])?.toString();
              final paired   = SafeJson.asStringOrNull(b['pairedBeamNo']);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('Beam $no',
                        style: const TextStyle(
                            color: ErpColors.accentBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  if (ends != null)
                    Text('$ends threads',
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (paired != null && paired.isNotEmpty)
                    Text('paired with $paired',
                        style: const TextStyle(
                            color: ErpColors.textMuted, fontSize: 11)),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────
class _MaterialRow extends StatelessWidget {
  final String label;
  final String help;
  final dynamic materialRef;
  final List<(String, String)> extra;
  const _MaterialRow({
    required this.label,
    required this.help,
    required this.materialRef,
    required this.extra,
  });
  @override
  Widget build(BuildContext context) {
    final mat = SafeJson.asMapOrNull(materialRef);
    final matName     = SafeJson.asString(mat?['name'], 'Not specified');
    final matCategory = SafeJson.asString(mat?['category']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(help,
            style: const TextStyle(
                color: ErpColors.textMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.local_offer_outlined,
              size: 12, color: ErpColors.accentBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(matName,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          if (matCategory.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(matCategory.toUpperCase(),
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ]),
        if (extra.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...extra.map((e) => Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Row(children: [
                  Text('${e.$1}: ',
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 11)),
                  Text(e.$2,
                      style: const TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              )),
        ],
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: ErpColors.borderLight),
      );
}

Widget _kv(String label, String? value, {String? help}) {
  if (value == null || value.isEmpty || value == 'null') {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
        if (help != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(help,
                style: const TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ),
      ],
    ),
  );
}

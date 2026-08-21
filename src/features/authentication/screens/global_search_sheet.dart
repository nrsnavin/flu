import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/nav_registry.dart';

/// Modal bottom sheet that searches the module catalog. Opened from
/// the centre FAB on `ErpShell` and from the More page. Tapping a
/// result closes the sheet, opens the module and updates `recents`
/// via `NavRegistry.open`.
class GlobalSearchSheet extends StatefulWidget {
  const GlobalSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GlobalSearchSheet(),
    );
  }

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final results = _q.trim().isEmpty
        ? const <NavModule>[]
        : reg.search(_q);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ErpColors.borderMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15, color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search modules — orders, po, stock, payroll…',
                    hintStyle: TextStyle(
                      color: ErpColors.textMuted, fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: ErpColors.accentBlue, size: 22),
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: ErpColors.textSecondary),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _q = '');
                            },
                          ),
                    filled: true,
                    fillColor: ErpColors.bgMuted,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(
                child: _q.trim().isEmpty
                    ? _SuggestionList(scrollCtrl: scrollCtrl, reg: reg)
                    : _ResultList(scrollCtrl: scrollCtrl, items: results),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final NavRegistry reg;
  const _SuggestionList({required this.scrollCtrl, required this.reg});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pinnedIds = reg.pinned.toList();
      final recentIds = reg.recents.toList();

      return ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (pinnedIds.isNotEmpty) ...[
            const _SectionLabel('PINNED'),
            ..._modules(pinnedIds),
            const SizedBox(height: 16),
          ],
          if (recentIds.isNotEmpty) ...[
            const _SectionLabel('RECENT'),
            ..._modules(recentIds),
          ],
          if (pinnedIds.isEmpty && recentIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.travel_explore_rounded,
                      size: 48, color: ErpColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Start typing to find any module',
                    style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  List<Widget> _modules(List<String> ids) => ids
      .map(reg.byId)
      .whereType<NavModule>()
      .map((m) => _ResultTile(module: m))
      .toList();
}

class _ResultList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final List<NavModule> items;
  const _ResultList({required this.scrollCtrl, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: ErpColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No modules match that search',
              style: TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      itemBuilder: (_, i) => _ResultTile(module: items[i]),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final NavModule module;
  const _ResultTile({required this.module});

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).pop();
          reg.open(module.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(module.icon,
                    size: 18, color: ErpColors.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ErpColors.textPrimary,
                        )),
                    Text(module.section,
                        style: TextStyle(
                          fontSize: 11,
                          color: ErpColors.textSecondary,
                          letterSpacing: 0.4,
                        )),
                  ],
                ),
              ),
              Obx(() {
                final pinned = reg.pinned.contains(module.id);
                return IconButton(
                  tooltip: pinned ? 'Unpin' : 'Pin',
                  icon: Icon(
                    pinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 18,
                    color: pinned
                        ? ErpColors.accentBlue
                        : ErpColors.textMuted,
                  ),
                  onPressed: () => reg.togglePin(module.id),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 0, 6),
        child: Text(text, style: ErpTextStyles.sectionHeader),
      );
}

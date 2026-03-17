import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  showSearchablePicker
//
//  Two modes depending on which parameter you supply:
//
//  1. STATIC mode (pass `items`)
//     Local list — filters client-side as you type. Use when
//     the full dataset is already in memory.
//
//  2. API mode (pass `onSearch`)
//     Calls onSearch(query) on each keystroke (debounced 350 ms).
//     The picker manages loading / result state itself.
//     Use when the backend paginates and you need server-side search.
//
//  You can supply both; if `onSearch` is present it takes priority.
// ══════════════════════════════════════════════════════════════

Future<T?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required String Function(T) label,
  // Static mode
  List<T> items = const [],
  // API mode
  Future<List<T>> Function(String query)? onSearch,
  // Optional item icon
  IconData itemIcon = Icons.inventory_2_outlined,
}) {
  return Get.bottomSheet<T>(
    _SearchablePickerSheet<T>(
      title:     title,
      items:     items,
      label:     label,
      onSearch:  onSearch,
      itemIcon:  itemIcon,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

// ══════════════════════════════════════════════════════════════
//  Internal sheet widget
// ══════════════════════════════════════════════════════════════

class _SearchablePickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) label;
  final Future<List<T>> Function(String)? onSearch;
  final IconData itemIcon;

  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    required this.label,
    this.onSearch,
    this.itemIcon = Icons.inventory_2_outlined,
  });

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T>
    extends State<_SearchablePickerSheet<T>> {
  // ── Mode flags ─────────────────────────────────────────────
  bool get _isApiMode => widget.onSearch != null;

  // ── State ──────────────────────────────────────────────────
  List<T>  _results   = [];
  bool     _loading   = false;
  bool     _hasFetched = false; // true once the first API call returns
  String   _query     = '';

  final _ctrl   = TextEditingController();
  Timer?  _debounce;

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (!_isApiMode) {
      // Static mode: show all items immediately
      _results = List.from(widget.items);
    }
    // API mode: show empty state until user types
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Search logic ───────────────────────────────────────────
  void _onQueryChanged(String query) {
    _query = query;

    if (_isApiMode) {
      // Debounce API calls by 350 ms
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _fetchFromApi(query);
      });
    } else {
      // Static: instant client-side filter
      setState(() {
        final q = query.toLowerCase();
        _results = q.isEmpty
            ? List.from(widget.items)
            : widget.items
            .where((e) => widget.label(e).toLowerCase().contains(q))
            .toList();
      });
    }
  }

  Future<void> _fetchFromApi(String query) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await widget.onSearch!(query);
      if (!mounted) return;
      setState(() {
        _results    = res;
        _hasFetched = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.75,
      decoration: const BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: ErpColors.borderMid,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(
              width: 3, height: 14,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: ErpColors.accentBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(widget.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.close,
                  color: ErpColors.textMuted, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onQueryChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _isApiMode
                    ? 'Type to search ${widget.title.toLowerCase()}…'
                    : 'Search ${widget.title.toLowerCase()}…',
                hintStyle: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: ErpColors.textMuted),
                // Spinner replaces clear button while loading
                suffixIcon: _loading
                    ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ErpColors.accentBlue,
                    ),
                  ),
                )
                    : _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: ErpColors.textMuted),
                  onPressed: () {
                    _ctrl.clear();
                    _onQueryChanged('');
                  },
                )
                    : null,
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
                  borderSide: const BorderSide(
                      color: ErpColors.accentBlue, width: 1.5),
                ),
              ),
            ),
          ),
        ),

        // Result count / status line
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(children: [
            if (_isApiMode && !_hasFetched && !_loading)
              const Text('Start typing to search…',
                  style: TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500))
            else
              Text(
                '${_results.length} result${_results.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
          ]),
        ),

        // Body — empty states or list
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    // API mode — not yet typed anything
    if (_isApiMode && !_hasFetched && !_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search_rounded,
              size: 40, color: ErpColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(
            'Search for ${widget.title.toLowerCase()}',
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Results load as you type',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 11),
          ),
        ]),
      );
    }

    // Loading first fetch
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ErpColors.accentBlue),
      );
    }

    // No results after search
    if (_results.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off,
              size: 32, color: ErpColors.textMuted),
          const SizedBox(height: 8),
          const Text('No results found',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 14)),
          if (_query.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('for "$_query"',
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 12)),
          ],
        ]),
      );
    }

    // Results list
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final item = _results[i];
        return GestureDetector(
          onTap: () => Get.back(result: item),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: ErpColors.navyDark.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(widget.itemIcon,
                    size: 18, color: ErpColors.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.label(item),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: ErpColors.textMuted),
            ]),
          ),
        );
      },
    );
  }
}
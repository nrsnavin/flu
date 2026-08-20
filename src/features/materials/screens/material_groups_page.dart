import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/material_group_controller.dart';

// ══════════════════════════════════════════════════════════════
//  MATERIAL GROUPS — the one place the list is EDITED
//
//  The phone has read this list for a while: every category picker,
//  filter chip and colour swatch already comes from the server rather
//  than from the five names hardcoded in six files. What it could not
//  do was change it. So a mill that needed a new category had to find
//  a desktop to add it, and until somebody did, the material could not
//  be entered at all.
//
//  ── Renaming moves other people's rows ─────────────────────────
//  A group's name IS the category string on every material in it, so a
//  rename cascades. The server reports how many moved and this repeats
//  the number back, because renaming a group and silently rewriting
//  eighty rows is a surprise that should not be discovered later.
//  The `code` never moves, which is what everything else keys on.
//
//  ── Removing archives or deletes, and the server decides ───────
//  A group that has ever held a material is archived; one that never
//  did is deleted outright. The confirm dialog is keyed off
//  totalMaterialCount — live PLUS archived — not the live count. An
//  archived material still names its group, so reading the live count
//  alone makes the dialog promise "removed outright" for a group the
//  server then archives. The web hit exactly that.
// ══════════════════════════════════════════════════════════════

class MaterialGroupsController extends GetxController {
  final groups = <MaterialGroup>[].obs;
  final isLoading = false.obs;
  final isBusy = false.obs;
  final errorMsg = RxnString();
  final showArchived = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      groups.value = await MaterialGroupService.fetch(
        includeArchived: true,
        withCounts: true,
      );
    } on DioException catch (e) {
      final d = e.response?.data;
      errorMsg.value = e.response?.statusCode == 403
          ? 'Material groups are managed by administrators.'
          : (d is Map && d['message'] != null
              ? d['message'].toString()
              : 'Could not load material groups');
    } catch (_) {
      errorMsg.value = 'Could not load material groups';
    } finally {
      isLoading.value = false;
    }
  }

  List<MaterialGroup> get visible {
    final list = showArchived.value
        ? groups.toList()
        : groups.where((g) => !g.archived).toList();
    // sortOrder first, then name — the same order every picker in the
    // app shows them in, so this screen is not a different list.
    list.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Every write refreshes the session-wide store too, or the pickers
  /// on other screens would keep offering yesterday's list.
  Future<void> _refreshEverything() async {
    await fetch();
    if (Get.isRegistered<MaterialGroupStore>()) {
      await MaterialGroupStore.to.load(force: true);
    }
  }

  Future<String?> save(MaterialGroup g, {required bool isNew}) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      if (isNew) {
        await MaterialGroupService.create(g.toValues());
        await _refreshEverything();
        return null;
      }
      final res = await MaterialGroupService.update(g.id, g.toValues());
      await _refreshEverything();
      return res.materialsRenamed > 0
          ? '__renamed__${res.materialsRenamed}'
          : null;
    } catch (e) {
      return _message(e, 'Could not save the group');
    } finally {
      isBusy.value = false;
    }
  }

  /// Returns a message to show — the server's own words for whether it
  /// archived or deleted — or an error.
  Future<({bool ok, String message})> remove(MaterialGroup g) async {
    isBusy.value = true;
    try {
      final res = await MaterialGroupService.remove(g.id);
      await _refreshEverything();
      return (
        ok: true,
        message: res.message.isNotEmpty
            ? res.message
            : (res.archived
                ? '${g.name} archived'
                : '${g.name} removed')
      );
    } catch (e) {
      return (ok: false, message: _message(e, 'Could not remove the group'));
    } finally {
      isBusy.value = false;
    }
  }

  Future<({bool ok, String message})> restore(MaterialGroup g) async {
    isBusy.value = true;
    try {
      await MaterialGroupService.restore(g.id);
      await _refreshEverything();
      return (ok: true, message: '${g.name} restored');
    } catch (e) {
      return (ok: false, message: _message(e, 'Could not restore the group'));
    } finally {
      isBusy.value = false;
    }
  }

  String _message(Object e, String fallback) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) return d['message'].toString();
    }
    return fallback;
  }
}

class MaterialGroupsPage extends StatefulWidget {
  const MaterialGroupsPage({super.key});

  @override
  State<MaterialGroupsPage> createState() => _MaterialGroupsPageState();
}

class _MaterialGroupsPageState extends State<MaterialGroupsPage> {
  late final MaterialGroupsController c;

  @override
  void initState() {
    super.initState();
    Get.delete<MaterialGroupsController>(force: true);
    c = Get.put(MaterialGroupsController());
  }

  @override
  void dispose() {
    Get.delete<MaterialGroupsController>(force: true);
    super.dispose();
  }

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ErpColors.errorRed : ErpColors.successGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        elevation: 0,
        title: const Text('Material Groups'),
        actions: [
          Obx(() => IconButton(
                tooltip: c.showArchived.value
                    ? 'Hide archived'
                    : 'Show archived',
                onPressed: () =>
                    c.showArchived.value = !c.showArchived.value,
                icon: Icon(c.showArchived.value
                    ? Icons.visibility_off_outlined
                    : Icons.inventory_2_outlined),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New group',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.groups.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null && c.groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ErpColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: c.fetch, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }

        final list = c.visible;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                c.showArchived.value
                    ? 'No material groups yet.'
                    : 'No active material groups. Tap the archive icon to '
                        'see archived ones.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ErpColors.textSecondary),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: c.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _row(list[i]),
          ),
        );
      }),
    );
  }

  Widget _row(MaterialGroup g) {
    final swatch = parseHexColour(g.colour) ?? categoryColour(g.name);
    final live = g.materialCount;
    return Opacity(
      opacity: g.archived ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 38,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ErpColors.textPrimary)),
                      ),
                      if (g.archived) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: ErpColors.bgMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Archived',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ErpColors.textMuted)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      kGroupKinds[g.kind]?.label ?? g.kind,
                      if (live != null)
                        '$live material${live == 1 ? '' : 's'}',
                      if (g.defaultUnit.isNotEmpty) g.defaultUnit,
                    ].join('  ·  '),
                    style: const TextStyle(
                        fontSize: 11.5, color: ErpColors.textMuted),
                  ),
                ],
              ),
            ),
            if (g.archived)
              IconButton(
                tooltip: 'Restore',
                icon: const Icon(Icons.restore, size: 20),
                onPressed: () async {
                  final r = await c.restore(g);
                  _say(r.message, error: !r.ok);
                },
              )
            else ...[
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _edit(g),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: ErpColors.errorRed),
                onPressed: () => _confirmRemove(g),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What the confirm dialog promises, keyed off the SAME number the
  /// server decides on — total members, live and archived.
  Future<void> _confirmRemove(MaterialGroup g) async {
    final total = g.totalMaterialCount ?? g.materialCount ?? 0;
    final willArchive = total > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(willArchive ? 'Archive ${g.name}?' : 'Remove ${g.name}?'),
        content: Text(
          willArchive
              ? '$total material${total == 1 ? '' : 's'} '
                  '${total == 1 ? 'names' : 'name'} this group, so it is '
                  'archived rather than deleted — those records keep '
                  'reading correctly. It stops appearing in the pickers, '
                  'and it can be restored.'
              : 'Nothing has ever been filed under this group, so it is '
                  'removed outright.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    willArchive ? ErpColors.warningAmber : ErpColors.errorRed),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(willArchive ? 'Archive' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await c.remove(g);
    _say(r.message, error: !r.ok);
  }

  Future<void> _edit(MaterialGroup? existing) async {
    final saved = await showModalBottomSheet<MaterialGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupSheet(existing: existing),
    );
    if (saved == null) return;

    final result = await c.save(saved, isNew: existing == null);
    if (result == null) {
      _say(existing == null ? '${saved.name} added' : '${saved.name} saved');
    } else if (result.startsWith('__renamed__')) {
      final n = result.substring('__renamed__'.length);
      // The cascade, said out loud.
      _say('${saved.name} saved — $n material'
          '${n == '1' ? '' : 's'} moved to the new name');
    } else {
      _say(result, error: true);
    }
  }
}

/// Create or edit one group.
class _GroupSheet extends StatefulWidget {
  const _GroupSheet({this.existing});

  final MaterialGroup? existing;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _minStock;
  late final TextEditingController _sortOrder;
  late final TextEditingController _notes;
  late String _kind;
  late String _colour;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    _unit = TextEditingController(text: g?.defaultUnit ?? 'kg');
    _minStock =
        TextEditingController(text: (g?.defaultMinStock ?? 0).toString());
    _sortOrder = TextEditingController(text: (g?.sortOrder ?? 0).toString());
    _notes = TextEditingController(text: g?.notes ?? '');
    _kind = g?.kind ?? 'other';
    _colour = g?.colour ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _minStock.dispose();
    _sortOrder.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _ready => _name.text.trim().isNotEmpty;

  void _submit() {
    if (!_ready) return;
    final g = widget.existing;
    Navigator.pop(
      context,
      MaterialGroup(
        id: g?.id ?? '',
        name: _name.text.trim(),
        code: g?.code ?? '',
        kind: _kind,
        colour: _colour,
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
        defaultUnit: _unit.text.trim().isEmpty ? 'kg' : _unit.text.trim(),
        defaultMinStock: double.tryParse(_minStock.text.trim()) ?? 0,
        notes: _notes.text.trim(),
        archived: g?.archived ?? false,
        materialCount: g?.materialCount,
        totalMaterialCount: g?.totalMaterialCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ErpColors.borderMid,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(isNew ? 'New material group' : 'Edit material group',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
              const SizedBox(height: 14),

              _field(_name, 'Name *', onChanged: (_) => setState(() {})),
              if (!isNew && widget.existing!.code.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'Code ${widget.existing!.code} — this does not change '
                    'when the name does. Renaming moves every material '
                    'filed under the old name.',
                    style: const TextStyle(
                        fontSize: 11, color: ErpColors.textMuted),
                  ),
                ),
              const SizedBox(height: 12),

              const Text('What does this group answer?',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 6),
              for (final e in kGroupKinds.entries)
                RadioListTile<String>(
                  value: e.key,
                  groupValue: _kind,
                  onChanged: (v) => setState(() => _kind = v ?? 'other'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(e.value.label,
                      style: const TextStyle(
                          fontSize: 13, color: ErpColors.textPrimary)),
                  subtitle: Text(e.value.hint,
                      style: const TextStyle(
                          fontSize: 11, color: ErpColors.textMuted)),
                ),
              const SizedBox(height: 8),

              const Text('Colour',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hex in kGroupSwatches)
                    GestureDetector(
                      onTap: () => setState(() => _colour = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: parseHexColour(hex),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _colour.toUpperCase() == hex.toUpperCase()
                                ? ErpColors.textPrimary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  // No colour chosen is a real state: the chip then
                  // falls back to the colour this app has always drawn
                  // that name in, rather than going grey.
                  GestureDetector(
                    onTap: () => setState(() => _colour = ''),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _colour.isEmpty
                              ? ErpColors.textPrimary
                              : ErpColors.borderLight,
                          width: _colour.isEmpty ? 2 : 1,
                        ),
                      ),
                      child: const Center(
                        child: Text('Default',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: ErpColors.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                      child: _field(_unit, 'Default unit')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(_minStock, 'Default min stock',
                          number: true)),
                ],
              ),
              const SizedBox(height: 12),
              _field(_sortOrder, 'Sort order', number: true),
              const SizedBox(height: 12),
              _field(_notes, 'Notes', lines: 2),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: _ready ? _submit : null,
                  child: Text(isNew ? 'Add group' : 'Save changes',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool number = false,
    int lines = 1,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        minLines: lines,
        maxLines: lines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
}

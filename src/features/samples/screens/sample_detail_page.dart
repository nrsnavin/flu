import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/sample_controllers.dart';
import '../models/sample.dart';
import 'sample_list_page.dart' show SampleStatusChip;

// ══════════════════════════════════════════════════════════════
//  ONE SAMPLE REQUEST
//
//  The log is the screen. The request itself is a header — written
//  once, never edited — and every change since is an entry with its
//  author and time, oldest first, which is the order somebody reads it
//  in when they are working out what was promised to a customer.
// ══════════════════════════════════════════════════════════════
class SampleDetailPage extends StatefulWidget {
  final String sampleId;
  const SampleDetailPage({super.key, required this.sampleId});

  @override
  State<SampleDetailPage> createState() => _SampleDetailPageState();
}

class _SampleDetailPageState extends State<SampleDetailPage> {
  late final SampleDetailController _c;
  final _update = TextEditingController();
  final _caption = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = Get.put(SampleDetailController(widget.sampleId),
        tag: widget.sampleId);
  }

  @override
  void dispose() {
    Get.delete<SampleDetailController>(tag: widget.sampleId, force: true);
    _update.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _toast(String? message, {bool ok = false}) {
    if (message == null) return;
    Get.snackbar(ok ? 'Done' : 'Error', message,
        backgroundColor:
            ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
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
        title: Obx(() {
          final s = _c.sample.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s == null ? "Sample" : s.code,
                  style: ErpTextStyles.pageTitle),
              Text(s?.title ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10)),
            ],
          );
        }),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Obx(() {
        if (_c.loading.value && _c.sample.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = _c.sample.value;
        if (s == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(_c.errorMsg.value ?? "Sample not found",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ErpColors.textSecondary)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _c.fetch,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              children: [
                _header(s),
                const SizedBox(height: 12),
                if (isAdminUser) ...[
                  _adminActions(s),
                  const SizedBox(height: 12),
                ],
                _log(s),
                const SizedBox(height: 12),
                _photos(s),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _header(SampleDetail s) {
    String qty(double v) =>
        v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

    return ErpSectionCard(
      title: "REQUEST",
      icon: Icons.science_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SampleStatusChip(status: s.status),
            const SizedBox(width: 8),
            if (s.ended && s.closedAt != null)
              Text("on ${DateFormat('dd MMM yyyy').format(s.closedAt!)}",
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          _kv("Customer",
              s.customerName.isEmpty ? "No customer named" : s.customerName),
          _kv("Raised by",
              "${s.raisedByName}${s.createdAt != null ? " · ${DateFormat('dd MMM yyyy').format(s.createdAt!)}" : ""}"),
          if (s.quantity > 0) _kv("Quantity", "${qty(s.quantity)} m"),
          if (s.targetDate != null)
            _kv("Wanted by", DateFormat('dd MMM yyyy').format(s.targetDate!)),
          _kv("Priority", s.priority),
          const SizedBox(height: 8),
          const Text("WHAT WAS ASKED FOR",
              style: TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(s.details,
              style: const TextStyle(
                  color: ErpColors.textPrimary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(k,
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11.5)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  // ── Admin actions ────────────────────────────────────────────
  Widget _adminActions(SampleDetail s) {
    final buttons = <Widget>[];

    if (s.status == 'open') {
      buttons.add(_action("Start work", Icons.play_arrow, ErpColors.accentBlue,
          () => _askStatus(s, 'in_progress')));
    }
    if (!s.ended) {
      buttons.add(_action("Mark completed", Icons.check_circle,
          ErpColors.successGreen, () => _askStatus(s, 'completed')));
      buttons.add(_action("Close", Icons.cancel_outlined,
          const Color(0xFFDC2626), () => _askStatus(s, 'closed')));
    } else {
      buttons.add(_action("Reopen", Icons.restart_alt, ErpColors.warningAmber,
          () => _askStatus(s, 'in_progress')));
    }

    return ErpSectionCard(
      title: "ADMIN",
      icon: Icons.admin_panel_settings_outlined,
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Widget _action(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _c.busy.value ? null : onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  /// Ending a sample, and undoing that, are both decisions somebody has
  /// to answer for — so both ask for a reason, and the server refuses
  /// without one either way.
  Future<void> _askStatus(SampleDetail s, String next) async {
    final terminal = isSampleTerminal(next);
    final reasonRequired = terminal || s.ended;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final ok = !reasonRequired || controller.text.trim().isNotEmpty;
          return AlertDialog(
            backgroundColor: ErpColors.bgSurface,
            title: Text("Mark ${sampleStatusLabel(next).toLowerCase()}?",
                style: const TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  terminal
                      ? "It stops taking updates and photos until an admin reopens it. Your reason goes into the log."
                      : s.ended
                          ? "Reopening undoes a decision somebody made — say why, and it goes into the log."
                          : "This goes into the log against your name.",
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setLocal(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: reasonRequired ? "Why?" : "Note (optional)",
                    hintStyle: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Cancel")),
              ElevatedButton(
                onPressed: ok ? () => Navigator.of(ctx).pop(true) : null,
                child: Text(sampleStatusLabel(next)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;
    final err = await _c.setStatus(next, controller.text);
    _toast(err ?? "Marked ${sampleStatusLabel(next).toLowerCase()}",
        ok: err == null);
  }

  // ── The log ──────────────────────────────────────────────────
  Widget _log(SampleDetail s) {
    return ErpSectionCard(
      title: "LOG",
      icon: Icons.forum_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...s.log.map(_entry),
          const Divider(height: 20, color: ErpColors.borderLight),
          if (s.ended)
            Text(
              "This sample is ${sampleStatusLabel(s.status).toLowerCase()}. An admin can reopen it to add more.",
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 12),
            )
          else ...[
            TextField(
              controller: _update,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    "e.g. Warped 60 m on loom 4. Shade a touch light against the card.",
                hintStyle:
                    const TextStyle(color: ErpColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: ErpColors.bgMuted,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: ErpColors.borderLight)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: ErpColors.borderLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                        color: ErpColors.accentBlue, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _c.busy.value
                    ? null
                    : () async {
                        final err = await _c.addUpdate(_update.text);
                        if (err == null) _update.clear();
                        _toast(err ?? "Update added", ok: err == null);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.edit_note, size: 16, color: Colors.white),
                label: const Text("Add to log",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _entry(SampleLogEntry e) {
    IconData icon;
    switch (e.kind) {
      case 'created':
        icon = Icons.flag_outlined;
        break;
      case 'status':
        icon = Icons.check_circle_outline;
        break;
      case 'photo':
        icon = Icons.photo_camera_outlined;
        break;
      case 'photo_removed':
        icon = Icons.hide_image_outlined;
        break;
      default:
        icon = Icons.chat_bubble_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: ErpColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary)),
                if (e.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(e.note,
                        style: const TextStyle(
                            color: ErpColors.textPrimary,
                            fontSize: 12.5,
                            height: 1.35)),
                  ),
                const SizedBox(height: 2),
                Text(
                  "${e.byName.isEmpty ? "—" : e.byName}"
                  "${e.at != null ? " · ${DateFormat('dd MMM yyyy, HH:mm').format(e.at!)}" : ""}",
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Photos ───────────────────────────────────────────────────
  Widget _photos(SampleDetail s) {
    return ErpSectionCard(
      title: "PHOTOS",
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.photos.isEmpty)
            const Text(
              "No photos yet. A shade card or a shot off the loom says more than the note under it.",
              style: TextStyle(color: ErpColors.textMuted, fontSize: 12),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: s.photos
                  .map((p) => _PhotoTile(
                        photo: p,
                        controller: _c,
                        onRemove: isAdminUser && !p.removed
                            ? () => _askRemovePhoto(p)
                            : null,
                      ))
                  .toList(),
            ),
          if (!s.ended) ...[
            const Divider(height: 20, color: ErpColors.borderLight),
            TextField(
              controller: _caption,
              style: const TextStyle(fontSize: 13),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Caption (optional)",
                labelStyle: ErpTextStyles.fieldLabel,
                hintText: "e.g. Trial off loom 4, shade slightly light",
                hintStyle:
                    const TextStyle(color: ErpColors.textMuted, fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: ErpColors.borderLight)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _c.busy.value
                    ? null
                    : () async {
                        final err = await _c.addPhoto(_caption.text);
                        if (err == null) _caption.clear();
                        _toast(err ?? "Photo added", ok: err == null);
                      },
                icon: const Icon(Icons.add_a_photo_outlined,
                    size: 16, color: ErpColors.accentBlue),
                label: const Text("Add photo",
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ErpColors.accentBlue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "This sample is ${sampleStatusLabel(s.status).toLowerCase()} — reopen it to add photos.",
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _askRemovePhoto(SamplePhoto p) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: ErpColors.bgSurface,
          title: const Text("Remove this photo?",
              style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "The photo comes down but the log keeps the entry that put it here, with your reason against it.",
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setLocal(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "e.g. Photo of the wrong sample",
                  hintStyle: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: controller.text.trim().length >= 3
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              child: const Text("Remove",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final err = await _c.removePhoto(p.id, controller.text);
    _toast(err ?? "Photo removed", ok: err == null);
  }
}

/// One tile.
///
/// A removed photo keeps its tile with the reason in place of the
/// image: the log says a photo was put here, and a gallery that quietly
/// lost one would contradict it.
class _PhotoTile extends StatelessWidget {
  final SamplePhoto photo;
  final SampleDetailController controller;
  final VoidCallback? onRemove;

  const _PhotoTile({
    required this.photo,
    required this.controller,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photo.removed) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: ErpColors.borderLight, style: BorderStyle.solid),
          color: ErpColors.bgMuted,
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hide_image_outlined,
                size: 20, color: ErpColors.textMuted),
            const SizedBox(height: 4),
            Text(
              photo.removalReason.isEmpty ? "Removed" : photo.removalReason,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 9.5),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _open(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _bytes(fit: BoxFit.cover),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  /// Fetched through the API client rather than Image.network: the file
  /// route is behind the auth gate and the cookie lives on that Dio, so
  /// a plain network image comes back 401 and renders nothing.
  Widget _bytes({BoxFit fit = BoxFit.cover}) {
    return FutureBuilder<Uint8List>(
      future: controller.photo(photo.id),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: ErpColors.bgMuted,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
          return Container(
            color: ErpColors.bgMuted,
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 20, color: ErpColors.textMuted),
            ),
          );
        }
        return Image.memory(snap.data!, fit: fit);
      },
    );
  }

  void _open(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ErpColors.bgSurface,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: _bytes(fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(photo.label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    "${photo.uploadedByName.isEmpty ? "—" : photo.uploadedByName}"
                    "${photo.createdAt != null ? " · ${DateFormat('dd MMM yyyy, HH:mm').format(photo.createdAt!)}" : ""}",
                    style: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Close")),
          ],
        ),
      ),
    );
  }
}

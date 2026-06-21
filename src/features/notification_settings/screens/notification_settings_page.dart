import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/notify_settings_controller.dart';
import 'recipient_events_sheet.dart';

// ══════════════════════════════════════════════════════════════
//  NOTIFICATION SETTINGS — admin-only
//  - Manual triggers for morning digest + evening report
//  - Add / remove WhatsApp recipients
//  - Surfaces provider state so a dry-run setup is obvious
// ══════════════════════════════════════════════════════════════

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _ctrl = NotifySettingsController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        title: const Text('WhatsApp Notifications',
            style: ErpTextStyles.pageTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _ctrl.refreshSettings,
          ),
        ],
      ),
      body: Obx(() {
        if (_ctrl.loading.value && _ctrl.recipients.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _ctrl.refreshSettings,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
            children: [
              _ProviderBanner(configured: _ctrl.providerConfigured.value),
              const SizedBox(height: 16),
              _SendNowSection(
                onMorning: () => _trigger(_ctrl.sendMorningDigestNow,
                    'Morning digest'),
                onEvening: () => _trigger(_ctrl.sendEveningReportNow,
                    'Evening report'),
                sendingDigest: _ctrl.sendingDigest.value,
                sendingEvening: _ctrl.sendingEvening.value,
              ),
              const SizedBox(height: 22),
              _RecipientsSection(
                recipients: _ctrl.recipients.toList(),
                saving: _ctrl.saving.value,
                onAdd: _showAddDialog,
                onRemove: _confirmRemove,
                onTap: (number) =>
                    RecipientEventsSheet.show(context, number),
              ),
              if (_ctrl.lastError.value.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: _ctrl.lastError.value),
              ],
            ],
          ),
        );
      }),
    );
  }

  // ── Actions ────────────────────────────────────────────────────
  Future<void> _trigger(
    Future<TriggerResult> Function() fn, String label,
  ) async {
    final r = await fn();
    if (!mounted) return;
    Get.snackbar(
      label, r.message,
      backgroundColor: r.ok ? ErpColors.successGreen : ErpColors.errorRed,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController(text: '+91');
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add WhatsApp recipient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: const InputDecoration(
                labelText: 'E.164 format',
                hintText: '+919876543210',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Country code + number, no spaces or dashes. The phone '
              'must have opted in to your WhatsApp sender on the '
              'provider side.',
              style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final ok = await _ctrl.addRecipient(controller.text);
              if (ok && ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added == true && mounted) {
      Get.snackbar(
        'Recipient added', controller.text.trim(),
        backgroundColor: ErpColors.successGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else if (_ctrl.lastError.value.isNotEmpty && mounted) {
      Get.snackbar(
        'Could not add', _ctrl.lastError.value,
        backgroundColor: ErpColors.errorRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _confirmRemove(String number) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove recipient?'),
        content: Text('$number will stop receiving WhatsApp notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ErpColors.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final saved = await _ctrl.removeRecipient(number);
    if (!mounted) return;
    Get.snackbar(
      saved ? 'Recipient removed' : 'Could not remove',
      saved ? number : _ctrl.lastError.value,
      backgroundColor: saved ? ErpColors.successGreen : ErpColors.errorRed,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Sections — kept widget-scoped (no state of their own) so the
// page rebuilds them cheaply on every Obx tick.
// ───────────────────────────────────────────────────────────────

class _ProviderBanner extends StatelessWidget {
  final bool configured;
  const _ProviderBanner({required this.configured});
  @override
  Widget build(BuildContext context) {
    if (configured) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.warningAmber),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: ErpColors.warningAmber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'WhatsApp provider is not configured. Triggers will '
              'render the message in dry-run mode (logged on the server, '
              'not sent). Set the Twilio env vars and restart.',
              style: TextStyle(color: ErpColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendNowSection extends StatelessWidget {
  final VoidCallback onMorning;
  final VoidCallback onEvening;
  final bool sendingDigest;
  final bool sendingEvening;
  const _SendNowSection({
    required this.onMorning,
    required this.onEvening,
    required this.sendingDigest,
    required this.sendingEvening,
  });
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Send a daily report now',
      icon: Icons.send_rounded,
      child: Column(
        children: [
          const Text(
            'Manually fires the same job the cron runs. Useful to '
            'verify recipients after a change or to re-send if a '
            'scheduled run was skipped.',
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SendButton(
                  label: 'Morning digest',
                  icon: Icons.wb_sunny_outlined,
                  loading: sendingDigest,
                  onPressed: sendingDigest ? null : onMorning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SendButton(
                  label: 'Evening report',
                  icon: Icons.nightlight_outlined,
                  loading: sendingEvening,
                  onPressed: sendingEvening ? null : onEvening,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;
  const _SendButton({
    required this.label, required this.icon,
    required this.loading, required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: ErpColors.accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      icon: loading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
          : Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _RecipientsSection extends StatelessWidget {
  final List<String> recipients;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onTap;
  const _RecipientsSection({
    required this.recipients,
    required this.saving,
    required this.onAdd,
    required this.onRemove,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Recipients',
      icon: Icons.contacts_outlined,
      trailing: IconButton(
        tooltip: 'Add',
        icon: const Icon(Icons.add_circle, color: ErpColors.accentBlue),
        onPressed: saving ? null : onAdd,
      ),
      child: recipients.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No recipients yet. Add the owner’s WhatsApp number '
                'to start receiving every event.',
                style: TextStyle(color: ErpColors.textSecondary),
              ),
            )
          : Column(
              children: [
                for (final number in recipients) _RecipientTile(
                  number: number,
                  onRemove: saving ? null : () => onRemove(number),
                  onTap: () => onTap(number),
                ),
                if (saving) const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              ],
            ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final String number;
  final VoidCallback? onRemove;
  final VoidCallback onTap;
  const _RecipientTile({
    required this.number,
    required this.onRemove,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.phone_iphone,
                color: ErpColors.accentLight, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(number,
                      style: const TextStyle(
                          color: ErpColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  const Text('Tap to filter events',
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: ErpColors.textMuted, size: 18),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.remove_circle_outline,
                  color: ErpColors.errorRed),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ErpColors.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ErpColors.errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: ErpColors.errorRed)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _Card({
    required this.title, required this.icon, required this.child,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ErpColors.accentBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const Divider(color: ErpColors.borderLight),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

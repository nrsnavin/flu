import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';

// Small pieces every Accounts screen uses, so they look like one place.

AppBar accountsAppBar(String title, {String subtitle = 'Accounts', List<Widget>? actions, PreferredSizeWidget? bottom}) =>
    AppBar(
      backgroundColor: ErpColors.navyDark,
      foregroundColor: ErpColors.textOnDark,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: ErpTextStyles.pageTitle),
          Text(subtitle, style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );

class AccountsCard extends StatelessWidget {
  const AccountsCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(13), this.borderColor});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Material(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor ?? ErpColors.borderLight),
            ),
            child: child,
          ),
        ),
      );
}

/// How money moves, in words.
String modeLabel(String m) => switch (m) {
      'cash' => 'Cash',
      'bank' => 'Bank transfer',
      'upi' => 'UPI',
      'cheque' => 'Cheque',
      'card' => 'Card',
      _ => m,
    };

Widget accountsLabel(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Text(s.toUpperCase(),
          style: TextStyle(fontSize: 10.5, letterSpacing: 0.7, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
    );

Widget accountsChip(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );

/// A message in the middle of a page, with a retry when one helps.
Widget accountsCentred(String text, {VoidCallback? onRetry}) => LayoutBuilder(
      builder: (_, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: box.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(text, textAlign: TextAlign.center, style: TextStyle(color: ErpColors.textSecondary)),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ]),
            ),
          ),
        ),
      ),
    );

void accountsToast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? ErpColors.solidError : ErpColors.solidSuccess,
    duration: Duration(seconds: msg.length > 80 ? 7 : 4),
  ));
}

/// Asks for a reason before something that cannot be undone, and
/// returns it — or null when the person backs out.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  int minLength = 3,
  String hint = 'Reason',
  Color? confirmColor,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title, message: message, confirm: confirm, minLength: minLength, hint: hint, confirmColor: confirmColor,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message, required this.confirm, required this.minLength, required this.hint, this.confirmColor});

  final String title, message, confirm, hint;
  final int minLength;
  final Color? confirmColor;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ctrl.text.trim().length >= widget.minLength;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.message, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: widget.hint, border: const OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
          style: widget.confirmColor == null ? null : FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          onPressed: ok ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

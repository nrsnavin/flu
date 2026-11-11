import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/money.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/accounts_models.dart';
import '../services/accounts_api.dart';
import 'accounts_widgets.dart';
import 'approvals_page.dart';
import 'bill_inbox_page.dart';
import 'cash_forecast_page.dart';
import 'collections_page.dart';
import 'month_end_page.dart';
import 'voucher_entry_page.dart';

// ══════════════════════════════════════════════════════════════
//  ACCOUNTS ON A PHONE
//
//  Not the books — those stay at a desk, with Tally and the GST returns.
//  This is the part of the money that cannot wait for one: where the
//  cash is, who owes it, what is waiting for a yes or a no. The page
//  opens on the balances, then the server's own inbox of what needs
//  doing (GET /accounts/inbox), each line going where it is done.
// ══════════════════════════════════════════════════════════════

class AccountsHomePage extends StatefulWidget {
  const AccountsHomePage({super.key});

  @override
  State<AccountsHomePage> createState() => _AccountsHomePageState();
}

class _AccountsHomePageState extends State<AccountsHomePage> {
  AccountsInbox? _inbox;
  AccountsOverview? _overview;
  Banking? _banking;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([AccountsApi.inbox(), AccountsApi.overview(), AccountsApi.banking()]);
      if (!mounted) return;
      setState(() {
        _inbox = r[0] as AccountsInbox;
        _overview = r[1] as AccountsOverview;
        _banking = r[2] as Banking;
      });
    } catch (e) {
      if (mounted) setState(() => _error = accountsMessage(e, 'Could not load Accounts'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _go(Widget page) async {
    await Get.to(() => page);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: accountsAppBar('Accounts', subtitle: 'Money in, money out'),
      body: () {
        if (_loading && _inbox == null) return const Center(child: CircularProgressIndicator());
        if (_inbox == null) return accountsCentred(_error ?? 'Could not load Accounts', onRetry: _load);
        final inbox = _inbox!;
        final ov = _overview ?? const AccountsOverview();
        final bank = _banking ?? const Banking();
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              _Balances(banking: bank),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _owed('Owed to us', ov.receivable, ov.receivableOverdue)),
                const SizedBox(width: 10),
                Expanded(child: _owed('We owe', ov.payable, ov.payableOverdue)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _go(const VoucherEntryPage(kind: 'receipt')),
                    icon: const Icon(Icons.south_west_rounded, size: 18),
                    label: const Text('Receive money'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _go(const VoucherEntryPage(kind: 'payment')),
                    icon: const Icon(Icons.north_east_rounded, size: 18),
                    label: const Text('Pay a supplier'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              accountsLabel('Needs you'),
              ..._needs(inbox),
              const SizedBox(height: 16),
              accountsLabel('Look ahead'),
              _link(Icons.show_chart_rounded, 'Cash forecast', 'What comes in and goes out, week by week',
                  () => _go(const CashForecastPage())),
              const SizedBox(height: 8),
              _link(Icons.fact_check_outlined, 'Month end', 'What is left before last month can be closed',
                  () => _go(const MonthEndPage())),
            ],
          ),
        );
      }(),
    );
  }

  List<Widget> _needs(AccountsInbox i) {
    final rows = <Widget>[];
    void add(InboxGroup g, IconData icon, String title, String what, {VoidCallback? onTap, bool web = false}) {
      if (g.count <= 0) return;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AccountsCard(
          onTap: onTap,
          child: Row(children: [
            Icon(icon, color: web ? ErpColors.textMuted : ErpColors.accentBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
                Text(web ? '$what — done on the web' : what,
                    style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${g.count}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
              if (g.amount > 0) Text(inr0(g.amount), style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
            ]),
            if (onTap != null) Icon(Icons.chevron_right, color: ErpColors.textMuted),
          ]),
        ),
      ));
    }

    add(i.approvals, Icons.how_to_reg_outlined, 'Expenses to approve', 'Claims and expenses waiting for a yes or a no',
        onTap: () => _go(const ApprovalsPage()));
    add(i.claimsToPay, Icons.payments_outlined, 'Claims to pay back', 'Approved, not yet paid to the person',
        onTap: () => _go(const ApprovalsPage(initialTab: 1)));
    add(i.toChase, Icons.call_outlined, 'Customers to chase', 'Overdue, with what to do next',
        onTap: () => _go(const CollectionsPage()));
    add(i.promisesDue, Icons.event_available_outlined, 'Promises due', 'Customers who said they would pay by now',
        onTap: () => _go(const CollectionsPage()));
    add(i.billsDue, Icons.receipt_long_outlined, 'Supplier bills due', 'Due or overdue to pay',
        onTap: () => _go(const VoucherEntryPage(kind: 'payment')));
    add(i.msmeDue, Icons.gavel_outlined, 'MSME bills near 45 days', 'Micro and small suppliers must be paid within 45 days',
        onTap: () => _go(const VoucherEntryPage(kind: 'payment')));
    add(i.mailedBills, Icons.mark_email_unread_outlined, 'Bills in the mailbox', 'Read from mail, waiting to be checked',
        onTap: () => _go(const BillInboxPage()));
    add(i.chequesDue, Icons.money_outlined, 'Cheques to deposit', 'Their date has come', web: true);
    add(i.statementsDue, Icons.account_balance_outlined, 'Bank statements due', 'No statement this week', web: true);
    if (i.bankLines > 0) {
      add(InboxGroup(count: i.bankLines), Icons.compare_arrows_rounded, 'Bank lines to match', 'Lines on a statement not yet in the books', web: true);
    }
    if (rows.isEmpty) {
      rows.add(AccountsCard(
        child: Text('Nothing waiting. Every approval, claim and chase is up to date.',
            style: TextStyle(color: ErpColors.textSecondary)),
      ));
    }
    return rows;
  }

  Widget _owed(String label, double total, double overdue) => AccountsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 9.5, letterSpacing: 0.5, fontWeight: FontWeight.w700, color: ErpColors.textMuted)),
          const SizedBox(height: 4),
          Text(inr0(total), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
          Text(overdue > 0 ? '${inr0(overdue)} overdue' : 'nothing overdue',
              style: TextStyle(fontSize: 11.5, color: overdue > 0 ? ErpColors.errorRed : ErpColors.textMuted)),
        ]),
      );

  Widget _link(IconData icon, String title, String what, VoidCallback onTap) => AccountsCard(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: ErpColors.accentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
              Text(what, style: TextStyle(fontSize: 11.5, color: ErpColors.textMuted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: ErpColors.textMuted),
        ]),
      );
}

/// Where the money is, first: the cash and bank on one line, each
/// account under it.
class _Balances extends StatelessWidget {
  const _Balances({required this.banking});

  final Banking banking;

  @override
  Widget build(BuildContext context) {
    final b = banking;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ErpColors.navyDark, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CASH AND BANK',
            style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10, letterSpacing: 0.7, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(inr0(b.bank + b.cash),
            style: TextStyle(color: ErpColors.textOnDark, fontSize: 28, fontWeight: FontWeight.w800)),
        if (b.chequesInHand > 0)
          Text('+ ${inr0(b.chequesInHand)} in cheques not yet deposited',
              style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11.5)),
        if (b.accounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final a in b.accounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(
                  switch (a.kind) {
                    'cash' => Icons.payments_outlined,
                    'card' => Icons.credit_card,
                    'upi' => Icons.qr_code_2,
                    _ => Icons.account_balance_outlined,
                  },
                  size: 16,
                  color: ErpColors.textOnDarkSub,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(a.name, style: TextStyle(color: ErpColors.textOnDark, fontSize: 13))),
                Text(inr(a.balance),
                    style: TextStyle(
                        color: a.balance < 0 ? const Color(0xFFFCA5A5) : ErpColors.textOnDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
        ],
      ]),
    );
  }
}

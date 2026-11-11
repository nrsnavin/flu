// ══════════════════════════════════════════════════════════════
//  ACCOUNTS — what the server sends (api/accounts*.js)
//
//  Mirrors prod_web/src/features/accounts/types.ts for the parts the
//  phone shows: the inbox of what needs doing, balances, collections,
//  open documents for a receipt or payment, expenses waiting for a
//  decision, the bills mailbox, the cash forecast and the month-end
//  checklist. Every field tolerates being absent.
// ══════════════════════════════════════════════════════════════

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _s(Object? v) => v?.toString() ?? '';
DateTime? _date(Object? v) =>
    v == null || '$v'.isEmpty ? null : DateTime.tryParse('$v')?.toLocal();
Map<String, dynamic> _m(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];
String _id(Object? v) => v is Map ? _s(v['_id']) : _s(v);

/// A count, what it adds up to, and the first few rows of it.
class InboxGroup {
  const InboxGroup({this.count = 0, this.amount = 0, this.top = const []});

  final int count;
  final double amount;
  final List<Map<String, dynamic>> top;

  factory InboxGroup.fromJson(Object? raw) {
    final j = _m(raw);
    return InboxGroup(count: _i(j['count']), amount: _d(j['amount']), top: _maps(j['top']));
  }
}

/// Everything in the books waiting for somebody (GET /accounts/inbox).
class AccountsInbox {
  const AccountsInbox({
    this.approvals = const InboxGroup(),
    this.claimsToPay = const InboxGroup(),
    this.billsDue = const InboxGroup(),
    this.toChase = const InboxGroup(),
    this.promisesDue = const InboxGroup(),
    this.mailedBills = const InboxGroup(),
    this.chequesDue = const InboxGroup(),
    this.statementsDue = const InboxGroup(),
    this.bankLines = 0,
    this.msmeDue = const InboxGroup(),
  });

  final InboxGroup approvals, claimsToPay, billsDue, toChase, promisesDue,
      mailedBills, chequesDue, statementsDue, msmeDue;
  final int bankLines;

  factory AccountsInbox.fromJson(Map<String, dynamic> j) => AccountsInbox(
        approvals: InboxGroup.fromJson(j['approvals']),
        claimsToPay: InboxGroup.fromJson(j['claimsToPay']),
        billsDue: InboxGroup.fromJson(j['billsDue']),
        toChase: InboxGroup.fromJson(j['toChase']),
        promisesDue: InboxGroup.fromJson(j['promisesDue']),
        mailedBills: InboxGroup.fromJson(j['mailedBills']),
        chequesDue: InboxGroup.fromJson(j['chequesDue']),
        statementsDue: InboxGroup.fromJson(j['statementsDue']),
        bankLines: _i(_m(j['bankLines'])['count']),
        msmeDue: InboxGroup.fromJson(j['msmeDue']),
      );
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    this.kind = 'bank',
    this.balance = 0,
    this.active = true,
    this.isDefault = false,
    this.chequesInHand = 0,
  });

  final String id, name;

  /// bank, cash, upi or card.
  final String kind;
  final double balance;
  final bool active, isDefault;
  final double chequesInHand;

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: _s(j['_id']),
        name: _s(j['name']),
        kind: _s(j['kind']).isEmpty ? 'bank' : _s(j['kind']),
        balance: _d(j['balance']),
        active: j['active'] != false,
        isDefault: j['isDefault'] == true,
        chequesInHand: _d(_m(j['chequesInHand'])['amount']),
      );

  /// The modes money can move through this account by — the server's
  /// rules (api/accountsCommon.js createVoucher): cash only through the
  /// cash box and the cash box only by cash; a credit card only by card;
  /// a card payment only through a card or a bank account.
  List<String> get modes => switch (kind) {
        'cash' => const ['cash'],
        'card' => const ['card'],
        'upi' => const ['upi', 'bank', 'cheque'],
        _ => const ['bank', 'upi', 'cheque', 'card'],
      };
}

/// Balances across the accounts (GET /accounts/banking).
class Banking {
  const Banking({this.accounts = const [], this.bank = 0, this.cash = 0, this.card = 0, this.chequesInHand = 0});

  final List<BankAccount> accounts;
  final double bank, cash, card, chequesInHand;

  factory Banking.fromJson(Map<String, dynamic> j) {
    final t = _m(j['totals']);
    return Banking(
      accounts: _maps(j['accounts']).map(BankAccount.fromJson).where((a) => a.active).toList(),
      bank: _d(t['bank']),
      cash: _d(t['cash']),
      card: _d(t['card']),
      chequesInHand: _d(t['chequesInHand']),
    );
  }
}

/// What is owed to us and by us (GET /accounts/overview).
class AccountsOverview {
  const AccountsOverview({
    this.receivable = 0,
    this.receivableOverdue = 0,
    this.payable = 0,
    this.payableOverdue = 0,
    this.pendingExpenses = 0,
  });

  final double receivable, receivableOverdue, payable, payableOverdue;
  final int pendingExpenses;

  factory AccountsOverview.fromJson(Map<String, dynamic> j) {
    final r = _m(j['receivables']);
    final p = _m(j['payables']);
    return AccountsOverview(
      receivable: _d(r['total']),
      receivableOverdue: _d(r['overdue']),
      payable: _d(p['total']),
      payableOverdue: _d(p['overdue']),
      pendingExpenses: _i(j['pendingExpenses']),
    );
  }
}

/// An open invoice, bill or expense a receipt or payment can settle.
class OpenDoc {
  const OpenDoc({
    required this.docType,
    required this.id,
    required this.docNo,
    this.refNo = '',
    this.date,
    this.dueDate,
    this.amount = 0,
    this.outstanding = 0,
    this.overdueDays = 0,
    this.tdsSection = '',
  });

  /// Invoice, SupplierBill, Expense or OpeningBalance.
  final String docType;
  final String id, docNo;

  /// The supplier's own number on a bill.
  final String refNo;
  final DateTime? date, dueDate;
  final double amount, outstanding;
  final int overdueDays;

  /// Set when the bill carries TDS, which is deducted when it is paid.
  final String tdsSection;

  String get kindLabel => switch (docType) {
        'Invoice' => 'Invoice',
        'SupplierBill' => 'Bill',
        'Expense' => 'Expense',
        'OpeningBalance' => 'Opening balance',
        _ => docType,
      };

  factory OpenDoc.fromJson(Map<String, dynamic> j) => OpenDoc(
        docType: _s(j['docType']),
        id: _s(j['id'] ?? j['_id']),
        docNo: _s(j['docNo']),
        refNo: _s(j['refNo']),
        date: _date(j['date']),
        dueDate: _date(j['dueDate']),
        amount: _d(j['amount']),
        outstanding: _d(j['outstanding']),
        overdueDays: _i(j['overdueDays']),
        tdsSection: j['tds'] is Map ? _s(_m(j['tds'])['section']).ifEmpty('TDS') : '',
      );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// A customer with money overdue, and what to do about it
/// (GET /accounts/collections).
class CollectionRow {
  const CollectionRow({
    required this.party,
    required this.partyName,
    this.total = 0,
    this.overdue = 0,
    this.oldestDays = 0,
    this.count = 0,
    this.nextAction = 'remind',
    this.nextTone = 'gentle',
    this.nextLabel = '',
    this.phone = '',
    this.contactName = '',
    this.promiseDate,
    this.promiseAmount = 0,
    this.promiseBroken = false,
    this.promiseNote = '',
    this.lastContact = '',
    this.lastContactAt,
    this.lastNote = '',
    this.recentlyContacted = false,
    this.held = false,
    this.docs = const [],
    this.onAccount = 0,
  });

  final String party, partyName;
  final double total, overdue;
  final int oldestDays, count;

  /// remind, call, escalate or apply (what they paid ahead covers it).
  final String nextAction, nextTone, nextLabel;
  final String phone, contactName;
  final DateTime? promiseDate;
  final double promiseAmount;
  final bool promiseBroken;
  final String promiseNote;
  final String lastContact;
  final DateTime? lastContactAt;
  final String lastNote;

  /// Contacted in the last seven days: the server gives them the week.
  final bool recentlyContacted;

  /// A promise to pay that has not come due yet: not chased till then.
  final bool held;
  final List<OpenDoc> docs;
  final double onAccount;

  factory CollectionRow.fromJson(Map<String, dynamic> j) {
    final next = _m(j['next']);
    final contact = _m(j['contact']);
    final promise = _m(j['promise']);
    final last = _m(j['lastContact']);
    final phone = _s(contact['accountantPhone']).isNotEmpty ? _s(contact['accountantPhone']) : _s(contact['phone']);
    return CollectionRow(
      party: _s(j['party']),
      partyName: _s(j['partyName']),
      total: _d(j['total']),
      overdue: _d(j['overdue']),
      oldestDays: _i(j['oldestDays']),
      count: _i(j['count']),
      nextAction: _s(next['action']).isEmpty ? 'remind' : _s(next['action']),
      nextTone: _s(next['tone']).isEmpty ? 'gentle' : _s(next['tone']),
      nextLabel: _s(next['label']),
      phone: phone,
      contactName: _s(contact['accountant']).isNotEmpty ? _s(contact['accountant']) : _s(contact['name']),
      promiseDate: promise.isEmpty ? null : _date(promise['date']),
      promiseAmount: _d(promise['amount']),
      promiseBroken: promise['broken'] == true,
      promiseNote: _s(promise['note']),
      lastContact: [
        _s(last['kind']),
        if (_s(last['channel']).isNotEmpty) 'by ${_s(last['channel'])}',
        if (_s(last['byName']).isNotEmpty) '· ${_s(last['byName'])}',
      ].where((s) => s.isNotEmpty).join(' '),
      lastContactAt: _date(last['at']),
      lastNote: _s(last['note']),
      recentlyContacted: j['recentlyContacted'] == true,
      held: j['held'] == true,
      docs: _maps(j['docs']).map(OpenDoc.fromJson).toList(),
      onAccount: _d(j['onAccount']),
    );
  }
}

/// An expense or claim waiting for a decision or for payment.
class ExpenseRow {
  const ExpenseRow({
    required this.id,
    this.expenseNo = '',
    this.date,
    this.categoryName = '',
    this.description = '',
    this.payeeName = '',
    this.amount = 0,
    this.paidAmount = 0,
    this.status = 'pending',
    this.submittedBy = '',
    this.isClaim = false,
    this.attachments = 0,
  });

  final String id, expenseNo;
  final DateTime? date;
  final String categoryName, description, payeeName;
  final double amount, paidAmount;
  final String status, submittedBy;
  final bool isClaim;
  final int attachments;

  double get toPay => (amount - paidAmount) > 0 ? amount - paidAmount : 0;

  factory ExpenseRow.fromJson(Map<String, dynamic> j) => ExpenseRow(
        id: _s(j['_id']),
        expenseNo: _s(j['expenseNo']),
        date: _date(j['date']),
        categoryName: _s(j['categoryName']),
        description: _s(j['description']),
        payeeName: _s(j['payeeName']),
        amount: _d(_m(j['totals'])['grand']),
        paidAmount: _d(j['paidAmount']),
        status: _s(j['status']).isEmpty ? 'pending' : _s(j['status']),
        submittedBy: _s(j['submittedByName']),
        isClaim: j['source'] == 'claim' || j['claimant'] != null,
        attachments: j['attachments'] is List ? (j['attachments'] as List).length : 0,
      );
}

/// A bill that came to the bills mailbox, read and waiting.
class MailedBill {
  const MailedBill({
    required this.id,
    this.supplierName = '',
    this.from = '',
    this.subject = '',
    this.receivedAt,
    this.filename = '',
    this.contentType = '',
    this.grand,
    this.billNo = '',
    this.billDate,
    this.alreadyEntered,
    this.senderKnown = false,
    this.supplierMatched = false,
  });

  final String id, supplierName, from, subject;
  final DateTime? receivedAt;
  final String filename, contentType;
  final double? grand;
  final String billNo;
  final DateTime? billDate;

  /// The bill already in the books with this number, if any.
  final String? alreadyEntered;
  final bool senderKnown, supplierMatched;

  bool get isImage => contentType.startsWith('image/');

  factory MailedBill.fromJson(Map<String, dynamic> j) => MailedBill(
        id: _s(j['_id']),
        supplierName: _s(j['supplierName']),
        from: _s(j['from']),
        subject: _s(j['subject']),
        receivedAt: _date(j['receivedAt']),
        filename: _s(j['filename']),
        contentType: _s(j['contentType']),
        grand: j['grand'] == null ? null : _d(j['grand']),
        billNo: _s(j['billNo']),
        billDate: _date(j['billDate']),
        alreadyEntered: j['alreadyEntered'] == null || '${j['alreadyEntered']}'.isEmpty ? null : _s(j['alreadyEntered']),
        senderKnown: j['senderKnown'] == true,
        supplierMatched: j['supplier'] != null && '${j['supplier']}'.isNotEmpty,
      );
}

/// One expected movement: an invoice likely to be paid, a bill falling
/// due, a salary run — and why the server put it in that week.
class ForecastLine {
  const ForecastLine({this.party = '', this.docNo = '', this.amount = 0, this.inflow = true, this.basis = '', this.date});

  final String party, docNo;
  final double amount;
  final bool inflow;
  final String basis;
  final DateTime? date;

  factory ForecastLine.fromJson(Map<String, dynamic> j) => ForecastLine(
        party: _s(j['party']),
        docNo: _s(j['docNo']),
        amount: _d(j['amount']),
        inflow: j['direction'] != 'out',
        basis: _s(j['basis']),
        date: _date(j['date']),
      );
}

class ForecastWeek {
  const ForecastWeek({this.from, this.to, this.inflow = 0, this.outflow = 0, this.closing = 0, this.items = const []});

  final DateTime? from, to;
  final double inflow, outflow, closing;

  /// Every movement in the week, biggest first.
  final List<ForecastLine> items;

  factory ForecastWeek.fromJson(Map<String, dynamic> j) => ForecastWeek(
        from: _date(j['from']),
        to: _date(j['to']),
        inflow: _d(j['inflow']),
        outflow: _d(j['outflow']),
        closing: _d(j['closing']),
        items: _maps(j['items'] ?? j['top']).map(ForecastLine.fromJson).toList(),
      );
}

/// Cash over the next weeks (GET /accounts/forecast).
class CashForecast {
  const CashForecast({this.opening = 0, this.weeks = const [], this.firstShortWeek, this.laterIn = 0, this.laterOut = 0});

  final double opening;
  final List<ForecastWeek> weeks;
  final DateTime? firstShortWeek;
  final double laterIn, laterOut;

  factory CashForecast.fromJson(Map<String, dynamic> j) => CashForecast(
        opening: _d(j['opening']),
        weeks: _maps(j['weeks']).map(ForecastWeek.fromJson).toList(),
        firstShortWeek: _date(j['firstShortWeek']),
        laterIn: _d(_m(j['later'])['inflow']),
        laterOut: _d(_m(j['later'])['outflow']),
      );
}

class CloseItem {
  const CloseItem({required this.key, required this.label, this.detail = '', this.count = 0, this.amount, this.ok = false});

  final String key, label, detail;
  final int count;
  final double? amount;
  final bool ok;

  factory CloseItem.fromJson(Map<String, dynamic> j) => CloseItem(
        key: _s(j['key']),
        label: _s(j['label']),
        detail: _s(j['detail']),
        count: _i(j['count']),
        amount: j['amount'] == null ? null : _d(j['amount']),
        ok: j['ok'] == true,
      );
}

/// What is left before a month can be closed (GET /accounts/close).
class CloseChecklist {
  const CloseChecklist({this.month = '', this.items = const [], this.done = 0, this.total = 0});

  final String month;
  final List<CloseItem> items;
  final int done, total;

  factory CloseChecklist.fromJson(Map<String, dynamic> j) => CloseChecklist(
        month: _s(j['month']),
        items: _maps(j['items']).map(CloseItem.fromJson).toList(),
        done: _i(j['done']),
        total: _i(j['total']),
      );
}

/// A check before money goes out: a changed bank account, a payment twice.
class PaymentFlag {
  const PaymentFlag({required this.code, required this.severity, required this.message});

  final String code;

  /// danger, warning or info.
  final String severity;
  final String message;

  factory PaymentFlag.fromJson(Map<String, dynamic> j) =>
      PaymentFlag(code: _s(j['code']), severity: _s(j['severity']), message: _s(j['message']));
}

/// A customer or supplier from the search.
class Party {
  const Party({required this.id, required this.name, this.gstin = ''});

  final String id, name, gstin;

  factory Party.fromJson(Map<String, dynamic> j) =>
      Party(id: _id(j['_id'] ?? j['id']), name: _s(j['name']), gstin: _s(j['gstin']));
}

/// A receipt or payment voucher as it came back.
class Voucher {
  const Voucher({required this.id, this.voucherNo = '', this.amount = 0, this.partyName = ''});

  final String id, voucherNo, partyName;
  final double amount;

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
        id: _s(j['_id']),
        voucherNo: _s(j['voucherNo']),
        amount: _d(j['amount']),
        partyName: _s(j['partyName']),
      );
}

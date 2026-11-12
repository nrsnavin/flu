import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../../core/request_id.dart';
import '../models/accounts_models.dart';
import '../voucher_math.dart' show Allocation;

// ══════════════════════════════════════════════════════════════
//  ACCOUNTS API — /api/v2/accounts, and the party pickers
//
//  Behind the Accounts permission (app.js). Approving and rejecting an
//  expense also want the admin or accounts role, and never the person
//  who entered it — the server says so in words, which the screens show.
// ══════════════════════════════════════════════════════════════

String accountsMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.response?.statusCode == 403) return 'You do not have access to this in Accounts.';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check the connection and try again.';
    }
  }
  return fallback;
}

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class AccountsApi {
  static final Dio _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/accounts',
    // Drafting a reminder is a model call.
    timeout: const Duration(seconds: 45),
  );
  static final Dio _root = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

  static Map<String, dynamic> _body(Response r) => Map<String, dynamic>.from(r.data as Map);
  static List<Map<String, dynamic>> _list(Object? v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  // ── What needs doing, and where the money is ──────────────────
  static Future<AccountsInbox> inbox() async => AccountsInbox.fromJson(_body(await _dio.get('/inbox')));
  static Future<AccountsOverview> overview() async => AccountsOverview.fromJson(_body(await _dio.get('/overview')));
  static Future<Banking> banking() async => Banking.fromJson(_body(await _dio.get('/banking')));

  static Future<List<BankAccount>> bankAccounts() async =>
      _list(_body(await _dio.get('/bank-accounts'))['accounts']).map(BankAccount.fromJson).where((a) => a.active).toList();

  // ── Collections ───────────────────────────────────────────────
  /// Customers with money overdue. [held] also brings those who promised
  /// to pay by a day not yet come — the server leaves them out otherwise.
  static Future<({List<CollectionRow> rows, double total, bool whatsapp})> collections({bool held = true}) async {
    final b = _body(await _dio.get('/collections', queryParameters: {if (held) 'held': 'true'}));
    return (
      rows: _list(b['rows']).map(CollectionRow.fromJson).toList(),
      total: (b['total'] as num?)?.toDouble() ?? 0,
      whatsapp: b['whatsapp'] == true,
    );
  }

  /// A reminder written for this customer; nothing is sent.
  static Future<({String message, String to, String tone})> draftReminder(String customer, {String? tone}) async {
    final b = _body(await _dio.post('/collections/draft', data: {'customer': customer, if (tone != null) 'tone': tone}));
    return (message: '${b['message'] ?? ''}', to: '${b['to'] ?? ''}', tone: '${b['tone'] ?? tone ?? ''}');
  }

  /// Sent on the company's WhatsApp line, to a number on file.
  static Future<({bool sent, bool dryRun, String error})> sendReminder({
    required String to,
    required String message,
    required String customer,
    String tone = '',
  }) async {
    final b = _body(await _dio.post('/collections/send',
        data: {'to': to, 'message': message, 'customer': customer, 'tone': tone}));
    return (sent: b['sent'] == true, dryRun: b['dryRun'] == true, error: '${b['error'] ?? ''}');
  }

  /// A call made, a promise to pay, or a note, remembered against the
  /// customer so tomorrow's list knows (kind: call, promise or note).
  static Future<void> logCollection({
    required String customer,
    required String kind,
    String note = '',
    DateTime? promiseDate,
    double? promiseAmount,
  }) =>
      _dio.post('/collections/log', data: {
        'customer': customer,
        'kind': kind,
        if (kind == 'call') 'channel': 'phone',
        if (note.trim().isNotEmpty) 'note': note.trim(),
        if (promiseDate != null) 'promiseDate': _ymd(promiseDate),
        if (promiseAmount != null && promiseAmount > 0) 'promiseAmount': promiseAmount,
      });

  // ── Receipts and payments ─────────────────────────────────────
  static Future<List<Party>> parties(String partyType, String search) async {
    final res = partyType == 'customer'
        ? await _root.get('/customer/all-customers', queryParameters: {'page': 1, 'limit': 20, 'search': search})
        : await _root.get('/supplier/get-suppliers', queryParameters: {'page': 1, 'limit': 20, 'search': search});
    final b = _body(res);
    return _list(b[partyType == 'customer' ? 'customers' : 'suppliers']).map(Party.fromJson).toList();
  }

  static Future<({List<OpenDoc> docs, double balance})> openDocs(String partyType, String party) async {
    final b = _body(await _dio.get('/payments/open-docs', queryParameters: {'partyType': partyType, 'party': party}));
    return (docs: _list(b['docs']).map(OpenDoc.fromJson).toList(), balance: (b['balance'] as num?)?.toDouble() ?? 0);
  }

  /// Before money goes out: a changed or shared bank account, a payment
  /// made twice, and the like.
  static Future<List<PaymentFlag>> checkPayment(Map<String, dynamic> body) async =>
      _list(_body(await _dio.post('/payments/check', data: body))['flags']).map(PaymentFlag.fromJson).toList();

  /// The body of a receipt or payment, as POST /accounts/payments and
  /// its /check take it. [amount] is the money that moves; each
  /// allocation's amount is what comes off its document, which on a
  /// bill carrying TDS is more than the money paid for it (the server
  /// works the TDS out again, by the same sum). [riskNote] says how a
  /// flagged payment — a bank account changed lately, or shared with
  /// another supplier — was confirmed; the server will not pay one
  /// without it.
  static Map<String, dynamic> voucherBody({
    required String kind,
    required String partyType,
    required String party,
    required double amount,
    required String mode,
    required String account,
    required DateTime date,
    required List<Allocation> allocations,
    String reference = '',
    String chequeNo = '',
    String chequeBank = '',
    DateTime? chequeDate,
    String narration = '',
    String riskNote = '',
  }) =>
      {
        'kind': kind,
        'partyType': partyType,
        partyType: party,
        'amount': amount,
        'mode': mode,
        'account': account,
        'date': _ymd(date),
        if (reference.trim().isNotEmpty) 'reference': reference.trim(),
        if (narration.trim().isNotEmpty) 'narration': narration.trim(),
        if (mode == 'cheque')
          'cheque': {
            'number': chequeNo.trim(),
            if (chequeBank.trim().isNotEmpty) 'bank': chequeBank.trim(),
            'date': _ymd(chequeDate ?? date),
          },
        'allocations': [
          for (final a in allocations)
            if (a.amount > 0) {'docType': a.doc.docType, 'doc': a.doc.id, 'amount': a.amount},
        ],
        if (riskNote.trim().isNotEmpty) ...{'confirmRisk': true, 'riskNote': riskNote.trim()},
      };

  /// Posts a voucher body from [voucherBody]. The same [requestId] sent
  /// twice comes back as the first voucher, not a second one.
  static Future<Voucher> createVoucher(Map<String, dynamic> body, {required String requestId}) async {
    final b = _body(await _dio.post('/payments', data: {...body, 'requestId': requestId}));
    return Voucher.fromJson(Map<String, dynamic>.from(b['payment'] as Map));
  }

  // ── Expenses and claims ───────────────────────────────────────
  static Future<List<ExpenseRow>> expenses(String status) async {
    final b = _body(await _dio.get('/expenses', queryParameters: {'status': status, 'limit': 50}));
    return _list(b['expenses']).map(ExpenseRow.fromJson).toList();
  }

  static Future<void> approveExpense(String id, {String note = '', String? payFrom, String mode = ''}) =>
      _dio.post('/expenses/$id/approve', data: {
        if (note.trim().isNotEmpty) 'note': note.trim(),
        if (payFrom != null) 'payNow': {'account': payFrom, if (mode.isNotEmpty) 'mode': mode},
      });

  static Future<void> rejectExpense(String id, String reason) =>
      _dio.post('/expenses/$id/reject', data: {'reason': reason});

  // One id for one payment. The same expense paid the same way again —
  // a second tap, a resend after a timeout whose first attempt did land
  // — carries the same id, and the server answers with the voucher the
  // first made. The id is let go once the payment has gone through.
  static final Map<String, String> _payIds = {};

  static Future<String> payExpense(String id, {required String account, required String mode, String reference = ''}) async {
    final what = '$id|$account|$mode|${reference.trim()}';
    final requestId = _payIds.putIfAbsent(what, newRequestId);
    final b = _body(await _dio.post('/expenses/$id/pay', data: {
      'account': account,
      'mode': mode,
      if (reference.trim().isNotEmpty) 'reference': reference.trim(),
      'requestId': requestId,
    }));
    _payIds.remove(what);
    return '${(b['voucher'] as Map?)?['voucherNo'] ?? ''}';
  }

  // ── The bills mailbox ─────────────────────────────────────────
  static Future<List<MailedBill>> mailedBills() async =>
      _list(_body(await _dio.get('/bill-inbox', queryParameters: {'status': 'new'}))['bills']).map(MailedBill.fromJson).toList();

  static Future<Uint8List> mailedBillFile(String id) async {
    final res = await _dio.get<List<int>>('/bill-inbox/$id/file', options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(res.data ?? const []);
  }

  static Future<void> dismissMailedBill(String id, String reason) =>
      _dio.post('/bill-inbox/$id/dismiss', data: {'reason': reason});

  // ── Read-only views ───────────────────────────────────────────
  static Future<CashForecast> forecast({int weeks = 6}) async =>
      CashForecast.fromJson(_body(await _dio.get('/forecast', queryParameters: {'weeks': weeks})));

  static Future<CloseChecklist> closeChecklist({String? month}) async =>
      CloseChecklist.fromJson(_body(await _dio.get('/close', queryParameters: {if (month != null) 'month': month})));
}

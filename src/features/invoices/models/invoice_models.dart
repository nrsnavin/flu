// ══════════════════════════════════════════════════════════════
//  INVOICES — what the server sends
//
//  Mirrors models/Invoice.js and api/invoice.js on the server, and
//  prod_web/src/features/invoices/types.ts on the web. One class reads
//  both the list row and the full invoice: the row is the invoice with
//  fewer fields, and every field here tolerates being absent.
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
List<String> _strings(Object? v) =>
    v is List ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList() : const [];

class InvoiceParty {
  const InvoiceParty({
    this.name = '',
    this.address = '',
    this.city = '',
    this.pincode = '',
    this.stateCode = '',
    this.gstin = '',
    this.phone = '',
  });

  final String name, address, city, pincode, stateCode, gstin, phone;

  factory InvoiceParty.fromJson(Map<String, dynamic> j) => InvoiceParty(
        name: _s(j['name']),
        address: _s(j['address']),
        city: _s(j['city']),
        pincode: _s(j['pincode']),
        stateCode: _s(j['stateCode']),
        gstin: _s(j['gstin']),
        phone: _s(j['phone']),
      );

  /// Address, city and pincode as lines a person reads.
  String get place => [
        address,
        [city, pincode].where((s) => s.isNotEmpty).join(' '),
      ].where((s) => s.trim().isNotEmpty).join('\n');
}

class InvoiceTotals {
  const InvoiceTotals({
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.tax = 0,
    this.roundOff = 0,
    this.grand = 0,
  });

  final double taxable, cgst, sgst, igst, tax, roundOff, grand;

  factory InvoiceTotals.fromJson(Map<String, dynamic> j) => InvoiceTotals(
        taxable: _d(j['taxable']),
        cgst: _d(j['cgst']),
        sgst: _d(j['sgst']),
        igst: _d(j['igst']),
        tax: _d(j['tax']),
        roundOff: _d(j['roundOff']),
        grand: _d(j['grand']),
      );
}

class InvoiceLine {
  const InvoiceLine({
    required this.name,
    this.hsn = '',
    this.unit = 'm',
    this.quantity = 0,
    this.boxes = 0,
    this.rate = 0,
    this.taxable = 0,
    this.gstPercent = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.amount = 0,
    this.dcNumbers = const [],
  });

  final String name, hsn, unit;
  final double quantity, rate, taxable, gstPercent, cgst, sgst, igst, amount;
  final int boxes;
  final List<String> dcNumbers;

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        name: _s(j['name']),
        hsn: _s(j['hsn']),
        unit: _s(j['unit']).isEmpty ? 'm' : _s(j['unit']),
        quantity: _d(j['quantity']),
        boxes: _i(j['boxes']),
        rate: _d(j['rate']),
        taxable: _d(j['taxable']),
        gstPercent: _d(j['gstPercent']),
        cgst: _d(j['cgst']),
        sgst: _d(j['sgst']),
        igst: _d(j['igst']),
        amount: _d(j['amount']),
        dcNumbers: _strings(j['dcNumbers']),
      );
}

/// Where an invoice stands with the money owed on it, the way the
/// receivables reckon it (services/outstanding.js; the web's owed()).
enum PaymentState { cancelled, paid, partPaid, due }

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    this.invoiceDate,
    this.orderId = '',
    this.orderNo,
    this.customerId = '',
    this.customerName = '',
    this.customerPo = '',
    this.buyer = const InvoiceParty(),
    this.seller = const InvoiceParty(),
    this.shipTo = '',
    this.supplyType = 'intra',
    this.placeOfSupply = '',
    this.dcNumbers = const [],
    this.lines = const [],
    this.totals = const InvoiceTotals(),
    this.amountInWords = '',
    this.notes = '',
    this.status = 'issued',
    this.cancelReason = '',
    this.einvoiceStatus = 'pending',
    this.irn = '',
    this.ackNo = '',
    this.ackDate,
    this.ewaybillNumber = '',
    this.ewaybillValidUpto,
    this.einvoiceProblems = const [],
    this.dueDate,
    this.paidAmount = 0,
    this.creditedAmount = 0,
    this.debitedAmount = 0,
  });

  final String id, invoiceNumber;
  final DateTime? invoiceDate;
  final String orderId;
  final int? orderNo;
  final String customerId, customerName, customerPo;
  final InvoiceParty buyer, seller;
  final String shipTo;

  /// intra (CGST + SGST), inter (IGST), export or sez.
  final String supplyType;
  final String placeOfSupply;
  final List<String> dcNumbers;
  final List<InvoiceLine> lines;
  final InvoiceTotals totals;
  final String amountInWords, notes;

  /// issued or cancelled.
  final String status;
  final String cancelReason;

  /// pending, registered or cancelled.
  final String einvoiceStatus;
  final String irn, ackNo;
  final DateTime? ackDate;
  final String ewaybillNumber;
  final DateTime? ewaybillValidUpto;

  /// What the e-invoice portal would refuse; empty when it can be registered.
  final List<String> einvoiceProblems;

  final DateTime? dueDate;
  final double paidAmount, creditedAmount, debitedAmount;

  bool get isCancelled => status == 'cancelled';
  bool get irnRegistered => einvoiceStatus == 'registered';

  /// What is still owed on it; nothing on a cancelled invoice.
  double get owed {
    if (isCancelled) return 0;
    final left = totals.grand + debitedAmount - paidAmount - creditedAmount;
    return left > 0 ? left : 0;
  }

  PaymentState get paymentState {
    if (isCancelled) return PaymentState.cancelled;
    if (owed <= 0.005) return PaymentState.paid;
    if (paidAmount + creditedAmount > 0) return PaymentState.partPaid;
    return PaymentState.due;
  }

  /// Whole days past due; 0 or less while it is not yet due. Day by
  /// day, so an invoice due today reads "due today" all day.
  int daysOverdue([DateTime? now]) {
    final due = dueDate ?? invoiceDate;
    if (due == null) return 0;
    final today = now ?? DateTime.now();
    final a = DateTime(due.year, due.month, due.day);
    final b = DateTime(today.year, today.month, today.day);
    return b.difference(a).inDays;
  }

  /// "CGST + SGST", "IGST", "Export" or "SEZ".
  String get taxLabel => switch (supplyType) {
        'intra' => 'CGST + SGST',
        'export' => 'Export',
        'sez' => 'SEZ',
        _ => 'IGST',
      };

  factory Invoice.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'];
    final einv = _m(j['einvoice']);
    final eway = _m(j['ewaybill']);
    final buyer = InvoiceParty.fromJson(_m(j['buyer']));
    return Invoice(
      id: _s(j['_id'] ?? j['id']),
      invoiceNumber: _s(j['invoiceNumber']),
      invoiceDate: _date(j['invoiceDate']),
      orderId: _s(j['order'] is Map ? (j['order'] as Map)['_id'] : j['order']),
      orderNo: j['orderNo'] == null ? null : _i(j['orderNo']),
      customerId: customer is Map ? _s(customer['_id']) : _s(customer),
      customerName: customer is Map ? _s(customer['name']) : buyer.name,
      customerPo: _s(j['customerPo']),
      buyer: buyer,
      seller: InvoiceParty.fromJson(_m(j['seller'])),
      shipTo: _s(j['shipTo']),
      supplyType: _s(j['supplyType']).isEmpty ? 'intra' : _s(j['supplyType']),
      placeOfSupply: _s(j['placeOfSupply']),
      dcNumbers: _maps(j['dcs']).map((d) => _s(d['dcNumber'])).where((s) => s.isNotEmpty).toList(),
      lines: _maps(j['lines']).map(InvoiceLine.fromJson).toList(),
      totals: InvoiceTotals.fromJson(_m(j['totals'])),
      amountInWords: _s(j['amountInWords']),
      notes: _s(j['notes']),
      status: _s(j['status']).isEmpty ? 'issued' : _s(j['status']),
      cancelReason: _s(_m(j['cancel'])['reason']),
      einvoiceStatus: _s(einv['status']).isEmpty ? 'pending' : _s(einv['status']),
      irn: _s(einv['irn']),
      ackNo: _s(einv['ackNo']),
      ackDate: _date(einv['ackDate']),
      ewaybillNumber: eway['status'] == 'generated' ? _s(eway['number']) : '',
      ewaybillValidUpto: _date(eway['validUpto']),
      einvoiceProblems: _strings(j['einvoiceProblems']),
      dueDate: _date(j['dueDate']),
      paidAmount: _d(j['paidAmount']),
      creditedAmount: _d(j['creditedAmount']),
      debitedAmount: _d(j['debitedAmount']),
    );
  }
}

class InvoicePage {
  const InvoicePage({required this.invoices, this.total = 0, this.page = 1, this.pages = 1});

  final List<Invoice> invoices;
  final int total, page, pages;

  factory InvoicePage.fromJson(Map<String, dynamic> j) => InvoicePage(
        invoices: _maps(j['invoices']).map(Invoice.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pages: _i(j['pages']) == 0 ? 1 : _i(j['pages']),
      );
}

// ── Raising one ─────────────────────────────────────────────────

/// A challan on the order, and whether it can go on a new invoice.
class InvoiceDcOption {
  const InvoiceDcOption({
    required this.id,
    required this.dcNumber,
    this.status = '',
    this.dispatchDate,
    this.totalQuantity = 0,
    this.invoicedOn,
    this.eligible = false,
    this.items = const [],
  });

  final String id, dcNumber, status;
  final DateTime? dispatchDate;
  final double totalQuantity;

  /// The invoice this challan is already on, if any.
  final String? invoicedOn;
  final bool eligible;
  final List<InvoiceDcItem> items;

  factory InvoiceDcOption.fromJson(Map<String, dynamic> j) => InvoiceDcOption(
        id: _s(j['_id']),
        dcNumber: _s(j['dcNumber']),
        status: _s(j['status']),
        dispatchDate: _date(j['dispatchDate']),
        totalQuantity: _d(j['totalQuantity']),
        invoicedOn: j['invoicedOn'] == null || '${j['invoicedOn']}'.isEmpty ? null : _s(j['invoicedOn']),
        eligible: j['eligible'] == true,
        items: _maps(j['items']).map(InvoiceDcItem.fromJson).toList(),
      );
}

class InvoiceDcItem {
  const InvoiceDcItem({this.elastic = '', this.elasticName = '', this.quantity = 0, this.unit = ''});

  final String elastic, elasticName, unit;
  final double quantity;

  factory InvoiceDcItem.fromJson(Map<String, dynamic> j) => InvoiceDcItem(
        elastic: _s(j['elastic'] is Map ? (j['elastic'] as Map)['_id'] : j['elastic']),
        elasticName: _s(j['elasticName']),
        quantity: _d(j['quantity']),
        unit: _s(j['unit']),
      );
}

/// The line the server proposes for one elastic: its rate from the
/// order, HSN and GST % from Settings or the elastic itself.
class InvoiceDraftLine {
  InvoiceDraftLine({
    required this.elastic,
    required this.name,
    this.unit = 'm',
    this.quantity = 0,
    this.rate = 0,
    this.hsn = '',
    this.gstPercent = 0,
    List<String>? dcNumbers,
    this.rateSource = 'none',
  }) : dcNumbers = dcNumbers ?? [];

  final String elastic, name, unit;
  double quantity, rate, gstPercent;
  String hsn;
  final List<String> dcNumbers;

  /// order, challan, entered or none.
  String rateSource;

  factory InvoiceDraftLine.fromJson(Map<String, dynamic> j) => InvoiceDraftLine(
        elastic: _s(j['elastic'] is Map ? (j['elastic'] as Map)['_id'] : j['elastic']),
        name: _s(j['name']),
        unit: _s(j['unit']).isEmpty ? 'm' : _s(j['unit']),
        quantity: _d(j['quantity']),
        rate: _d(j['rate']),
        hsn: _s(j['hsn']),
        gstPercent: _d(j['gstPercent']),
        dcNumbers: _strings(j['dcNumbers']),
        rateSource: _s(j['rateSource']).isEmpty ? 'none' : _s(j['rateSource']),
      );
}

/// Everything the raise form needs for one order (GET /invoice/order-info).
class InvoiceOrderInfo {
  const InvoiceOrderInfo({
    required this.orderId,
    this.orderNo,
    this.po = '',
    this.customerId = '',
    this.buyer = const InvoiceParty(),
    this.shipTo = '',
    this.supplyType = 'intra',
    this.placeOfSupply = '',
    this.dcs = const [],
    this.lines = const [],
    this.defaultHsn = '',
    this.defaultGstPercent = 5,
    this.problems = const [],
    this.exportSuggested = '',
  });

  final String orderId;
  final int? orderNo;
  final String po, customerId;
  final InvoiceParty buyer;
  final String shipTo, supplyType, placeOfSupply;
  final List<InvoiceDcOption> dcs;
  final List<InvoiceDraftLine> lines;
  final String defaultHsn;
  final double defaultGstPercent;

  /// What the e-invoice portal would refuse once it is raised.
  final List<String> problems;

  /// The export / SEZ kind the customer's file suggests ("" for a
  /// domestic sale). Those invoices need an LUT, a currency and a port,
  /// and are raised on the web.
  final String exportSuggested;

  factory InvoiceOrderInfo.fromJson(Map<String, dynamic> j) {
    final order = _m(j['order']);
    final defaults = _m(j['defaults']);
    return InvoiceOrderInfo(
      orderId: _s(order['_id']),
      orderNo: order['orderNo'] == null ? null : _i(order['orderNo']),
      po: _s(order['po']),
      customerId: _s(order['customer']),
      buyer: InvoiceParty.fromJson(_m(j['buyer'])),
      shipTo: _s(j['shipTo']),
      supplyType: _s(j['supplyType']).isEmpty ? 'intra' : _s(j['supplyType']),
      placeOfSupply: _s(j['placeOfSupply']),
      dcs: _maps(j['dcs']).map(InvoiceDcOption.fromJson).toList(),
      lines: _maps(j['lines']).map(InvoiceDraftLine.fromJson).toList(),
      defaultHsn: _s(defaults['hsn']),
      defaultGstPercent: defaults['gstPercent'] == null ? 5 : _d(defaults['gstPercent']),
      problems: _strings(j['problems']),
      exportSuggested: _s(_m(j['export'])['suggested']),
    );
  }
}

/// An order's invoices and the challans still to be invoiced
/// (GET /invoice/by-order).
class OrderInvoices {
  const OrderInvoices({
    this.invoices = const [],
    this.invoiced = 0,
    this.uninvoicedDcs = const [],
  });

  final List<Invoice> invoices;

  /// The total of the issued (not cancelled) invoices.
  final double invoiced;
  final List<({String id, String dcNumber, double quantity})> uninvoicedDcs;

  factory OrderInvoices.fromJson(Map<String, dynamic> j) => OrderInvoices(
        invoices: _maps(j['invoices']).map(Invoice.fromJson).toList(),
        invoiced: _d(_m(j['totals'])['invoiced']),
        uninvoicedDcs: _maps(j['uninvoicedDcs'])
            .map((d) => (id: _s(d['_id']), dcNumber: _s(d['dcNumber']), quantity: _d(d['totalQuantity'])))
            .toList(),
      );
}

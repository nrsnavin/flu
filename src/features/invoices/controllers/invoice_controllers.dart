import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/request_id.dart';
import '../gst.dart';
import '../models/invoice_models.dart';
import '../services/invoice_api.dart';

// ══════════════════════════════════════════════════════════════
//  INVOICES ON A PHONE
//
//  Web-only until now. What it is worth on a phone: raising the
//  invoice as the goods leave, from the order, without waiting for
//  somebody at a desk; reading what a customer owes on one while they
//  are on the line; sending them the PDF; and cancelling one raised
//  in error. Registering the IRN and the e-way bill stay on the web,
//  where the GSP set-up and the portal live; the phone shows where
//  each stands.
// ══════════════════════════════════════════════════════════════

class InvoiceListController extends GetxController {
  final invoices = <Invoice>[].obs;
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final search = ''.obs;

  /// The filter chips: null (all), issued, cancelled, or irn (issued
  /// and still waiting for an IRN).
  final filter = RxnString();
  final page = 1.obs;
  final pages = 1.obs;
  final total = 0.obs;

  Timer? _debounce;

  static const filters = <String?, String>{
    null: 'All',
    'issued': 'Issued',
    'irn': 'IRN pending',
    'cancelled': 'Cancelled',
  };

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final f = filter.value;
      final res = await InvoiceApi.list(
        page: page.value,
        search: search.value,
        status: f == 'irn' ? 'issued' : f,
        einvoice: f == 'irn' ? 'pending' : null,
      );
      invoices.value = res.invoices;
      total.value = res.total;
      pages.value = res.pages;
    } catch (e) {
      errorMsg.value = invoiceMessage(e, 'Could not load invoices');
    } finally {
      isLoading.value = false;
    }
  }

  /// Typing should not fire a request per keystroke.
  void setSearch(String s) {
    search.value = s;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      page.value = 1;
      fetch();
    });
  }

  void setFilter(String? f) {
    if (f == filter.value) return;
    filter.value = f;
    page.value = 1;
    fetch();
  }

  Future<void> goToPage(int p) async {
    if (p < 1 || p > pages.value || p == page.value) return;
    page.value = p;
    await fetch();
  }

  /// Keep a row in step after its detail changed it.
  void replace(Invoice inv) {
    final i = invoices.indexWhere((x) => x.id == inv.id);
    if (i >= 0) invoices[i] = inv;
  }
}

class InvoiceDetailController extends GetxController {
  InvoiceDetailController(this.invoiceId);

  final String invoiceId;

  final invoice = Rxn<Invoice>();
  final isLoading = false.obs;
  final isCancelling = false.obs;
  final isFetchingPdf = false.obs;
  final errorMsg = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      invoice.value = await InvoiceApi.detail(invoiceId);
    } catch (e) {
      errorMsg.value = invoiceMessage(e, 'Could not load this invoice');
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns what to tell the person: the portal note when there is
  /// one, or the error.
  Future<({bool ok, String message})> cancel(String reason) async {
    if (isCancelling.value) return (ok: false, message: '');
    isCancelling.value = true;
    try {
      final r = await InvoiceApi.cancel(invoiceId, reason);
      invoice.value = r.invoice;
      if (Get.isRegistered<InvoiceListController>()) {
        Get.find<InvoiceListController>().replace(r.invoice);
      }
      return (
        ok: true,
        message: r.portalNote.isEmpty ? 'Invoice cancelled' : 'Invoice cancelled. ${r.portalNote}',
      );
    } catch (e) {
      return (ok: false, message: invoiceMessage(e, 'Could not cancel the invoice'));
    } finally {
      isCancelling.value = false;
    }
  }

  Future<({Uint8List? bytes, String? error})> pdf() async {
    if (isFetchingPdf.value) return (bytes: null, error: null);
    isFetchingPdf.value = true;
    try {
      return (bytes: await InvoiceApi.pdf(invoiceId), error: null);
    } catch (e) {
      return (bytes: null, error: invoiceMessage(e, 'Could not get the invoice PDF'));
    } finally {
      isFetchingPdf.value = false;
    }
  }
}

/// Raise a tax invoice for an order, against its despatched challans.
///
/// The challans that have left and are not on an invoice come ticked.
/// The lines are their items merged per product, priced from the
/// order; a missing rate is typed in here, and the HSN and GST % can be
/// corrected. The totals are previewed as the server will compute them.
class RaiseInvoiceController extends GetxController {
  RaiseInvoiceController(this.orderId);

  final String orderId;

  final info = Rxn<InvoiceOrderInfo>();
  final isLoading = false.obs;
  final isRaising = false.obs;
  final errorMsg = RxnString();

  final selected = <String>{}.obs;
  final overrides = <String, LineOverride>{}.obs;
  final invoiceDate = DateTime.now().obs;
  final notesCtrl = TextEditingController();
  final shipToCtrl = TextEditingController();

  // One id per submission, reused when the same submission is retried
  // (a timeout, a second tap) and replaced once anything in it changes.
  String? _requestId;
  String? _requestSig;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    notesCtrl.dispose();
    shipToCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final i = await InvoiceApi.orderInfo(orderId);
      info.value = i;
      selected
        ..clear()
        ..addAll(i.dcs.where((d) => d.eligible).map((d) => d.id));
      shipToCtrl.text = i.shipTo;
    } catch (e) {
      errorMsg.value = invoiceMessage(e, 'Could not load the order');
    } finally {
      isLoading.value = false;
    }
  }

  /// An export or SEZ customer: those invoices take an LUT, a currency
  /// and a port, and are raised on the web.
  bool get needsWeb => (info.value?.exportSuggested ?? '').isNotEmpty;

  List<InvoiceDraftLine> get lines {
    final i = info.value;
    if (i == null) return const [];
    return draftLines(i.dcs, selected, i.lines, overrides,
        defaultHsn: i.defaultHsn, defaultGstPercent: i.defaultGstPercent);
  }

  ({List<PricedLine> lines, InvoiceTotals totals}) get priced =>
      priceLines(lines, info.value?.supplyType ?? 'intra');

  List<InvoiceDraftLine> get unpriced => lines.where((l) => !(l.rate > 0)).toList();

  bool get canRaise =>
      info.value != null &&
      !needsWeb &&
      selected.isNotEmpty &&
      lines.isNotEmpty &&
      unpriced.isEmpty &&
      !isRaising.value;

  void toggle(InvoiceDcOption dc) {
    if (!dc.eligible) return;
    if (selected.contains(dc.id)) {
      selected.remove(dc.id);
    } else {
      selected.add(dc.id);
    }
  }

  void setOverride(String elastic, {double? rate, String? hsn, double? gstPercent}) {
    final o = overrides[elastic] ?? LineOverride();
    if (rate != null) o.rate = rate;
    if (hsn != null) o.hsn = hsn;
    if (gstPercent != null) o.gstPercent = gstPercent;
    overrides[elastic] = o;
    overrides.refresh();
  }

  String get _signature {
    final o = overrides.entries
        .map((e) => '${e.key}:${e.value.rate}:${e.value.hsn}:${e.value.gstPercent}')
        .toList()
      ..sort();
    final dcs = selected.toList()..sort();
    return [
      dcs.join(','),
      o.join(','),
      invoiceDate.value.toIso8601String().substring(0, 10),
      notesCtrl.text.trim(),
      shipToCtrl.text.trim(),
    ].join('|');
  }

  /// Raises it. Throws what the server said, for the screen to read —
  /// a credit hold among them, which an admin can release with a reason.
  Future<Invoice> raise({String? creditOverride}) async {
    final sig = _signature;
    if (_requestId == null || sig != _requestSig) {
      _requestId = newRequestId();
      _requestSig = sig;
    }
    isRaising.value = true;
    try {
      final inv = await InvoiceApi.create(
        orderId: orderId,
        dcIds: selected.toList(),
        invoiceDate: invoiceDate.value,
        requestId: _requestId!,
        overrides: Map.of(overrides),
        notes: notesCtrl.text,
        shipTo: shipToCtrl.text,
        creditOverride: creditOverride,
      );
      _requestId = null; // the next raise is a new invoice
      return inv;
    } finally {
      isRaising.value = false;
    }
  }
}

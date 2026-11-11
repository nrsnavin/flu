import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/capture.dart';
import '../../../core/request_id.dart';
import '../models/claim_models.dart';
import '../services/claims_api.dart';

// ══════════════════════════════════════════════════════════════
//  EXPENSE CLAIMS ON A PHONE
//
//  The phone is where this belongs: the receipt is in somebody's hand
//  at the fuel pump or the toll booth. Photograph it, the server reads
//  it into the claim, the person checks the figures and sends it; it
//  waits for Accounts to approve and pay it back, and the person can
//  see where each one stands and withdraw one still waiting.
// ══════════════════════════════════════════════════════════════

class ClaimsController extends GetxController {
  final claims = <Claim>[].obs;
  final waiting = 0.0.obs;
  final owed = 0.0.obs;
  final isLoading = false.obs;
  final errorMsg = RxnString();
  final withdrawing = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final m = await ClaimsApi.mine();
      claims.value = m.claims;
      waiting.value = m.waiting;
      owed.value = m.owed;
    } catch (e) {
      errorMsg.value = claimMessage(e, 'Could not load your claims');
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns what to tell the person.
  Future<({bool ok, String message})> withdraw(Claim c) async {
    if (withdrawing.value != null) return (ok: false, message: '');
    withdrawing.value = c.id;
    try {
      await ClaimsApi.withdraw(c.id);
      await fetch();
      return (ok: true, message: 'Withdrawn');
    } catch (e) {
      return (ok: false, message: claimMessage(e, 'Could not withdraw the claim'));
    } finally {
      withdrawing.value = null;
    }
  }
}

class NewClaimController extends GetxController {
  final categories = <ClaimCategory>[].obs;
  final category = RxnString();
  final descriptionCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final date = DateTime.now().obs;
  String refNo = '';

  final photo = Rxn<CapturedFile>();
  final scan = Rxn<ClaimScan>();
  final reading = false.obs;
  final readNote = ''.obs;
  final sending = false.obs;
  final loadError = RxnString();

  /// Bumped on every keystroke so the Send button follows the fields.
  final edits = 0.obs;

  String? _requestId;
  String? _requestSig;

  @override
  void onInit() {
    super.onInit();
    descriptionCtrl.addListener(() => edits.value++);
    amountCtrl.addListener(() => edits.value++);
    loadCategories();
  }

  @override
  void onClose() {
    descriptionCtrl.dispose();
    amountCtrl.dispose();
    super.onClose();
  }

  Future<void> loadCategories() async {
    loadError.value = null;
    try {
      categories.value = await ClaimsApi.categories();
    } catch (e) {
      loadError.value = claimMessage(e, 'Could not load the expense heads');
    }
  }

  double get amount => double.tryParse(amountCtrl.text.trim()) ?? 0;

  bool get ready =>
      category.value != null &&
      descriptionCtrl.text.trim().length >= 3 &&
      amount > 0 &&
      !sending.value &&
      !reading.value;

  /// The receipt, photographed or picked: read into the form at once.
  /// The photo goes with the claim even when reading it fails.
  Future<void> usePhoto(CapturedFile file) async {
    photo.value = file;
    scan.value = null;
    readNote.value = '';
    reading.value = true;
    try {
      final r = await ClaimsApi.scan(file.bytes, file.name);
      if (!r.read) {
        readNote.value = r.problem == 'not_a_bill'
            ? 'That does not look like a receipt — fill the claim in below.'
            : 'The receipt could not be read — fill the claim in below.';
        return;
      }
      scan.value = r;
      if (r.amount != null) amountCtrl.text = _plain(r.amount!);
      final d = DateTime.tryParse(r.date);
      if (d != null) date.value = d;
      if (r.description.isNotEmpty) descriptionCtrl.text = r.description;
      if (r.categoryId != null && categories.any((c) => c.id == r.categoryId)) {
        category.value = r.categoryId;
      }
      refNo = r.refNo;
      readNote.value = 'Filled in from the receipt — check each figure before sending.';
    } catch (e) {
      readNote.value = claimMessage(e, 'The receipt could not be read — fill the claim in below.');
    } finally {
      reading.value = false;
    }
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  /// Sends it, then attaches the photo. Returns the claim, or throws
  /// what the server said. A photo that fails to attach does not undo
  /// the claim: [photoError] says so.
  String? photoError;

  Future<Claim> send() async {
    final sig = [
      category.value,
      descriptionCtrl.text.trim(),
      amount,
      date.value.toIso8601String().substring(0, 10),
      refNo,
    ].join('|');
    if (_requestId == null || sig != _requestSig) {
      _requestId = newRequestId();
      _requestSig = sig;
    }
    sending.value = true;
    photoError = null;
    try {
      final claim = await ClaimsApi.create(
        category: category.value!,
        description: descriptionCtrl.text,
        amount: amount,
        date: date.value,
        requestId: _requestId!,
        refNo: refNo,
        aiSuggestion: scan.value?.aiSuggestion,
      );
      _requestId = null;
      final p = photo.value;
      if (p != null) {
        try {
          await ClaimsApi.attachPhoto(claim.id, p.bytes, p.name);
        } catch (e) {
          photoError = claimMessage(e, 'The photo did not attach');
        }
      }
      return claim;
    } finally {
      sending.value = false;
    }
  }
}

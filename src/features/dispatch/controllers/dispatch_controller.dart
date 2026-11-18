import 'package:dio/dio.dart' show DioException;
import 'package:get/get.dart';

import '../models/dispatch_models.dart';
import '../services/dispatch_api.dart';

// ══════════════════════════════════════════════════════════════
//  THE DISPATCH QUEUE ON A PHONE
//
//  The people who load the lorry are on the floor, not at a desk. They
//  see what has to leave and in what order, and mark each one gone as
//  it goes; marketing answers "when does the customer need it?" from
//  wherever they are.
//
//  Every action reloads the queue rather than patching one row: the
//  order is the server's, and somebody else may have moved it.
// ══════════════════════════════════════════════════════════════

typedef DispatchOutcome = ({bool ok, String message});

class DispatchController extends GetxController {
  /// false = the open queue, true = what has been dispatched.
  final showDispatched = false.obs;

  final items = <DispatchItem>[].obs;
  final awaitingCount = 0.obs;
  final queuedCount = 0.obs;
  final lateCount = 0.obs;

  final isLoading = false.obs;
  final errorMsg = RxnString();

  /// The item an action is running on; one at a time.
  final busyId = RxnString();

  /// Bumped on every load, so an answer for a view the person has
  /// already left is dropped rather than shown under the wrong tab.
  int _load = 0;

  List<DispatchItem> get awaiting => items.where((i) => i.awaiting).toList();
  List<DispatchItem> get queued => items.where((i) => i.queued).toList();

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    final mine = ++_load;
    final dispatched = showDispatched.value;
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final q = await DispatchApi.queue(dispatched: dispatched);
      if (mine != _load) return;
      items.value = q.items;
      if (!dispatched) {
        awaitingCount.value = q.awaiting;
        queuedCount.value = q.queued;
        lateCount.value = q.late;
      }
    } catch (e) {
      if (mine != _load) return;
      errorMsg.value = dispatchMessage(e, 'Could not load the dispatch queue');
    } finally {
      if (mine == _load) isLoading.value = false;
    }
  }

  void show({required bool dispatched}) {
    if (showDispatched.value == dispatched) return;
    showDispatched.value = dispatched;
    items.clear();
    fetch();
  }

  /// Put the server's answer for one item into the list on screen.
  void _apply(DispatchItem done) {
    final i = items.indexWhere((x) => x.id == done.id);
    if (i < 0) return;
    if (showDispatched.value || done.awaiting || done.queued) {
      items[i] = done;
    } else {
      items.removeAt(i); // gone, or taken off the queue
    }
    if (!showDispatched.value) {
      awaitingCount.value = items.where((x) => x.awaiting).length;
      queuedCount.value = items.where((x) => x.queued).length;
      lateCount.value = items.where((x) => x.late).length;
    }
  }

  Future<DispatchOutcome> _act(
    DispatchItem item,
    Future<DispatchItem> Function() call,
    String Function(DispatchItem done) said,
    String failed,
  ) async {
    if (busyId.value != null) return (ok: false, message: '');
    busyId.value = item.id;
    try {
      final done = await call();
      // Shown at once, so the list is true even if the reload fails;
      // the reload then puts it in the server's order.
      _apply(done);
      await fetch();
      return (ok: true, message: said(done));
    } catch (e) {
      // The server refused: somebody else got there first, or it is no
      // longer in the queue — show what is true now. (No reload when the
      // server was never reached: that would only fail a second time.)
      if (e is DioException && e.response != null) await fetch();
      return (ok: false, message: dispatchMessage(e, failed));
    } finally {
      busyId.value = null;
    }
  }

  Future<DispatchOutcome> setUrgency(DispatchItem item, UrgencyOption o) => _act(
        item,
        () => DispatchApi.setUrgency(item.id, o.value),
        (done) => '${item.ref}: ${done.urgencyLabel ?? o.label}',
        'Could not set the urgency',
      );

  Future<DispatchOutcome> markDispatched(DispatchItem item, String note) => _act(
        item,
        () => DispatchApi.markDispatched(item.id, note: note),
        (_) => '${item.ref} dispatched',
        'Could not mark it dispatched',
      );

  Future<DispatchOutcome> remove(DispatchItem item, String reason) => _act(
        item,
        () => DispatchApi.cancel(item.id, reason),
        (_) => '${item.ref} removed from the queue',
        'Could not remove it',
      );
}

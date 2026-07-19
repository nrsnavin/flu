import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

/// GetX controller behind the notification settings page.
///
/// Wraps three backend routes:
///   GET  /api/v2/notify/settings   — load current state
///   PUT  /api/v2/notify/settings   — save recipients
///   POST /api/v2/notify/run-digest          — fire morning digest now
///   POST /api/v2/notify/run-evening-report  — fire evening report now
///
/// Single source of truth — the page just observes the rx fields and
/// fires intent methods.
class NotifySettingsController extends GetxController {
  static NotifySettingsController get instance =>
      Get.isRegistered<NotifySettingsController>()
          ? Get.find<NotifySettingsController>()
          : Get.put(NotifySettingsController());

  // Re-uses the global JWT-cookie interceptor.
  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/notify',
  );

  // ── Reactive state ─────────────────────────────────────────────
  final loading        = false.obs;   // initial fetch in flight
  final saving         = false.obs;   // PUT in flight
  final sendingDigest  = false.obs;   // morning trigger in flight
  final sendingEvening = false.obs;   // evening trigger in flight
  final enabled        = true.obs;
  final recipients     = <String>[].obs;
  final providerConfigured = false.obs;
  final lastError      = ''.obs;

  // Per-event config, mirroring the backend shape:
  //   { eventName: { enabled, recipients: [...], tier, throttleSeconds } }
  // When events[ev].recipients is empty, the backend falls through to
  // the global recipients list — same logic mirrored client-side in
  // isSubscribed() so the per-recipient sheet reflects reality.
  final events = <String, Map<String, dynamic>>{}.obs;

  // ── Lifecycle ──────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    refreshSettings();
  }

  Future<void> refreshSettings() async {
    loading.value = true;
    lastError.value = '';
    try {
      final res = await _dio.get('/settings');
      final body = (res.data is Map) ? res.data as Map : const {};
      final s = (body['settings'] is Map) ? body['settings'] as Map : const {};
      enabled.value = s['enabled'] != false;
      recipients.assignAll(
        ((s['recipients'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
      final rawEvents = s['events'];
      events.clear();
      if (rawEvents is Map) {
        rawEvents.forEach((k, v) {
          if (v is Map) {
            events[k.toString()] = Map<String, dynamic>.from(v);
          }
        });
      }
      final provider = (body['provider'] is Map) ? body['provider'] as Map : const {};
      providerConfigured.value = provider['configured'] == true;
    } on DioException catch (e) {
      lastError.value = _readableDioError(e);
    } catch (e) {
      lastError.value = 'Failed to load settings: $e';
    } finally {
      loading.value = false;
    }
  }

  // ── Recipient editing ──────────────────────────────────────────
  // The backend's PUT validator rejects anything that doesn't match
  // /^\+\d{8,15}$/, so we surface the same rule client-side for a
  // faster failure mode than a round-trip.
  bool isValidE164(String s) => RegExp(r'^\+\d{8,15}$').hasMatch(s.trim());

  Future<bool> addRecipient(String raw) async {
    final number = raw.trim();
    if (!isValidE164(number)) {
      lastError.value = 'Use the international format, e.g. +919876543210.';
      return false;
    }
    if (recipients.contains(number)) {
      lastError.value = '$number is already on the list.';
      return false;
    }
    return _saveRecipients([...recipients, number]);
  }

  Future<bool> removeRecipient(String number) {
    return _saveRecipients(recipients.where((r) => r != number).toList());
  }

  Future<bool> _saveRecipients(List<String> next) async {
    saving.value = true;
    lastError.value = '';
    try {
      final res = await _dio.put('/settings', data: {'recipients': next});
      final body = (res.data is Map) ? res.data as Map : const {};
      final s = (body['settings'] is Map) ? body['settings'] as Map : const {};
      recipients.assignAll(
        ((s['recipients'] as List?) ?? next).map((e) => e.toString()).toList(),
      );
      return true;
    } on DioException catch (e) {
      lastError.value = _readableDioError(e);
      return false;
    } catch (e) {
      lastError.value = 'Failed to save: $e';
      return false;
    } finally {
      saving.value = false;
    }
  }

  // ── Per-recipient event subscriptions ──────────────────────────
  // The backend's per-event recipients[] is the source of truth:
  //   - non-empty list → only those recipients get this event
  //   - empty list     → falls through to global recipients
  // The UI exposes a per-recipient subscription toggle that resolves
  // both modes into a single boolean.

  /// All known event names with stable display ordering.
  List<String> get knownEvents {
    final names = events.keys.toList()..sort();
    return names;
  }

  /// True iff [number] currently receives [eventName].
  bool isSubscribed(String number, String eventName) {
    final ev = events[eventName];
    if (ev == null) return false;
    if (ev['enabled'] == false) return false;
    final rs = (ev['recipients'] as List?) ?? const [];
    if (rs.isNotEmpty) {
      return rs.map((e) => e.toString()).contains(number);
    }
    // Falls through to global.
    return recipients.contains(number);
  }

  /// True iff this event has an explicit recipient override (vs
  /// falling through to global). Surfaced in the sheet so the admin
  /// knows when a "no" comes from an explicit exclusion vs a global
  /// no-op.
  bool eventHasExplicitOverride(String eventName) {
    final rs = (events[eventName]?['recipients'] as List?) ?? const [];
    return rs.isNotEmpty;
  }

  /// Toggle the subscription for one (recipient, event) pair.
  /// Mutates the event's recipients[] explicitly: starting from the
  /// global list when the override is empty, so flipping one recipient
  /// off doesn't accidentally unsubscribe everyone else.
  ///
  /// Edge case: if the new explicit list ends up empty, the event is
  /// flipped to disabled (recipients:[] would otherwise fall back to
  /// global — i.e. silently re-subscribe everyone).
  Future<bool> setEventSubscription(
    String number, String eventName, bool wantSubscribed,
  ) async {
    final ev = events[eventName];
    if (ev == null) return false;

    final currentList = ((ev['recipients'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    // Materialize the implicit "everyone in global" set when the
    // override is empty so we don't accidentally widen the audience.
    final base = currentList.isEmpty ? recipients.toList() : currentList;

    final nextSet = base.toSet();
    if (wantSubscribed) {
      nextSet.add(number);
    } else {
      nextSet.remove(number);
    }
    final next = nextSet.toList()..sort();

    final patch = <String, dynamic>{};
    if (next.isEmpty) {
      // Nobody subscribed → disable the event entirely. Empty
      // recipients[] would otherwise fall back to global, which
      // would silently re-subscribe everyone.
      patch['enabled']    = false;
      patch['recipients'] = <String>[];
    } else {
      patch['enabled']    = true;
      patch['recipients'] = next;
    }

    saving.value = true;
    lastError.value = '';
    try {
      final res = await _dio.put('/settings', data: {
        'events': { eventName: patch },
      });
      final body = (res.data is Map) ? res.data as Map : const {};
      final s = (body['settings'] is Map) ? body['settings'] as Map : const {};
      final rawEvents = s['events'];
      if (rawEvents is Map) {
        events.clear();
        rawEvents.forEach((k, v) {
          if (v is Map) {
            events[k.toString()] = Map<String, dynamic>.from(v);
          }
        });
      }
      return true;
    } on DioException catch (e) {
      lastError.value = _readableDioError(e);
      return false;
    } catch (e) {
      lastError.value = 'Failed to save: $e';
      return false;
    } finally {
      saving.value = false;
    }
  }

  // ── Manual triggers ────────────────────────────────────────────
  // Each returns { ok, message } so the page can surface a snackbar
  // without coupling to the controller.

  Future<TriggerResult> sendMorningDigestNow() =>
      _trigger(sendingDigest, '/run-digest', 'Morning digest');

  Future<TriggerResult> sendEveningReportNow() =>
      _trigger(sendingEvening, '/run-evening-report', 'Evening report');

  Future<TriggerResult> _trigger(
    RxBool flag, String path, String label,
  ) async {
    flag.value = true;
    lastError.value = '';
    try {
      final res = await _dio.post(path);
      final body = (res.data is Map) ? res.data as Map : const {};
      final ok = body['success'] == true;
      if (!ok) {
        return TriggerResult(false, body['message']?.toString()
            ?? '$label send failed.');
      }
      final notify = (body['notifyResult'] is Map)
          ? body['notifyResult'] as Map
          : const {};
      final sent = notify['sent'];
      final preview = (body['preview'] as String?)?.trim();
      if (sent is int && sent > 0) {
        return TriggerResult(true, '$label sent to $sent recipient(s).');
      }
      if (notify['skipped'] != null) {
        return TriggerResult(false,
            '$label skipped: ${notify['skipped']}. Check settings.');
      }
      if (preview != null && preview.isNotEmpty) {
        // Provider not configured but the pipeline ran end-to-end.
        return TriggerResult(true,
            '$label generated in dry-run mode (WhatsApp creds missing).');
      }
      return TriggerResult(true, '$label triggered.');
    } on DioException catch (e) {
      final msg = _readableDioError(e);
      lastError.value = msg;
      return TriggerResult(false, msg);
    } catch (e) {
      lastError.value = '$label trigger failed: $e';
      return TriggerResult(false, '$label trigger failed: $e');
    } finally {
      flag.value = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _readableDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'Network error';
  }
}

class TriggerResult {
  final bool ok;
  final String message;
  TriggerResult(this.ok, this.message);
}

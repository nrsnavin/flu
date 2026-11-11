import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import 'floor_models.dart';

// ══════════════════════════════════════════════════════════════
//  THE FLOOR'S OWN CLIENT
//
//  Floor entry is opened with a shift PIN, not a login, so it does not
//  use the app's client: that one sends the signed-in session's cookie,
//  and a floor phone is usually signed in as nobody. Every call but
//  /open carries the shift's token in X-Floor-Token instead, and a 401
//  here means "enter the PIN again" (the shift ended, or the office
//  changed its PIN) — handled on the screen, never a sign-out.
//
//  The token is kept on the phone for the shift, so closing the app or
//  a call coming in does not cost the supervisor the PIN. The shift's
//  state is always fetched fresh.
// ══════════════════════════════════════════════════════════════

/// A refusal from the floor routes, in the server's words.
class FloorError implements Exception {
  final int? status;
  final String message;
  final String? code;
  final Map<String, dynamic> details;
  const FloorError(this.message, {this.status, this.code, this.details = const {}});

  /// The token is no good any more: ask for the PIN again.
  bool get pinAgain => status == 401;

  @override
  String toString() => message;
}

class FloorApi {
  FloorApi._();
  static final FloorApi instance = FloorApi._();

  static const _kToken = 'floor.token';
  static const _kSession = 'floor.session';

  String? _token;
  FloorSession? _session;

  late final Dio _dio = () {
    final d = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));
    d.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (_token != null && _token!.isNotEmpty) o.headers['X-Floor-Token'] = _token;
      h.next(o);
    }));
    return d;
  }();

  FloorSession? get session => _session;

  /// The session kept from before, if any (the screen then checks it
  /// still stands by reading the shift).
  Future<FloorSession?> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final token = p.getString(_kToken);
      final raw = p.getString(_kSession);
      if (token == null || token.isEmpty || raw == null) return null;
      final s = FloorSession.from(jsonDecode(raw));
      if (!s.isValid) return null;
      _token = token;
      _session = s;
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> forget() async {
    _token = null;
    _session = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kToken);
      await p.remove(_kSession);
    } catch (_) {/* nothing kept */}
  }

  Future<T> _call<T>(Future<Response<dynamic>> Function() send, T Function(Map<String, dynamic>) read) async {
    try {
      final res = await send();
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      return read(body);
    } on DioException catch (e) {
      final data = e.response?.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
      if (e.response == null) {
        throw const FloorError('Could not reach the server — check the connection and try again.');
      }
      final details = map['details'] is Map ? Map<String, dynamic>.from(map['details'] as Map) : const <String, dynamic>{};
      throw FloorError(
        map['message']?.toString() ?? 'Something went wrong — try again.',
        status: e.response?.statusCode,
        code: map['code']?.toString(),
        details: details,
      );
    }
  }

  /// Open a shift with its PIN. Keeps the token for the shift.
  Future<FloorState> open({required String dateKey, required String shift, required String pin, required String name}) async {
    final out = await _call(
      () => _dio.post('/floor/open', data: {'dateKey': dateKey, 'shift': shift, 'pin': pin, 'name': name}),
      (b) => (token: b['token']?.toString() ?? '', session: FloorSession.from(b['session']), state: FloorState.from(b['state'])),
    );
    _token = out.token;
    _session = out.session;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kToken, out.token);
      await p.setString(_kSession, jsonEncode(out.session.toJson()));
    } catch (_) {/* a convenience only */}
    return out.state;
  }

  Future<FloorState> shift() =>
      _call(() => _dio.get('/floor/shift'), (b) => FloorState.from(b['state']));

  /// One loom, by its QR label, its id, or its ID as typed.
  Future<FloorMachine> machine(String code) =>
      _call(() => _dio.get('/floor/machine', queryParameters: {'code': code}), (b) => FloorMachine.from(b['machine']));

  /// Puts the loom on the shift with this operator; the first loom makes
  /// the plan when nobody did.
  Future<({String detailId, bool planCreated})> setOperator(String machine, String operator) => _call(
        () => _dio.post('/floor/operator', data: {'machine': machine, 'operator': operator}),
        (b) => (detailId: b['detailId']?.toString() ?? '', planCreated: b['planCreated'] == true),
      );

  Future<FloorSaved> enter({
    required String detailId,
    required double production,
    String? timer,
    String feedback = '',
    String? operator,
  }) =>
      _call(
        () => _dio.post('/floor/entry', data: {
          'detailId': detailId,
          'production': production,
          'timer': (timer == null || timer.isEmpty) ? null : timer,
          'feedback': feedback,
          'operator': operator,
        }),
        FloorSaved.from,
      );

  /// The entry's remark, raised as a machine issue for the fitter (or
  /// linked to the open one it repeats).
  Future<({String title, bool duplicate})> raiseRemarkIssue(String detailId) => _call(
        () => _dio.post('/floor/remark-issue', data: {'detailId': detailId}),
        (b) {
          final issue = b['issue'] is Map ? Map<String, dynamic>.from(b['issue'] as Map) : const <String, dynamic>{};
          return (title: issue['title']?.toString() ?? 'Machine issue', duplicate: b['duplicate'] == true);
        },
      );

  /// Create shift plan: the looms noted become the plan. Refused with
  /// FLOOR_LOOMS_TO_ENTER while looms are still to enter, unless [force].
  Future<({FloorPlan? plan, List<String> freeLooms})> complete({bool force = false}) => _call(
        () => _dio.post('/floor/complete', data: force ? {'force': true} : <String, dynamic>{}),
        (b) => (
          plan: FloorPlan.from(b['plan']),
          freeLooms: (b['freeMachines'] is List)
              ? (b['freeMachines'] as List).map((m) => m is Map ? '${m['ID']}' : '').where((s) => s.isNotEmpty).toList()
              : const <String>[],
        ),
      );

  /// The loom's timer the shift before; null when there was none.
  Future<FloorPreviousTimer?> previousTimer(String machineId) => _call(
        () => _dio.get('/floor/previous-timer-photo', queryParameters: {'machine': machineId}),
        (b) => FloorPreviousTimer.from(b['previous']),
      );
}

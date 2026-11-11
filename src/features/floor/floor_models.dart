// ══════════════════════════════════════════════════════════════
//  FLOOR ENTRY — what the server says (api/floor.js,
//  services/floorEntry.js), read leniently: a field the server leaves
//  out is a null or an empty list here, never a crash on the floor.
// ══════════════════════════════════════════════════════════════

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.map(_map).toList() : const [];
String _s(Object? v) => v?.toString() ?? '';
String? _sn(Object? v) => v?.toString();
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _in(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
double? _dn(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

/// The shift a floor session is open on, and who opened it.
class FloorSession {
  final String dateKey;
  final String shift; // DAY | NIGHT
  final String name;
  const FloorSession({required this.dateKey, required this.shift, required this.name});

  factory FloorSession.from(Object? raw) {
    final j = _map(raw);
    return FloorSession(dateKey: _s(j['dateKey']), shift: _s(j['shift']), name: _s(j['name']));
  }

  Map<String, dynamic> toJson() => {'dateKey': dateKey, 'shift': shift, 'name': name};
  bool get isValid => dateKey.isNotEmpty && (shift == 'DAY' || shift == 'NIGHT');
}

class FloorPerson {
  final String id;
  final String name;
  const FloorPerson(this.id, this.name);
  static FloorPerson? from(Object? raw) {
    final j = _map(raw);
    final id = _s(j['id']);
    return id.isEmpty ? null : FloorPerson(id, _s(j['name']));
  }
}

/// What was entered on a loom this shift.
class FloorSubmitted {
  final double? production; // metres a head
  final String? timer;
  final String feedback;
  final String? at;
  final String byName;
  const FloorSubmitted({this.production, this.timer, this.feedback = '', this.at, this.byName = ''});

  static FloorSubmitted? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    return FloorSubmitted(
      production: _dn(j['production']),
      timer: _sn(j['timer']),
      feedback: _s(j['feedback']),
      at: _sn(j['at']),
      byName: _s(j['byName']),
    );
  }
}

/// The loom's row on the shift.
class FloorDetail {
  final String id;
  final String status;
  final FloorPerson? operator;
  /// The office put this operator on the loom; the floor cannot change it.
  final bool operatorLocked;
  final FloorSubmitted? submitted;
  const FloorDetail({required this.id, required this.status, this.operator, this.operatorLocked = false, this.submitted});

  static FloorDetail? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    final id = _s(j['id']);
    if (id.isEmpty) return null;
    return FloorDetail(
      id: id,
      status: _s(j['status']),
      operator: FloorPerson.from(j['operator']),
      operatorLocked: j['operatorLocked'] == true,
      submitted: FloorSubmitted.from(j['submitted']),
    );
  }
}

/// One loom, as the floor sees it this shift.
class FloorMachine {
  final String id;
  final String code; // the loom's ID as painted on it, e.g. L-02
  final String manufacturer;
  final int? hooks;
  final int? heads;
  final int headsRunning;
  final String status;
  final String? jobNo;
  final String? jobStatus;
  final FloorDetail? detail;
  /// free | loading | unplanned | ready | entered | verified | locked
  final String entry;
  final String? why;
  /// What a head weaves an hour, learned from the loom's own verified
  /// shifts ("machine") or the plant's ("plant").
  final double? metresPerHeadHour;
  final String? rateBasis;
  final int? rateShifts;
  final String? sensorRunTime;

  const FloorMachine({
    required this.id,
    required this.code,
    this.manufacturer = '',
    this.hooks,
    this.heads,
    this.headsRunning = 0,
    this.status = '',
    this.jobNo,
    this.jobStatus,
    this.detail,
    this.entry = 'free',
    this.why,
    this.metresPerHeadHour,
    this.rateBasis,
    this.rateShifts,
    this.sensorRunTime,
  });

  factory FloorMachine.from(Object? raw) {
    final j = _map(raw);
    final job = _map(j['job']);
    final rate = _map(j['rate']);
    final sensor = _map(j['sensor']);
    return FloorMachine(
      id: _s(j['id']),
      code: _s(j['ID']),
      manufacturer: _s(j['manufacturer']),
      hooks: _in(j['hooks']),
      heads: _in(j['heads']),
      headsRunning: _i(j['headsRunning']),
      status: _s(j['status']),
      jobNo: job.isEmpty ? null : _s(job['no']),
      jobStatus: job.isEmpty ? null : _s(job['status']),
      detail: FloorDetail.from(j['detail']),
      entry: _s(j['entry']).isEmpty ? 'free' : _s(j['entry']),
      why: _sn(j['why']),
      metresPerHeadHour: rate.isEmpty ? null : _dn(rate['metresPerHeadHour']),
      rateBasis: rate.isEmpty ? null : _sn(rate['basis']),
      rateShifts: rate.isEmpty ? null : _in(rate['shifts']),
      sensorRunTime: sensor.isEmpty ? null : _sn(sensor['runTime']),
    );
  }

  /// Centimetres a head weaves a minute: the loom's learned rate, else
  /// the plant default the web uses.
  double get cmPerMin =>
      metresPerHeadHour == null ? 30.0 : metresPerHeadHour! * 100 / 60;
}

class FloorPlan {
  final String id;
  final bool finalized;
  /// Made from the floor (operators are the floor's to change).
  final bool fromFloor;
  /// Set once the floor pressed Create shift plan.
  final bool completed;
  final List<String> freeLooms;
  const FloorPlan({required this.id, this.finalized = false, this.fromFloor = false, this.completed = false, this.freeLooms = const []});

  static FloorPlan? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    final floor = j['floor'];
    return FloorPlan(
      id: _s(j['id']),
      finalized: j['finalized'] == true,
      fromFloor: j['fromFloor'] == true,
      completed: floor is Map,
      freeLooms: floor is Map ? _list(_map(floor)['freeMachines']).map((m) => _s(m['ID'])).toList() : const [],
    );
  }

  /// Entries so far are a draft the floor turns into the plan.
  bool get isDraft => fromFloor && !completed;
}

class FloorOperator {
  final String id;
  final String name;
  final String department;
  const FloorOperator(this.id, this.name, this.department);
  String get label => department.isNotEmpty && department != 'weaving' ? '$name ($department)' : name;
}

class FloorState {
  final String dateKey;
  final String shift;
  final String label;
  final bool isCurrent;
  final FloorPlan? plan;
  final List<FloorMachine> machines;
  final List<FloorOperator> operators;
  final int toEnter;
  final int entered;
  const FloorState({
    required this.dateKey,
    required this.shift,
    this.label = '',
    this.isCurrent = true,
    this.plan,
    this.machines = const [],
    this.operators = const [],
    this.toEnter = 0,
    this.entered = 0,
  });

  factory FloorState.from(Object? raw) {
    final j = _map(raw);
    final counts = _map(j['counts']);
    return FloorState(
      dateKey: _s(j['dateKey']),
      shift: _s(j['shift']),
      label: _s(j['label']),
      isCurrent: j['isCurrent'] != false,
      plan: FloorPlan.from(j['plan']),
      machines: _list(j['machines']).map(FloorMachine.from).toList(),
      operators: _list(j['operators'])
          .map((o) => FloorOperator(_s(o['id']), _s(o['name']), _s(o['department'])))
          .where((o) => o.id.isNotEmpty)
          .toList(),
      toEnter: _i(counts['toEnter']),
      entered: _i(counts['entered']),
    );
  }

  FloorState withMachine(FloorMachine m, {FloorPlan? plan}) => FloorState(
        dateKey: dateKey,
        shift: shift,
        label: label,
        isCurrent: isCurrent,
        plan: plan ?? this.plan,
        machines: [for (final x in machines) x.id == m.id ? m : x],
        operators: operators,
        toEnter: toEnter,
        entered: entered,
      );
}

/// A remark, classed by the server; a machine fault is offered to the fitter.
class FloorRemark {
  final String kind;
  final int? minutes;
  final bool machineFault;
  final String? issue;
  const FloorRemark({required this.kind, this.minutes, this.machineFault = false, this.issue});

  static FloorRemark? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    return FloorRemark(
      kind: _s(j['kind']).isEmpty ? 'other' : _s(j['kind']),
      minutes: _in(j['minutes']),
      machineFault: j['machineFault'] == true,
      issue: _sn(j['issue']),
    );
  }
}

/// What saving an entry gives back.
class FloorSaved {
  final FloorMachine machine;
  final FloorPlan? plan;
  final bool autoVerified;
  final List<String> waitsBecause;
  final FloorRemark? remark;
  const FloorSaved({required this.machine, this.plan, this.autoVerified = false, this.waitsBecause = const [], this.remark});

  factory FloorSaved.from(Object? raw) {
    final j = _map(raw);
    return FloorSaved(
      machine: FloorMachine.from(j['machine']),
      plan: FloorPlan.from(j['plan']),
      autoVerified: j['autoVerified'] == true,
      waitsBecause: (j['waitsBecause'] is List)
          ? (j['waitsBecause'] as List).map((e) => e.toString()).toList()
          : const [],
      remark: FloorRemark.from(j['remark']),
    );
  }
}

/// The loom's timer the shift before, for checking today's reading.
class FloorPreviousTimer {
  final String shiftLabel;
  final String? operator;
  final String? runTime;
  final bool verified;
  const FloorPreviousTimer({required this.shiftLabel, this.operator, this.runTime, this.verified = false});

  static FloorPreviousTimer? from(Object? raw) {
    if (raw is! Map) return null;
    final j = _map(raw);
    final photo = _map(j['photo']);
    return FloorPreviousTimer(
      shiftLabel: _s(_map(j['shift'])['label']),
      operator: _sn(j['operator']),
      runTime: _sn(j['runTime']) ?? _sn(photo['runTimeUsed']) ?? _sn(photo['readText']),
      verified: j['verified'] == true,
    );
  }
}

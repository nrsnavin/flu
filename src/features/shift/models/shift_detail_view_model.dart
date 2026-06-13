class ShiftDetailViewModel {
  final String id;
  final String status;
  final String date;
  final String shift;
  final String employeeName;
  final String machineName;
  final String jobNo;
  final int production;
  final String timer;
  final String feedback;
  final List<String> runningElastics;

  ShiftDetailViewModel({
    required this.id,
    required this.status,
    required this.date,
    required this.shift,
    required this.employeeName,
    required this.machineName,
    required this.jobNo,
    required this.production,
    required this.timer,
    required this.feedback,
    required this.runningElastics
  });

  factory ShiftDetailViewModel.fromJson(Map<String, dynamic> s) {

    // Server may return any of `employee`, `machine`, `orderRunning`,
    // or per-row `elastic` as null when the populate didn't resolve.
    // Guard every chain so the page renders something useful instead
    // of crashing on NoSuchMethodError.
    final emp     = s["employee"]     as Map?;
    final machine = s["machine"]      as Map?;
    final order   = machine?["orderRunning"] as Map?;
    final elasticsRaw = s["elastics"] as List? ?? const [];

    return ShiftDetailViewModel(
      id: s["_id"]?.toString() ?? '',
      status: s["status"]?.toString() ?? '',
      date: s["date"]?.toString() ?? '',
      shift: s["shift"]?.toString() ?? '',
      employeeName: emp?["name"]?.toString() ?? '',
      machineName: machine?["ID"]?.toString() ?? '',
      jobNo: order?["jobOrderNo"]?.toString() ?? '',
      production: (s["productionMeters"] as num?)?.toInt() ?? 0,
      timer: s["timer"]?.toString() ?? "00:00:00",
      feedback: s["feedback"]?.toString() ?? "",
      runningElastics: elasticsRaw
          .map((e) {
            final m = e is Map ? e : const {};
            final el = m["elastic"];
            if (el is Map) return el["name"]?.toString() ?? '';
            return '';
          })
          .where((n) => n.isNotEmpty)
          .toList(),
    );
  }
}



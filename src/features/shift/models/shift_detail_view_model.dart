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

    return ShiftDetailViewModel(
      id: s["_id"],
      status: s["status"],
      date: s["date"],
      shift: s["shift"],
      employeeName: s["employee"]["name"],
      machineName: s["machine"]["ID"],
      jobNo: s["machine"]["orderRunning"]!=null?s["machine"]["orderRunning"]["jobOrderNo"].toString():"",
      production: s["productionMeters"] ?? 0,
      timer: s["timer"] ?? "00:00:00",
      feedback: s["feedback"] ?? "",
      runningElastics: (s["elastics"] as List)
          .map((e) => e["elastic"]["name"].toString())
          .toList(),
    );
  }
}



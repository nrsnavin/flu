class ShiftModel {
  final String id;
  final DateTime date;
  final String shift;
  final String operatorName;
  final String machineName;
  final String jobNo;
  final double production;
  final String timer;
  final String status;

  ShiftModel({
    required this.id,
    required this.date,
    required this.shift,
    required this.operatorName,
    required this.machineName,
    required this.jobNo,
    required this.production,
    required this.timer,
    required this.status,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json["_id"],
      date: DateTime.parse(json["date"]),
      shift: json["shift"],
      operatorName: json["employee"]?["name"] ?? "",
      machineName: json["machine"]?["machineId"] ?? "",
      jobNo: json["machine"]?["orderRunning"]?["jobOrderNo"]?.toString() ?? "",
      production: (json["production"] ?? 0).toDouble(),
      timer: json["timer"] ?? "00:00:00",
      status: json["status"] ?? "open",
    );
  }
}

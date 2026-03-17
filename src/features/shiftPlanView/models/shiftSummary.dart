class ShiftSummaryModel {
  final String id;
  final String shift;
  final int runningMachines;
  final int operators;
  final double production;
  final String status;

  ShiftSummaryModel({
    required this.id,
    required this.shift,
    required this.runningMachines,
    required this.operators,
    required this.production,
    required this.status,
  });

  factory ShiftSummaryModel.fromJson(Map<String, dynamic> json) {
    return ShiftSummaryModel(
      id: json["_id"] ?? "test",
      // BUG FIX: added fallback for shift field to avoid null throw
      shift: json["shift"] ?? "",
      runningMachines: json["machinesRunning"] ?? 0,
      operators: json["operatorCount"] ?? 0,
      production: (json["totalProduction"] ?? 0).toDouble(),
      status: json["status"] ?? "open",
    );
  }
}
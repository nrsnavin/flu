class ShiftPlanDetailModel {
  final String id;
  final DateTime date;
  final String shift;
  final String description;
  final int totalProduction;
  final int operatorCount;
  final List<ShiftMachineDetail> machines;

  ShiftPlanDetailModel({
    required this.id,
    required this.date,
    required this.shift,
    required this.description,
    required this.totalProduction,
    required this.operatorCount,
    required this.machines,
  });

  factory ShiftPlanDetailModel.fromJson(Map<String, dynamic> json) {
    return ShiftPlanDetailModel(
      operatorCount:json['operatorCount'],
      id: json['_id'],
      date: DateTime.parse(json['date']),
      shift: json['shift'],
      description: json['description'] ?? "",
      totalProduction: json['totalProduction'] ?? 0,
      machines: (json['machines'] as List)
          .map((e) => ShiftMachineDetail.fromJson(e))
          .toList(),
    );
  }
}

class ShiftMachineDetail {
  final String machineId;
  final String machineName;
  final String jobOrderNo;
  final String operatorName;
  final int production;
  final String timer;
  final String status;

  ShiftMachineDetail({
    required this.machineId,
    required this.machineName,
    required this.jobOrderNo,
    required this.operatorName,
    required this.production,
    required this.timer,
    required this.status,
  });

  factory ShiftMachineDetail.fromJson(Map<String, dynamic> json) {
    return ShiftMachineDetail(
      machineId: json['machineId'],
      machineName: json['machineName'],
      jobOrderNo: json['jobOrderNo'],
      operatorName: json['operatorName'],
      production: json['production'] ?? 0,
      timer: json['timer'] ?? "00:00:00",
      status: json['status'] ?? "open",
    );
  }
}

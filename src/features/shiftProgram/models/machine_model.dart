class OperatorModel {
  final String id;
  final String name;

  OperatorModel({required this.id, required this.name});

  factory OperatorModel.fromJson(Map<String, dynamic> json) {
    return OperatorModel(
      id: json['_id'],
      name: json['name'],
    );
  }
}
class MachineRunningModel {
  final String machineId;
  final String machineCode;
  final String jobOrderNo;

  MachineRunningModel({
    required this.machineId,
    required this.machineCode,
    required this.jobOrderNo,
  });

  factory MachineRunningModel.fromJson(Map<String, dynamic> json) {
    return MachineRunningModel(
      machineId: json['machineId'],
      machineCode: json['ID'],
      jobOrderNo: json['jobOrderNo'].toString(),
    );
  }
}

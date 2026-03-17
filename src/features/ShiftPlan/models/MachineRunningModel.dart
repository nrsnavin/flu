/// Enhanced MachineRunningModel.
/// Original only had machineId, machineCode, jobOrderNo.
/// Added manufacturer, noOfHeads, elastics for richer UI display.
class MachineRunningModel {
  final String machineId;
  final String machineCode;
  final String jobOrderNo;
  final String? manufacturer;
  final int noOfHeads;
  final List<Map<String, dynamic>> elastics;

  const MachineRunningModel({
    required this.machineId,
    required this.machineCode,
    required this.jobOrderNo,
    this.manufacturer,
    this.noOfHeads = 1,
    this.elastics = const [],
  });

  /// Display-friendly label: "M-12" or "Lindauer M-12"
  String get displayName =>
      manufacturer != null && manufacturer!.isNotEmpty
          ? '$manufacturer $machineCode'
          : machineCode;

  factory MachineRunningModel.fromJson(Map<String, dynamic> json) {
    return MachineRunningModel(
      machineId:    json['machineId']?.toString()   ?? json['_id']?.toString() ?? '',
      machineCode:  json['machineCode']?.toString() ?? json['ID']?.toString()  ?? '—',
      jobOrderNo:   json['jobOrderNo']?.toString()  ?? '',
      manufacturer: json['manufacturer']?.toString(),
      noOfHeads:    (json['noOfHeads'] as num?)?.toInt() ??
          (json['NoOfHead'] as num?)?.toInt() ?? 1,
      elastics:     (json['elastics'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          [],
    );
  }
}
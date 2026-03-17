/// FIX: This file was COMPLETELY BLANK in the original upload.
/// The model is used throughout shiftPlan_controller.dart and
/// shift_plan_create.dart — without it nothing compiled.
class OperatorModel {
  final String id;
  final String name;
  final String? department;
  final String? phone;

  const OperatorModel({
    required this.id,
    required this.name,
    this.department,
    this.phone,
  });

  factory OperatorModel.fromJson(Map<String, dynamic> json) {
    return OperatorModel(
      id:         json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name:       json['name']?.toString() ?? '—',
      department: json['department']?.toString(),
      phone:      json['phone']?.toString(),
    );
  }

  @override
  String toString() => name;
}
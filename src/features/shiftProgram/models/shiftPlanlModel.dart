import 'package:production/src/features/shiftProgram/models/shiftOpenListModel.dart';

class ShiftPlanModel {
  String id;
  String date;
  String shift;
  String description;
  int production;
  List plan;

  ShiftPlanModel({
    required this.id,
    required this.description,
    required this.production,
    required this.shift,
    required this.date,
    required this.plan,
  });

  factory ShiftPlanModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        '_id': String id,
        'date': String date,
        'shift': String shift,
        'description': String description,
        'totalProduction': int production,
      } =>
        ShiftPlanModel(
          id: json['_id'],
          date: date,
          shift: shift,
          production: production,
          description: description,
          plan: json['plan'].toList(),
        ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }
}

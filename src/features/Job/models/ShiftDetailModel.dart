class ShiftDetailModelView {
  final String id;
  final DateTime date;
  final String shift;
  final String operatorName;
  final double production;

  ShiftDetailModelView({
    required this.id,
    required this.date,
    required this.shift,
    required this.operatorName,
    required this.production,
  });

  factory ShiftDetailModelView.fromJson(Map<String, dynamic> json) {
    return ShiftDetailModelView(
      id: json["_id"],
      date: DateTime.parse(json["date"]),
      shift: json["shift"] ?? "",
      operatorName: json["employee"]?["name"] ?? "Not Assigned",
      production: (json["productionMeters"] ?? 0).toDouble(),
    );
  }
}

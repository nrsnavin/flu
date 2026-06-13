import 'eqv.dart';

class PreparatoryView {
  final String id;
  final String status;
  final DateTime date;
  final List<ElasticQtyView> elastics;

  PreparatoryView({
    required this.id,
    required this.status,
    required this.date,
    required this.elastics,
  });

  factory PreparatoryView.fromJson(Map<String, dynamic> json) {
    return PreparatoryView(
      id: json['_id'],
      status: json['status'],
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
      elastics: (json['elasticOrdered'] ??
          json['elasticPlanned'] ??
          [])
          .map<ElasticQtyView>((e) => ElasticQtyView.fromJson(e))
          .toList(),
    );
  }
}

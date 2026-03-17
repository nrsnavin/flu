import 'package:production/src/features/Job/models/raw.dart';

import 'ElasticQtyModel.dart';
import 'job.dart';

class OrderModel {
  final String id;
  final int orderNo;
  final DateTime date;
  final DateTime supplyDate;
  final String po;
  final String description;
  final String status;

  final String customerId;
  final String customerName;

  final List<ElasticQtyModel> elasticOrdered;
  final List<ElasticQtyModel> producedElastic;
  final List<ElasticQtyModel> packedElastic;
  final List<ElasticQtyModel> pendingElastic;

  final List<RawMaterialRequirementModel> rawMaterialRequired;
  final List<JobRefModel> jobs;

  OrderModel({
    required this.id,
    required this.orderNo,
    required this.date,
    required this.supplyDate,
    required this.po,
    required this.description,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.elasticOrdered,
    required this.producedElastic,
    required this.packedElastic,
    required this.pendingElastic,
    required this.rawMaterialRequired,
    required this.jobs,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'],
      orderNo: json['orderNo'],
      date: DateTime.parse(json['date']),
      supplyDate: DateTime.parse(json['supplyDate']),
      po: json['po'],
      description: json['description'] ?? '',
      status: json['status'],

      customerId: json['customer'] is Map
          ? json['customer']['_id']
          : json['customer'],
      customerName: json['customer'] is Map
          ? json['customer']['name']
          : '',

      elasticOrdered: (json['elastics'] as List<dynamic>? ?? [])
          .map((e) => ElasticQtyModel(elasticId: e['id'], elasticName: e['name'], quantity: e['ordered']))
          .toList(),

      producedElastic: (json['elastics'] as List<dynamic>? ?? [])
          .map((e) => ElasticQtyModel(elasticId: e['id'], elasticName: e['name'], quantity: e['produced']))
          .toList(),

      packedElastic: (json['elastics'] as List<dynamic>? ?? [])
          .map((e) => ElasticQtyModel(elasticId: e['id'], elasticName: e['name'], quantity: e['packed']))
          .toList(),

      pendingElastic: (json['elastics'] as List<dynamic>? ?? [])
          .map((e) => ElasticQtyModel(elasticId: e['id'], elasticName: e['name'], quantity: e['pending']))
          .toList(),

      rawMaterialRequired:
      (json['rawMaterialRequired'] as List<dynamic>? ?? [])
          .map((e) => RawMaterialRequirementModel.fromJson(e))
          .toList(),

      // jobs: (json['jobs'] as List<dynamic>? ?? [])
      //     .map((e) => JobRefModel.fromJson(e))
      //     .toList(),

      jobs: []
    );
  }
}

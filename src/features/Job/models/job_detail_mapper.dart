import 'package:production/src/features/Job/models/preparatory_model.dart';
import 'package:production/src/features/Job/models/wastage_view.dart';

import '../../shiftProgram/models/shiftDetailModel.dart';
import 'ShiftDetailModel.dart';
import 'eqv.dart';
import 'job_detail.dart';

class JobDetailViewMapper {
  static JobDetailView fromApi(Map<String, dynamic> json) {
    return JobDetailView(
      id: json['_id'],
      jobNo: json['jobOrderNo'],
      status: json['status'],
      date: DateTime.parse(json['date']),

      // 🧶 Preparatory
      warping: json['warping'] != null
          ? PreparatoryView.fromJson(json['warping'])
          : null,

      covering: json['covering'] != null
          ? PreparatoryView.fromJson(json['covering'])
          : null,

      // 🏭 Machine
      machineName: json['machine'] != null
          ? json['machine']['ID']
          : null,

      // 👷 Employees (from shift details)
      weavingEmployees: _extractEmployees(json['shiftDetails']),

      // 🧵 Elastic Quantities
      planned: _mapElasticQty(json['elastics']),
      produced: _mapElasticQty(json['producedElastic']),
      packed: _mapElasticQty(json['packedElastic']),

      // ♻️ Wastages
      wastages: _mapWastages(json['wastages'] ?? []),
      shiftDetails: (json["shiftDetails"] as List? ?? [])
          .map((e) => ShiftDetailModelView.fromJson(e))
          .toList(),
    );
  }

  /// 🧵 Elastic Qty Mapper
  static List<ElasticQtyView> _mapElasticQty(List<dynamic>? list) {
    if (list == null) return [];

    return list.map((e) {
      final elastic = e['elastic'];
      return ElasticQtyView(
        elasticId: elastic is Map ? elastic['_id'] : elastic,
        elasticName: elastic is Map ? elastic['name'] ?? '' : '',
        quantity: (e['quantity'] ?? 0).toDouble(),
      );
    }).toList();
  }

  /// 👷 Extract employees from latest shift
  static List<String> _extractEmployees(List<dynamic>? shifts) {
    if (shifts == null || shifts.isEmpty) return [];

    final latestShift = shifts.last;

    final employees = latestShift['employees'] as List<dynamic>?;

    if (employees == null) return [];

    return employees
        .map((e) => e is Map ? e['name'].toString() : '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// ♻️ Wastage Mapper
  static List<WastageView> _mapWastages(List<dynamic> list) {
    return list.map((w) {
      return WastageView(
        elasticName: w['elastic'] != null ? w['elastic']['name'] : '',
        quantity: (w['quantity'] ?? 0).toDouble(),
        reason: w['reason'] ?? '',
      );
    }).toList();
  }
}

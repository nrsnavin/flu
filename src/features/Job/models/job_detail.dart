import 'package:production/src/features/Job/models/preparatory_model.dart';
import 'package:production/src/features/Job/models/wastage_view.dart';

import '../../shiftProgram/models/shiftDetailModel.dart';
import 'ShiftDetailModel.dart';
import 'eqv.dart';

class JobDetailView {
  final String id;
  final int jobNo;
  final String status;
  final DateTime date;

  final PreparatoryView? warping;
  final PreparatoryView? covering;

  final String? machineName;
  final List<String> weavingEmployees;

  final List<ElasticQtyView> planned;
  final List<ElasticQtyView> produced;
  final List<ElasticQtyView> packed;
  final List<WastageView> wastages;
  final List<ShiftDetailModelView> shiftDetails;



  JobDetailView({
    required this.id,
    required this.jobNo,
    required this.status,
    required this.date,
    this.warping,
    this.covering,
    this.machineName,
    required this.weavingEmployees,
    required this.planned,
    required this.produced,
    required this.packed,
    required this.wastages,
    required this.shiftDetails
  });
}

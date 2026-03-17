import 'package:flutter/cupertino.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class OrderElasticRow {
  RxnString elasticId = RxnString();
  final TextEditingController qtyCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
  }
}

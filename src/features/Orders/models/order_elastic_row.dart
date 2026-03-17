import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderElasticRow {
  /// MongoDB _id of the chosen elastic.
  final RxnString elasticId = RxnString();

  /// Display name — stored here so the picker field can show it
  /// without needing to look up the elastic list again.
  final RxnString selectedElasticName = RxnString();

  final TextEditingController qtyCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
  }
}
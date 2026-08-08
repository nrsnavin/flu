class ElasticQtyModel {
  final String elasticId;
  final String elasticName;

  // Metres, and metres are fractional — the order form takes two
  // decimals. Declared `int` while the factory below assigned
  // `.toDouble()` to it, which type-checks only because the JSON value
  // arrives as `dynamic`: the mismatch surfaced at RUNTIME, as a cast
  // error building the order, the first time a quantity was not whole.
  final double quantity;

  ElasticQtyModel({
    required this.elasticId,
    required this.elasticName,
    required this.quantity,
  });

  factory ElasticQtyModel.fromJson(Map<String, dynamic> json) {
    return ElasticQtyModel(
      elasticId: json['elastic'] is Map
          ? json['elastic']['_id']
          : json['elastic'],
      elasticName: json['elastic'] is Map
          ? json['elastic']['name']
          : '',
      quantity: (json['quantity'] ?? 0).toDouble(),
    );
  }
}

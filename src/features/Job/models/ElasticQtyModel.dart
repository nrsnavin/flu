class ElasticQtyModel {
  final String elasticId;
  final String elasticName;
  final int quantity;

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

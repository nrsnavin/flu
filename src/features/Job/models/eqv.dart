class ElasticQtyView {
  final String elasticId;
  final String elasticName;
  final double quantity;

  ElasticQtyView({
    required this.elasticId,
    required this.elasticName,
    required this.quantity,
  });

  factory ElasticQtyView.fromJson(Map<String, dynamic> json) {
    return ElasticQtyView(
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

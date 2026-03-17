class ElasticListModel {
  final String id;
  final String name;
  final String weaveType;
  final double stock;

  ElasticListModel({
    required this.id,
    required this.name,
    required this.weaveType,
    required this.stock,
  });

  factory ElasticListModel.fromJson(Map<String, dynamic> json) {
    return ElasticListModel(
      id: json["_id"],
      name: json["name"],
      weaveType: json["weaveType"],
      stock: (json["stock"] ?? 0).toDouble(),
    );
  }
}

class ElasticListModel {
  final String id;
  final String name;
  final String weaveType;
  final double stock;
  final bool archived;

  ElasticListModel({
    required this.id,
    required this.name,
    required this.weaveType,
    required this.stock,
    this.archived = false,
  });

  factory ElasticListModel.fromJson(Map<String, dynamic> json) {
    return ElasticListModel(
      id: json["_id"]?.toString() ?? '',
      name: json["name"]?.toString() ?? '—',
      weaveType: json["weaveType"]?.toString() ?? '—',
      stock: (json["stock"] as num?)?.toDouble() ?? 0,
      archived: json["archived"] == true,
    );
  }
}

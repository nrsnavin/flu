class JobElasticModel {
  final String id;
  final String name;
  final int quantity;

  JobElasticModel({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory JobElasticModel.fromJson(Map<String, dynamic> json) {
    return JobElasticModel(
      id: json["elastic"]["_id"],
      name: json["elastic"]["name"],
      quantity: json["quantity"],
    );
  }
}

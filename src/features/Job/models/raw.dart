class RawMaterialRequirementModel {
  final String rawMaterialId;
  final String name;
  final double requiredWeight;
  final double inStock;

  RawMaterialRequirementModel({
    required this.rawMaterialId,
    required this.name,
    required this.requiredWeight,
    required this.inStock,
  });

  factory RawMaterialRequirementModel.fromJson(Map<String, dynamic> json) {
    return RawMaterialRequirementModel(
      rawMaterialId: json['rawMaterial'],
      name: json['name'] ?? '',
      requiredWeight: (json['requiredWeight'] ?? 0).toDouble(),
      inStock: (json['inStock'] ?? 0).toDouble(),
    );
  }
}

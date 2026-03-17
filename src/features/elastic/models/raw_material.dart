class RawMaterialMini {
  final String id;
  final String name;
  final double price;
  final String category;

  RawMaterialMini({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
  });

  factory RawMaterialMini.fromJson(Map<String, dynamic> json) {
    return RawMaterialMini(
      id: json["_id"],
      name: json["name"],
      price: (json["price"] ?? 0).toDouble(),
      category: json["category"],
    );
  }
}

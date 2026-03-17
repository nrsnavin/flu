class MachineAssignmentModel {
  final MachineModel machine;
  final Map<int, ElasticMini> headElasticMap;

  MachineAssignmentModel({
    required this.machine,
    required this.headElasticMap,
  });
}
class ElasticMini {
  final String id;
  final String name;

  ElasticMini({
    required this.id,
    required this.name,
  });

  factory ElasticMini.fromJson(Map<String, dynamic> json) {
    return ElasticMini(
      id: json['_id'] ?? json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
    };
  }
}



class MachineModel {
  final String id;
  final String code;          // Machine Code / ID shown to users
  final int noOfHeads;        // Number of weaving heads
  final int noOfHooks;        // Hooks per head
  final String manufacturer;
  final String status;        // free | running | maintenance
  final String? orderRunning; // JobOrder ID if running

  /// Optional: head → elastic mapping (used after weaving plan)
  final Map<int, ElasticMini>? headElasticMap;

  MachineModel({
    required this.id,
    required this.code,
    required this.noOfHeads,
    required this.noOfHooks,
    required this.manufacturer,
    required this.status,
    this.orderRunning,
    this.headElasticMap,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      id: json['_id'],
      code: json['code'] ?? json['machineCode'] ?? '',
      noOfHeads: json['noOfHeads'] ?? 0,
      noOfHooks: json['noOfHooks'] ?? 0,
      manufacturer: json['manufacturer'] ?? '',
      status: json['status'] ?? 'free',
      orderRunning: json['orderRunning'],
      headElasticMap: json['headElasticMap'] != null
          ? (json['headElasticMap'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(
          int.parse(k),
          ElasticMini.fromJson(v),
        ),
      )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "code": code,
      "noOfHeads": noOfHeads,
      "noOfHooks": noOfHooks,
      "manufacturer": manufacturer,
      "status": status,
      "orderRunning": orderRunning,
      "headElasticMap": headElasticMap?.map(
            (k, v) => MapEntry(k.toString(), v.toJson()),
      ),
    };
  }

  /// Convenience helpers
  bool get isFree => status == "free";
  bool get isRunning => status == "running";
}

class MachineSelectModel {
  final String id;
  final String status;
  final String manufacturer;
  final String ID;
  final String NoOfHooks;
  final String NoOfHeads;

  MachineSelectModel({
    required this.id,
    required this.status,
    required this.manufacturer,
    required this.ID,
    required this.NoOfHeads,
    required this.NoOfHooks,
  });

  factory MachineSelectModel.fromJson(Map<String, dynamic> json) {
    return MachineSelectModel(
      id: json['_id'],
      status: json['status'],
      manufacturer: json['manufacturer'],
      ID: json['ID'],
      NoOfHeads: json['NoOfHead'].toString(),
      NoOfHooks: json['NoOfHooks'].toString(),
    );
  }
}

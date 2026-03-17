class ShiftDetailModel {
  String id;
  String employee;
  String machine;
  String date;
  String shift;

  String description;
  int production;

  String elastics;
  int noOfHooks;
  int noOfHeads;
  String status;

  ShiftDetailModel({
    required this.id,
    required this.employee,
    required this.machine,
    required this.status,

    required this.description,

    required this.production,
    required this.elastics,
    required this.shift,
    required this.date,
    required this.noOfHooks,
    required this.noOfHeads,
  });

  factory ShiftDetailModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        '_id': String id,
        'date': String date,
        'employee': Map emp,
        'machine': Map machine,
      'status':String status,
        'shift': String shift,
        'description': String description,
        'production': int production,
      'elastics':String el
      } =>
        ShiftDetailModel(
          id: json['_id'],
          employee: emp['name'],
          date: date,
          status: status,
          machine: machine['ID'],
          shift: shift,
          production: production,
          elastics: el,
          noOfHeads: machine['NoOfHead'],
          noOfHooks: machine['NoOfHooks'],
          description: description,
        ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }
}

class ShiftOpenListModel {
  String id;
  String employee;
  String machine;
  String date;
  String shift;
  int heads;
  int production;
  String elastic;

  ShiftOpenListModel({
    required this.id,
    required this.employee,
    required this.machine,
    required this.shift,
    required this.date,
    required this.heads,
    required this.elastic,
    required this.production,
  });

  factory ShiftOpenListModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        '_id': String id,
        'date': String date,
        'employee': Map emp,
        'machine': Map machine,
        'shift': String shift,
        'production': int production,
      'elastics':String el,

      } =>
        ShiftOpenListModel(
          id: id,
          employee: emp['name'],
          date: date,
          machine: machine['ID'],
          shift: shift,
          heads: machine['NoOfHead'],
          elastic: el,
          production: production,
        ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }
}

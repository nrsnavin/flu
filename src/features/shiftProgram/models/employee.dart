class Employee {
  String id;
  String name;
  String department;

  Employee({required this.name, required this.department, required this.id});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'_id': String id, 'name': String name, 'department': String dept} =>
        Employee(id: id, name: name, department: dept),
      _ => throw const FormatException('Failed to load album.'),
    };
  }
}

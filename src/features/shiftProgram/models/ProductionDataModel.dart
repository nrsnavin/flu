import 'dart:ffi';

class ProductionRow {
  final String operatorName;
  final String machineCode;
  final int heads;
  final int hooks;
  final int production;
  final int totalProduction;
  final Duration timer;
  final double efficiency;
  final Duration downtimeMinutes;

  ProductionRow({
    required this.operatorName,
    required this.machineCode,
    required this.heads,
    required this.hooks,
    required this.production,
    required this.totalProduction,
    required this.timer,
    required this.efficiency,
    required this.downtimeMinutes,
  });


  factory ProductionRow.fromJson(Map<String, dynamic> json) {

    Duration parseHHmmss(String time) {
      final parts = time.split(':');

      return Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
        seconds: int.parse(parts[2]),
      );
    }
    return switch (json) {
      {
      'employee': Map emp,
      'machine': Map machine,
      'production': int production,
      'timer':String timer
      } =>
          ProductionRow(
            machineCode: machine['ID'],
            operatorName: emp['name'],
            heads: machine['NoOfHead'],
            hooks: machine['NoOfHooks'],
            production: production,
            totalProduction: (production * machine['NoOfHead']) as int,
            timer: parseHHmmss(timer),
            efficiency: parseHHmmss(timer).inMinutes*100/Duration(hours: 12).inMinutes,
            downtimeMinutes:Duration(hours: 12) -parseHHmmss(timer),
          ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }


}

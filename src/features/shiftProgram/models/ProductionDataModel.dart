
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
      // Bad strings ("7h 30m", "", non-3-part) fall back to zero so a
      // single malformed shift row doesn't crash the whole list.
      int part(int i) =>
          (parts.length > i ? int.tryParse(parts[i]) : null) ?? 0;
      return Duration(
        hours:   part(0),
        minutes: part(1),
        seconds: part(2),
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
            heads: (machine['NoOfHead'] as num?)?.toInt() ?? 0,
            hooks: (machine['NoOfHooks'] as num?)?.toInt() ?? 0,
            production: production,
            totalProduction:
                production * (((machine['NoOfHead'] as num?)?.toInt()) ?? 1),
            timer: parseHHmmss(timer),
            efficiency: parseHHmmss(timer).inMinutes*100/Duration(hours: 12).inMinutes,
            downtimeMinutes:Duration(hours: 12) -parseHHmmss(timer),
          ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }


}

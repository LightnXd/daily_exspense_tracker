class DailyEntry {
  final DateTime date;
  final double? breakfast;
  final double? lunch;
  final double? dinner;
  final double? snack;

  DailyEntry({
    required this.date,
    this.breakfast,
    this.lunch,
    this.dinner,
    this.snack,
  });

  double sum() {
    return (breakfast ?? 0) + (lunch ?? 0) + (dinner ?? 0) + (snack ?? 0);
  }

  factory DailyEntry.fromMap(Map<String, dynamic> m) {
    return DailyEntry(
      date: DateTime.parse(m['date'] as String),
      breakfast: m['breakfast'] == null ? null : (m['breakfast'] as num).toDouble(),
      lunch: m['lunch'] == null ? null : (m['lunch'] as num).toDouble(),
      dinner: m['dinner'] == null ? null : (m['dinner'] as num).toDouble(),
      snack: m['snack'] == null ? null : (m['snack'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'snack': snack,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory DailyEntry.fromJson(Map<String, dynamic> json) => DailyEntry.fromMap(json);
}

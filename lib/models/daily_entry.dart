class DailyEntry {
  final DateTime date;
  final int? breakfast;
  final int? lunch;
  final int? dinner;
  final int? snack;

  DailyEntry({
    required this.date,
    this.breakfast,
    this.lunch,
    this.dinner,
    this.snack,
  });

  int sum() {
    return (breakfast ?? 0) + (lunch ?? 0) + (dinner ?? 0) + (snack ?? 0);
  }

  factory DailyEntry.fromMap(Map<String, dynamic> m) {
    return DailyEntry(
      date: DateTime.parse(m['date'] as String),
      breakfast: m['breakfast'] == null ? null : m['breakfast'] as int,
      lunch: m['lunch'] == null ? null : m['lunch'] as int,
      dinner: m['dinner'] == null ? null : m['dinner'] as int,
      snack: m['snack'] == null ? null : m['snack'] as int,
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
}

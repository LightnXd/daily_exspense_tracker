import '../models/daily_entry.dart';

class DayRow {
  final int day;
  final double? breakfast;
  final double? lunch;
  final double? dinner;
  final double? snack;
  final double left;

  DayRow({required this.day, this.breakfast, this.lunch, this.dinner, this.snack, required this.left});
}

class MonthlyReport {
  final List<DayRow> days;
  final double sumBreakfast;
  final double sumLunch;
  final double sumDinner;
  final double sumSnack;
  final double totalLeft;
  final double totalDailyFood;
  final double? meanBreakfast;
  final double? meanLunch;
  final double? meanDinner;
  final double? meanSnack;
  final double? meanLeft;

  MonthlyReport({
    required this.days,
    required this.sumBreakfast,
    required this.sumLunch,
    required this.sumDinner,
    required this.sumSnack,
    required this.totalLeft,
    required this.totalDailyFood,
    this.meanBreakfast,
    this.meanLunch,
    this.meanDinner,
    this.meanSnack,
    this.meanLeft,
  });
}

MonthlyReport computeMonthlyReport(int year, int month, List<DailyEntry> entries, int budget) {
  final map = <int, DailyEntry>{};
  for (final e in entries) map[e.date.day] = e;

  double sumBreakfast = 0, sumLunch = 0, sumDinner = 0, sumSnack = 0;
  int countBreakfast = 0, countLunch = 0, countDinner = 0, countSnack = 0;
  double totalLeft = 0;
  int countDaysWithEntries = 0;

  final lastDay = DateTime(year, month + 1, 0).day;
  final days = <DayRow>[];
  for (int d = 1; d <= lastDay; d++) {
    final r = map[d];
    if (r?.breakfast != null) {
      sumBreakfast += r!.breakfast!;
      countBreakfast++;
    }
    if (r?.lunch != null) {
      sumLunch += r!.lunch!;
      countLunch++;
    }
    if (r?.dinner != null) {
      sumDinner += r!.dinner!;
      countDinner++;
    }
    if (r?.snack != null) {
      sumSnack += r!.snack!;
      countSnack++;
    }
    final double left = r != null ? budget - r.sum() : budget.toDouble();
    if (r != null) {
      totalLeft += left;
      countDaysWithEntries++;
    }
    days.add(DayRow(day: d, breakfast: r?.breakfast, lunch: r?.lunch, dinner: r?.dinner, snack: r?.snack, left: left));
  }

  final meanBreakfast = countBreakfast == 0 ? null : sumBreakfast / countBreakfast;
  final meanLunch = countLunch == 0 ? null : sumLunch / countLunch;
  final meanDinner = countDinner == 0 ? null : sumDinner / countDinner;
  final meanSnack = countSnack == 0 ? null : sumSnack / countSnack;
  final meanLeft = countDaysWithEntries == 0 ? null : totalLeft / countDaysWithEntries;
  final totalDailyFood =  sumBreakfast + sumLunch + sumDinner + sumSnack;

  return MonthlyReport(
    days: days,
    sumBreakfast: sumBreakfast,
    sumLunch: sumLunch,
    sumDinner: sumDinner,
    sumSnack: sumSnack,
    totalLeft: totalLeft,
    totalDailyFood: totalDailyFood,
    meanBreakfast: meanBreakfast,
    meanLunch: meanLunch,
    meanDinner: meanDinner,
    meanSnack: meanSnack,
    meanLeft: meanLeft,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_expense_tracker/models/daily_entry.dart';
import 'package:daily_expense_tracker/utils/report_utils.dart';

void main() {
  test('computeMonthlyReport aggregates correctly', () {
    final entries = [
      DailyEntry(date: DateTime(2026, 1, 1), breakfast: 10000, lunch: 5000),
      DailyEntry(date: DateTime(2026, 1, 3), dinner: 2000, snack: 1000),
      DailyEntry(date: DateTime(2026, 1, 31), breakfast: 1000),
    ];
    final budget = 60000;
    final report = computeMonthlyReport(2026, 1, entries, budget);

    expect(report.sumBreakfast, 11000);
    expect(report.sumLunch, 5000);
    expect(report.sumDinner, 2000);
    expect(report.sumSnack, 1000);
    expect(report.days.length, 31);
    // day 2 has no data, left should be budget
    expect(report.days[1].left, budget);
    // totalLeft only accumulates for days with entries
    final expectedTotalLeft = (budget - (10000 + 5000)) + (budget - (2000 + 1000)) + (budget - 1000);
    expect(report.totalLeft, expectedTotalLeft);
    final expectedMeanLeft = (expectedTotalLeft / 3).round();
    expect(report.meanLeft, expectedMeanLeft);
  });
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../models/grand_purchase.dart';
import '../services/db_helper.dart';
import '../services/prefs.dart';
import '../utils/report_utils.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd/MM');
  List<DailyEntry> _rows = [];
  List<GrandPurchase> _specialRows = [];

  @override
  void initState() {
    super.initState();
    _load();
    PrefsService.dailyBudget.addListener(_load);
  }

  @override
  void dispose() {
    PrefsService.dailyBudget.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await DBHelper().getEntriesForMonth(_year, _month);
    final special = await DBHelper().getGrandPurchasesForMonth(_year, _month);
    setState(() {
      _rows = entries;
      _specialRows = special;
    });
  }

  Widget _buildTable() {
    final budget = PrefsService.dailyBudget.value;
    final report = computeMonthlyReport(_year, _month, _rows, budget);

    // Show only days that have any spending. If none, show only header + Mean/Total with '-'.
    final daysWithSpending = report.days.where((d) => d.breakfast != null || d.lunch != null || d.dinner != null || d.snack != null).toList();
    final hasSpending = daysWithSpending.isNotEmpty;

    final rows = hasSpending
        ? daysWithSpending.map((d) {
            return DataRow(cells: [
              DataCell(Text('${d.day}')),
              DataCell(Text(d.breakfast == null ? '-' : _fmt.format(d.breakfast))),
              DataCell(Text(d.lunch == null ? '-' : _fmt.format(d.lunch))),
              DataCell(Text(d.dinner == null ? '-' : _fmt.format(d.dinner))),
              DataCell(Text(d.snack == null ? '-' : _fmt.format(d.snack))),
              DataCell(Text(_fmt.format(d.left))),
            ]);
          }).toList()
        : <DataRow>[];

    final meanRow = DataRow(cells: [
      const DataCell(Text('%')),
      DataCell(Text(report.meanBreakfast == null ? '-' : _fmt.format(report.meanBreakfast))),
      DataCell(Text(report.meanLunch == null ? '-' : _fmt.format(report.meanLunch))),
      DataCell(Text(report.meanDinner == null ? '-' : _fmt.format(report.meanDinner))),
      DataCell(Text(report.meanSnack == null ? '-' : _fmt.format(report.meanSnack))),
      DataCell(Text(report.meanLeft == null ? '-' : _fmt.format(report.meanLeft))),
    ]);

    final totalRow = DataRow(cells: [
      const DataCell(Text('+')),
      DataCell(Text(hasSpending ? _fmt.format(report.sumBreakfast) : '-')),
      DataCell(Text(hasSpending ? _fmt.format(report.sumLunch) : '-')),
      DataCell(Text(hasSpending ? _fmt.format(report.sumDinner) : '-')),
      DataCell(Text(hasSpending ? _fmt.format(report.sumSnack) : '-')),
      DataCell(Text(hasSpending ? _fmt.format(report.totalLeft) : '-')),
    ]);

    final allRows = <DataRow>[...rows, meanRow, totalRow];

    return SizedBox(
      width: double.infinity,
      child: DataTable(
        columnSpacing: 8,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 40,
        headingRowHeight: 36,
        columns: const [
          DataColumn(label: Text('Day')),
          DataColumn(label: Text('BF')),
          DataColumn(label: Text('LC')),
          DataColumn(label: Text('DN')),
          DataColumn(label: Text('SN')),
          DataColumn(label: Text('Left')),
        ],
        rows: allRows,
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _summaryLine(String label, int value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              _fmt.format(value),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
      );

  /// Builds a simple purchase row: [displayName] — [price] — [date dd/MM]
  /// with an optional italic desc line underneath.
  Widget _purchaseRow(GrandPurchase p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.displayName,
                    style: const TextStyle(fontSize: 13)),
              ),
              Text(_fmt.format(p.price),
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 12),
              Text(_dateFmt.format(p.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const sizedBox(width: 20),
            ],
          ),
          if (p.desc != null && p.desc!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Text(p.desc!,
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecialSection() {
    if (_specialRows.isEmpty) return const SizedBox.shrink();

    final budget = PrefsService.dailyBudget.value;
    final report = computeMonthlyReport(_year, _month, _rows, budget);

    final foodItems = _specialRows.where((p) => p.type == 'food&drink').toList();
    final otherItems = List<GrandPurchase>.from(
        _specialRows.where((p) => p.type != 'food&drink'))
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalFoodDrink = foodItems.fold<int>(0, (s, p) => s + p.price);
    final totalFoodBudgetLeft = report.totalLeft - totalFoodDrink;

    final totalAll = _specialRows.fold<int>(0, (s, p) => s + p.price);

    // Days with entries for grand total formula
    final daysWithEntries = report.days
        .where((d) =>
            d.breakfast != null ||
            d.lunch != null ||
            d.dinner != null ||
            d.snack != null)
        .length;
    final grandTotal =
        totalAll + (budget * daysWithEntries - totalFoodBudgetLeft);

    // Per-type totals for other items
    final typeMap = <String, int>{};
    for (final p in otherItems) {
      typeMap[p.type] = (typeMap[p.type] ?? 0) + p.price;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),

        // ── Food & Drink ─────────────────────────────────────────────
        _sectionTitle('Food & Drink'),
        if (foodItems.isEmpty)
          const Text('No food & drink purchases',
              style: TextStyle(fontSize: 13, color: Colors.grey))
        else
          ...foodItems.map(_purchaseRow),
        const SizedBox(height: 8),
        _summaryLine('Total food & drink purchase', totalFoodDrink),
        _summaryLine(
          'Total food & drink budget left',
          totalFoodBudgetLeft,
          color: totalFoodBudgetLeft >= 0 ? Colors.green : Colors.red,
        ),

        // ── Other types ──────────────────────────────────────────────
        if (otherItems.isNotEmpty) ...[
          _sectionTitle('Other Purchases'),
          ...otherItems.map(_purchaseRow),
          const SizedBox(height: 8),
          ...typeMap.entries.map(
            (e) => _summaryLine('Total ${e.key}', e.value),
          ),
        ],

        // ── Grand total ──────────────────────────────────────────────
        const Divider(height: 24),
        _summaryLine('Grand Total', grandTotal,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DropdownButton<int>(
              value: _month,
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat.MMMM().format(DateTime(0, i + 1))))),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _month = v);
                _load();
              },
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
                value: _year,
                items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - 2 + i, child: Text('${DateTime.now().year - 2 + i}'))),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _year = v);
                  _load();
                })
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTable(),
                    _buildSpecialSection(),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

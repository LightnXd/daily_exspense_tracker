import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_entry.dart';
import '../models/grand_purchase.dart';
import '../models/purchase_type.dart';
import '../services/db_helper.dart';
import '../services/prefs.dart';
import '../utils/purchase_display.dart';
import '../utils/report_utils.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => ReportPageState();
}

class ReportPageState extends State<ReportPage> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  final _fmt = NumberFormat('#,##0.##', 'en_US');
  final _dateFmt = DateFormat('dd/MM');
  List<DailyEntry> _rows = [];
  List<GrandPurchase> _specialRows = [];
  List<PurchaseType> _purchaseTypes = [];
  final Set<String> _expandedTypes = {};

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

  Future<void> reload() => _load();

  Future<void> _load() async {
    final entries = await DBHelper().getEntriesForMonth(_year, _month);
    final special = await DBHelper().getGrandPurchasesForMonth(_year, _month);
    final types = await DBHelper().getAllPurchaseTypes();
    setState(() {
      _rows = entries;
      _specialRows = special;
      _purchaseTypes = types;
    });
  }

  Map<String, PurchaseType> get _typeByName {
    return {for (final t in _purchaseTypes) t.name: t};
  }

  Widget _buildTable() {
    final budget = PrefsService.dailyBudget.value;
    final report = computeMonthlyReport(_year, _month, _rows, budget);

    final daysWithSpending = report.days
        .where((d) =>
            d.breakfast != null ||
            d.lunch != null ||
            d.dinner != null ||
            d.snack != null)
        .toList();
    final hasSpending = daysWithSpending.isNotEmpty;

    final rows = hasSpending
        ? daysWithSpending.map((d) {
            return DataRow(cells: [
              DataCell(Text('${d.day}')),
              DataCell(Text(
                  d.breakfast == null ? '-' : _fmt.format(d.breakfast))),
              DataCell(Text(d.lunch == null ? '-' : _fmt.format(d.lunch))),
              DataCell(Text(d.dinner == null ? '-' : _fmt.format(d.dinner))),
              DataCell(Text(d.snack == null ? '-' : _fmt.format(d.snack))),
              DataCell(Text(_fmt.format(d.left))),
            ]);
          }).toList()
        : <DataRow>[];

    final meanRow = DataRow(cells: [
      const DataCell(Text('%')),
      DataCell(Text(report.meanBreakfast == null
          ? '-'
          : _fmt.format(report.meanBreakfast))),
      DataCell(Text(
          report.meanLunch == null ? '-' : _fmt.format(report.meanLunch))),
      DataCell(Text(
          report.meanDinner == null ? '-' : _fmt.format(report.meanDinner))),
      DataCell(Text(
          report.meanSnack == null ? '-' : _fmt.format(report.meanSnack))),
      DataCell(Text(
          report.meanLeft == null ? '-' : _fmt.format(report.meanLeft))),
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

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _summaryLine(String label, double value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              _fmt.format(value),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      );

  Widget _purchaseRow(GrandPurchase p) {
    final typeConfig = _typeByName[p.type];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(purchaseDisplayName(p, typeConfig),
                    style: const TextStyle(fontSize: 13)),
              ),
              Text(_fmt.format(p.price),
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 12),
              Text(_dateFmt.format(p.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 20),
            ],
          ),
          if (p.desc != null && p.desc!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Text(p.desc!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(PurchaseType type, List<GrandPurchase> items) {
    final total = items.fold<double>(0, (s, p) => s + p.price);
    final expanded = _expandedTypes.contains(type.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedTypes.remove(type.name);
              } else {
                _expandedTypes.add(type.name);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    type.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Text(
                  _fmt.format(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 24, bottom: 8),
              child: Text('No purchases',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            )
          else
            ...items.map(_purchaseRow),
        ],
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSpecialSection() {
    if (_specialRows.isEmpty && _purchaseTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    final budget = PrefsService.dailyBudget.value;
    final report = computeMonthlyReport(_year, _month, _rows, budget);

    final grouped = <String, List<GrandPurchase>>{};
    for (final p in _specialRows) {
      grouped.putIfAbsent(p.type, () => []).add(p);
    }
    for (final items in grouped.values) {
      items.sort((a, b) => a.date.compareTo(b.date));
    }

    final allSpecialTotal =
        _specialRows.fold<double>(0, (s, p) => s + p.price);
    final grandTotal = report.totalDailyFood + allSpecialTotal;

    final deductingTypes =
        _purchaseTypes.where((t) => t.deductFromBudget).toList();

    final categoriesWithPurchases = _purchaseTypes
        .where((t) => grouped.containsKey(t.name))
        .toList();

    final unknownTypes = grouped.keys
        .where((name) => !_typeByName.containsKey(name))
        .toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        _sectionTitle('Special Purchases'),

        if (_specialRows.isEmpty)
          const Text('No special purchases',
              style: TextStyle(fontSize: 13, color: Colors.grey))
        else ...[
          ...categoriesWithPurchases.map(
            (t) => _buildCategorySection(t, grouped[t.name]!),
          ),
          ...unknownTypes.map(
            (name) => _buildCategorySection(
              PurchaseType(name: name),
              grouped[name]!,
            ),
          ),
        ],

        if (deductingTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...deductingTypes.map((t) {
            final categoryTotal = (grouped[t.name] ?? [])
                .fold<double>(0, (s, p) => s + p.price);
            final budgetLeft = report.totalLeft - categoryTotal;
            return _summaryLine(
              'Total ${t.name} budget left',
              budgetLeft,
              color: budgetLeft >= 0 ? Colors.green : Colors.red,
            );
          }),
        ],

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
              items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                          DateFormat.MMMM().format(DateTime(0, i + 1))))),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _month = v);
                _load();
              },
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
                value: _year,
                items: List.generate(
                    5,
                    (i) => DropdownMenuItem(
                        value: DateTime.now().year - 2 + i,
                        child: Text('${DateTime.now().year - 2 + i}'))),
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

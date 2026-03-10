import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/daily_entry.dart';
import '../services/db_helper.dart';
import '../services/prefs.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _selected = DateTime.now();
  DailyEntry? _entry;
  final _fmt = NumberFormat('#,##0.##', 'en_US');
  final _controllers = {
    'breakfast': TextEditingController(),
    'lunch': TextEditingController(),
    'dinner': TextEditingController(),
    'snack': TextEditingController(),
  };
  final _focusNodes = {
    'breakfast': FocusNode(),
    'lunch': FocusNode(),
    'dinner': FocusNode(),
    'snack': FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    _loadFor(_selected);
    PrefsService.dailyBudget.addListener(_onBudgetChanged);
    _focusNodes.forEach((k, node) {
      node.addListener(() {
        if (!node.hasFocus) _formatController(k);
      });
    });
  }

  @override
  void dispose() {
    PrefsService.dailyBudget.removeListener(_onBudgetChanged);
    _controllers.values.forEach((c) => c.dispose());
    _focusNodes.values.forEach((n) => n.dispose());
    super.dispose();
  }

  void _onBudgetChanged() => setState(() {});

  Future<void> _loadFor(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    final e = await DBHelper().getEntry(d);
    setState(() {
      _selected = d;
      _entry = e;
      _controllers.forEach((k, c) {
        final val = _valueForKey(k);
        c.text = val == null ? '' : _fmt.format(val);
      });
    });
  }

  double? _valueForKey(String k) {
    if (_entry == null) return null;
    switch (k) {
      case 'breakfast':
        return _entry!.breakfast;
      case 'lunch':
        return _entry!.lunch;
      case 'dinner':
        return _entry!.dinner;
      case 'snack':
        return _entry!.snack;
    }
    return null;
  }

  Future<void> _save() async {
    final b = _parse(_controllers['breakfast']!.text);
    final l = _parse(_controllers['lunch']!.text);
    final d = _parse(_controllers['dinner']!.text);
    final s = _parse(_controllers['snack']!.text);
    final entry = DailyEntry(date: _selected, breakfast: b, lunch: l, dinner: d, snack: s);
    await DBHelper().upsertEntry(entry);
    setState(() => _entry = entry);
    _controllers.forEach((k, c) => _formatController(k));
  }

  void _formatController(String key) {
    final controller = _controllers[key]!;
    if (controller.text.trim().isEmpty) return;
    final v = double.tryParse(controller.text.replaceAll(',', ''));
    if (v != null) controller.text = _fmt.format(v);
  }

  double? _parse(String t) {
    if (t.trim().isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  Widget _numberInput(String key, String label) {
    final controller = _controllers[key]!;
    final focusNode = _focusNodes[key]!;
    final show = _valueForKey(key) != null || controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: InputDecoration(hintText: show ? null : '-'),
          onSubmitted: (_) {
            _formatController(key);
            _save();
          },
          onEditingComplete: () {
            _formatController(key);
            _save();
          },
        ),
      ],
    );
  }

  void _changeDate(int delta) => _loadFor(_selected.add(Duration(days: delta)));

  Future<void> _showBudgetDialog() async {
    final controller = TextEditingController(text: PrefsService.dailyBudget.value.toString());
    final res = await showDialog<int?>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Set daily budget'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      final v = int.tryParse(controller.text.replaceAll(',', '')) ?? PrefsService.dailyBudget.value;
                      Navigator.pop(context, v);
                    },
                    child: const Text('Save')),
              ],
            ));
    if (res != null) {
      await PrefsService.setDailyBudget(res);
      setState(() {});
    }
  }

  Future<void> _showSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Set daily budget'),
              onTap: () {
                Navigator.pop(context);
                _showBudgetDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export data (CSV)'),
              onTap: () async {
                Navigator.pop(context);
                await _exportData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import data (CSV)'),
              onTap: () async {
                Navigator.pop(context);
                await _importData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Bulk value change'),
              onTap: () async {
                Navigator.pop(context);
                await _showBulkChangeDialog();
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(
          start: DateTime(DateTime.now().year, DateTime.now().month, 1),
          end: DateTime.now(),
        ),
      );
      if (range == null || !mounted) return;

      final csvContent = await DBHelper().exportToCsvString(range.start, range.end);
      final from = DateFormat('yyyy-MM-dd').format(range.start);
      final to = DateFormat('yyyy-MM-dd').format(range.end);
      final fileName = 'expense_export_${from}_to_$to.csv';

      String? savePath;
      try {
        savePath = await FilePicker.platform.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
      } catch (_) {}

      if (savePath != null) {
        await File(savePath).writeAsString(csvContent);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to $savePath'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('\${dir.path}/\$fileName');
        await file.writeAsString(csvContent);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Export complete'),
              content: Text('Saved to:\n\${file.path}'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Share.shareXFiles([XFile(file.path)], text: 'Expense export');
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (res == null || res.files.isEmpty) return;
      final file = File(res.files.single.path!);
      final content = await file.readAsString();
      await DBHelper().importFromCsvString(content);
      await _loadFor(_selected);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Import complete'),
            content: const Text('Data imported successfully.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  Future<void> _showBulkChangeDialog() async {
    String operation = 'multiply';
    final numCtrl = TextEditingController();
    const ops = ['add', 'subtract', 'multiply', 'divide'];
    const opLabels = {
      'add': 'Add',
      'subtract': 'Subtract',
      'multiply': 'Multiply',
      'divide': 'Divide',
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bulk Value Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Applies to all daily entry and special purchase prices.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: operation,
                decoration: const InputDecoration(
                  labelText: 'Operation',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: ops
                    .map((op) => DropdownMenuItem(
                          value: op,
                          child: Text(opLabels[op]!),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => operation = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: numCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Value',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '* Warning: this will alter all existing price data. '
                'Results will be rounded to a maximum of 2 decimal places.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final val = double.tryParse(numCtrl.text);
                if (val == null) return;
                if (operation == 'divide' && val == 0) return;
                Navigator.pop(ctx);
                try {
                  await DBHelper().applyBulkChange(operation, val);
                  await _loadFor(_selected);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bulk change applied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Error'),
                        content: Text(e.toString()),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                      ),
                    );
                  }
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    numCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = PrefsService.dailyBudget.value;
    final spent = _entry?.sum() ?? 0;
    final left = budget - spent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6),
            onSelected: (m) => PrefsService.setThemeMode(m),
            itemBuilder: (_) => [
              const PopupMenuItem(value: ThemeMode.system, child: Text('System')),
              const PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
              const PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettingsDialog),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left)),
            Text(DateFormat.yMMMMd().format(_selected), style: const TextStyle(fontSize: 16)),
            IconButton(onPressed: () => _changeDate(1), icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 32),
          Text('Remaining: ${_fmt.format(left)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _numberInput('breakfast', 'Breakfast'),
                const SizedBox(height: 18),
                _numberInput('lunch', 'Lunch'),
                const SizedBox(height: 18),
                _numberInput('dinner', 'Dinner'),
                const SizedBox(height: 18),
                _numberInput('snack', 'Snack'),
                const SizedBox(height: 18),
                ElevatedButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          )
        ]),
      ),
    );
  }
}

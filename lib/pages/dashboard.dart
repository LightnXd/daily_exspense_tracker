import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  final _fmt = NumberFormat('#,##0', 'en_US');
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

  int? _valueForKey(String k) {
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
    final v = int.tryParse(controller.text.replaceAll(',', ''));
    if (v != null) controller.text = _fmt.format(v);
  }

  int? _parse(String t) {
    if (t.trim().isEmpty) return null;
    return int.tryParse(t.replaceAll(',', ''));
  }

  String _formatNullable(int? v) => v == null ? '-' : _fmt.format(v);

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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              title: const Text('Export data'),
              onTap: () async {
                Navigator.pop(context);
                await _exportData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import data'),
              onTap: () async {
                Navigator.pop(context);
                await _importData();
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
      final path = await DBHelper().exportToJsonFile();
      // Offer to share the file
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Export complete'),
          content: Text('Data exported to:\n$path'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Share.shareXFiles([XFile(path)], text: 'Daily expense export');
                },
                child: const Text('Share')),
          ],
        ),
      );
    } catch (e) {
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Error'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    }
  }

  Future<void> _importData() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any);
      if (res == null || res.files.isEmpty) return;
      final file = File(res.files.single.path!);
      final content = await file.readAsString();
      await DBHelper().importFromJsonString(content);
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Import complete'), content: const Text('Data imported successfully.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      await _loadFor(_selected);
    } catch (e) {
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Error'), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    }
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
          Text('Remaining: ${NumberFormat('#,##0', 'en_US').format(left)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

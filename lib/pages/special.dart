import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/grand_purchase.dart';
import '../services/db_helper.dart';

const List<String> kPurchaseTypes = [
  'food&drink',
  'sanitation',
  'transport',
  'event',
  'furniture',
  'games',
  'extra',
];

class SpecialPage extends StatefulWidget {
  const SpecialPage({Key? key}) : super(key: key);

  @override
  State<SpecialPage> createState() => _SpecialPageState();
}

class _SpecialPageState extends State<SpecialPage> {
  final _formKey = GlobalKey<FormState>();
  String _type = kPurchaseTypes.first;
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  List<GrandPurchase> _purchases = [];
  final _fmt = NumberFormat('#,##0', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    final list = await DBHelper().getAllGrandPurchases();
    if (mounted) setState(() => _purchases = list);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final purchase = GrandPurchase(
      type: _type,
      name: _nameCtrl.text.trim(),
      color: (_type == 'sanitation' && _colorCtrl.text.trim().isNotEmpty)
          ? _colorCtrl.text.trim()
          : null,
      price: int.parse(_priceCtrl.text.replaceAll(',', '')),
      date: _date,
      desc: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    await DBHelper().insertGrandPurchase(purchase);
    _formKey.currentState!.reset();
    _nameCtrl.clear();
    _colorCtrl.clear();
    _priceCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _type = kPurchaseTypes.first;
      _date = DateTime.now();
      _saving = false;
    });
    await _loadList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _delete(GrandPurchase p) async {
    if (p.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${p.displayName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper().deleteGrandPurchase(p.id!);
      await _loadList();
    }
  }

  Widget _row(String label, Widget input) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: input),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSanitation = _type == 'sanitation';

    return Scaffold(
      appBar: AppBar(title: const Text('Special Purchase')),
      body: Column(
        children: [
          // ── Form ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Type
                  _row(
                    'Type',
                    DropdownButtonFormField<String>(
                      value: _type,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: kPurchaseTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                  ),
                  // Name
                  _row(
                    'Name',
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Insert name',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  // Color (sanitation only)
                  if (isSanitation)
                    _row(
                      'Color',
                      TextFormField(
                        controller: _colorCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. blue, red',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  // Price
                  _row(
                    'Price',
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '0',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  // Date
                  _row(
                    'Date',
                    OutlinedButton(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(_dateFmt.format(_date)),
                    ),
                  ),
                  // Desc
                  _row(
                    'Desc',
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _purchases.isEmpty
                ? const Center(child: Text('No entries yet'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _purchases.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = _purchases[i];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        title: Text(
                          '${p.displayName}  •  ${_fmt.format(p.price)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.type}  •  ${_dateFmt.format(p.date)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (p.desc != null && p.desc!.isNotEmpty)
                              Text(
                                p.desc!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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

  int _filterYear = DateTime.now().year;
  int _filterMonth = DateTime.now().month;

  String _sortField = 'date';
  bool _sortAscending = false; // default date desc

  List<GrandPurchase> _purchases = [];
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final _fmt = NumberFormat('#,##0.##', 'en_US');
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
    _searchCtrl.dispose();
    super.dispose();
  }

  void _sortPurchases() {
    _purchases.sort((a, b) {
      int cmp;
      if (_sortField == 'price') {
        cmp = a.price.compareTo(b.price);
      } else if (_sortField == 'alphabet') {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        cmp = a.date.compareTo(b.date);
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  Future<void> _loadList() async {
    final list = await DBHelper().getGrandPurchasesForMonth(_filterYear, _filterMonth);
    if (mounted) {
      setState(() {
        _purchases = list;
        _sortPurchases();
      });
    }
  }

  void _onSortSelected(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = false; // start desc on new field
      }
      _sortPurchases();
    });
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
      price: double.parse(_priceCtrl.text.replaceAll(',', '')),
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

  Future<void> _edit(GrandPurchase p) async {
    if (p.id == null) return;

    final formKey = GlobalKey<FormState>();
    String type = p.type;
    final nameCtrl = TextEditingController(text: p.name);
    final colorCtrl = TextEditingController(text: p.color ?? '');
    final priceCtrl = TextEditingController(text: p.price.toString());
    DateTime newDate = p.date;
    final descCtrl = TextEditingController(text: p.desc ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          final isSanitation = type == 'sanitation';

          return AlertDialog(
            title: const Text('Edit Purchase'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: kPurchaseTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => type = v);
                      },
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    if (isSanitation)
                      TextFormField(
                        controller: colorCtrl,
                        decoration: const InputDecoration(labelText: 'Color'),
                      ),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.replaceAll(',', '')) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: newDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => newDate = picked);
                      },
                      child: Text(_dateFmt.format(newDate)),
                    ),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Desc (optional)'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final updated = GrandPurchase(
                    id: p.id,
                    type: type,
                    name: nameCtrl.text.trim(),
                    color: (type == 'sanitation' && colorCtrl.text.trim().isNotEmpty)
                        ? colorCtrl.text.trim()
                        : null,
                    price: double.parse(priceCtrl.text.trim().replaceAll(',', '')),
                    date: newDate,
                    desc: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  );
                  await DBHelper().updateGrandPurchase(updated);
                  Navigator.pop(ctx);
                  await _loadList();
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
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
      appBar: AppBar(
        title: const Text('Special Purchase'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _onSortSelected,
            itemBuilder: (ctx) {
              final entries = [
                'date',
                'price',
                'alphabet',
              ];
              return entries.map((key) {
                final label = key == 'date'
                    ? 'Date'
                    : key == 'price'
                        ? 'Price'
                        : 'Alphabet';
                final selected = key == _sortField;
                final icon = selected
                    ? Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                      )
                    : null;
                return PopupMenuItem<String>(
                  value: key,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label),
                      if (icon != null) icon,
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Filter row ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  DropdownButton<int>(
                    value: _filterMonth,
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(DateFormat.MMMM().format(DateTime(0, i + 1))),
                      ),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filterMonth = v);
                      _loadList();
                    },
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _filterYear,
                    items: List.generate(
                        5,
                        (i) => DropdownMenuItem(
                            value: DateTime.now().year - 2 + i,
                            child: Text('${DateTime.now().year - 2 + i}'))),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filterYear = v);
                      _loadList();
                    },
                  ),
                  const Spacer(),
                  Text(
                    'Sort: ${_sortField[0].toUpperCase()}${_sortField.substring(1)} ${_sortAscending ? '↑' : '↓'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          // ── Form ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        decoration: const InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.replaceAll(',', '')) == null) return 'Invalid number';
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
          ),
          const SliverToBoxAdapter(child: Divider(height: 24)),
          // ── Search bar ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              ),
            ),
          ),
          // ── List ──────────────────────────────────────────────────────
          Builder(builder: (context) {
            final filtered = _purchases
                .where((p) =>
                    _searchQuery.isEmpty ||
                    p.name.toLowerCase().contains(_searchQuery))
                .toList();

            if (filtered.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No entries')),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  if (i.isOdd) return const Divider(height: 1);
                  final p = filtered[i ~/ 2];
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                                fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _edit(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(p),
                        ),
                      ],
                    ),
                  );
                },
                childCount: filtered.length * 2 - 1,
              ),
            );
          }),
        ],
      ),
    );
  }
}
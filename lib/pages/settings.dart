import 'package:flutter/material.dart';
import '../models/purchase_type.dart';
import '../services/db_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<PurchaseType> _types = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await DBHelper().getAllPurchaseTypes();
    if (mounted) {
      setState(() {
        _types = types;
        _loading = false;
      });
    }
  }

  Future<void> _showTypeDialog({PurchaseType? existing}) async {
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (ctx) => _CategoryFormDialog(
        existing: existing,
        existingTypes: _types,
      ),
    );
    if (result == null || !mounted) return;

    try {
      if (existing != null) {
        await DBHelper().updatePurchaseType(
          PurchaseType(
            id: existing.id,
            name: result.name,
            useColor: result.useColor,
            deductFromBudget: result.deductFromBudget,
            sortOrder: existing.sortOrder,
          ),
        );
      } else {
        final maxOrder = _types.isEmpty
            ? 0
            : _types.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
        await DBHelper().insertPurchaseType(
          PurchaseType(
            name: result.name,
            useColor: result.useColor,
            deductFromBudget: result.deductFromBudget,
            sortOrder: maxOrder,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _flagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTypeDialog(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _types.isEmpty
              ? const Center(child: Text('No categories yet'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final t = _types[i];
                    return ListTile(
                      title: Text(t.name),
                      subtitle: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (t.useColor)
                            _flagChip('Color', Colors.blue),
                          if (t.deductFromBudget)
                            _flagChip('Budget', Colors.orange),
                        ],
                      ),
                      trailing: const Icon(Icons.edit, size: 20),
                      onTap: () => _showTypeDialog(existing: t),
                    );
                  },
                ),
    );
  }
}

class _CategoryFormResult {
  final String name;
  final bool useColor;
  final bool deductFromBudget;

  _CategoryFormResult({
    required this.name,
    required this.useColor,
    required this.deductFromBudget,
  });
}

class _CategoryFormDialog extends StatefulWidget {
  final PurchaseType? existing;
  final List<PurchaseType> existingTypes;

  const _CategoryFormDialog({
    required this.existing,
    required this.existingTypes,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late bool _useColor;
  late bool _deductFromBudget;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _useColor = widget.existing?.useColor ?? false;
    _deductFromBudget = widget.existing?.deductFromBudget ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final duplicate = widget.existingTypes.any((t) =>
        t.name.toLowerCase() == name.toLowerCase() &&
        t.id != widget.existing?.id);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A category with this name already exists'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _CategoryFormResult(
        name: name,
        useColor: _useColor,
        deductFromBudget: _deductFromBudget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Category' : 'Add Category'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use color field'),
                subtitle: const Text(
                  'Show a color input when adding purchases of this type',
                  style: TextStyle(fontSize: 12),
                ),
                value: _useColor,
                onChanged: (v) => setState(() => _useColor = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deduct from budget'),
                subtitle: const Text(
                  'Purchases in this category reduce the monthly food budget left',
                  style: TextStyle(fontSize: 12),
                ),
                value: _deductFromBudget,
                onChanged: (v) =>
                    setState(() => _deductFromBudget = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

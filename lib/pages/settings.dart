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
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var useColor = existing?.useColor ?? false;
    var deductFromBudget = existing?.deductFromBudget ?? false;
    final isEdit = existing != null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Category' : 'Add Category'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
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
                        value: useColor,
                        onChanged: (v) =>
                            setDialogState(() => useColor = v ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Deduct from budget'),
                        subtitle: const Text(
                          'Purchases in this category reduce the monthly food budget left',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: deductFromBudget,
                        onChanged: (v) => setDialogState(
                            () => deductFromBudget = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final name = nameCtrl.text.trim();
                    final duplicate = _types.any((t) =>
                        t.name.toLowerCase() == name.toLowerCase() &&
                        t.id != existing?.id);
                    if (duplicate) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('A category with this name already exists'),
                        ),
                      );
                      return;
                    }

                    try {
                      if (isEdit) {
                        await DBHelper().updatePurchaseType(
                          PurchaseType(
                            id: existing.id,
                            name: name,
                            useColor: useColor,
                            deductFromBudget: deductFromBudget,
                            sortOrder: existing.sortOrder,
                          ),
                        );
                      } else {
                        final maxOrder = _types.isEmpty
                            ? 0
                            : _types
                                    .map((t) => t.sortOrder)
                                    .reduce((a, b) => a > b ? a : b) +
                                1;
                        await DBHelper().insertPurchaseType(
                          PurchaseType(
                            name: name,
                            useColor: useColor,
                            deductFromBudget: deductFromBudget,
                            sortOrder: maxOrder,
                          ),
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: Text(isEdit ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/formatters.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _batchController = TextEditingController();
  final _supplierController = TextEditingController();
  final _wattageController = TextEditingController(text: '540');
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '11500');
  final _serialsController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _batchController.dispose();
    _supplierController.dispose();
    _wattageController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _serialsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> get _parsedSerials =>
      Formatters.parseSerials(_serialsController.text);

  int get _enteredCount => _parsedSerials.length;

  int get _expectedQuantity => int.tryParse(_quantityController.text) ?? 0;

  bool get _hasDuplicates {
    final list = _parsedSerials.map((s) => s.toUpperCase()).toList();
    return list.toSet().length != list.length;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_enteredCount != _expectedQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Entered $_enteredCount serial(s), but quantity is $_expectedQuantity.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_hasDuplicates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duplicate serial numbers detected in your entry.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final wattage = int.parse(_wattageController.text);
      await context.read<PurchaseProvider>().addPurchase(
            purchaseDate: _purchaseDate,
            supplierName: _supplierController.text.trim().isEmpty
                ? null
                : _supplierController.text.trim(),
            batchNumber: _batchController.text.trim(),
            wattage: wattage,
            quantity: _expectedQuantity,
            serialNumbers: _parsedSerials,
            unitPurchasePrice: double.parse(_priceController.text),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      // Refresh dashboard and inventory
      if (mounted) {
        context.read<DashboardProvider>().loadDashboard();
        context.read<InventoryProvider>().loadPanels();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Batch recorded! ${_parsedSerials.length} panels of ${wattage}W added to inventory.'),
            backgroundColor: AppColors.solarGreenDark,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Inward Purchase'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date Picker Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today,
                    color: AppColors.primaryBlue),
                title: const Text('Purchase Date',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                subtitle: Text(
                  Formatters.formatDate(_purchaseDate),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _purchaseDate = picked);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            // Batch & Supplier
            TextFormField(
              controller: _batchController,
              decoration: const InputDecoration(
                labelText: 'Batch Number *',
                hintText: 'e.g. BATCH-540-K2',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Batch number is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier Name (Optional)',
                hintText: 'e.g. Tata Power Solar Systems',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 12),

            // Wattage & Quantity
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _wattageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wattage (W) *',
                      hintText: '540',
                      suffixText: 'W',
                    ),
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (pcs) *',
                      hintText: '1',
                      suffixText: 'panels',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Purchase Price (₹) *',
                hintText: '11500',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val < 0) return 'Must be ≥ 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Serial Numbers Entry Box
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Panel Serial Numbers *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _enteredCount == _expectedQuantity
                                ? AppColors.solarGreenLight
                                : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$_enteredCount of $_expectedQuantity serials',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _enteredCount == _expectedQuantity
                                  ? AppColors.solarGreenDark
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _serialsController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Paste panel serial numbers separated by comma, space or new line...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_hasDuplicates) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Warning: Duplicate serials found in input list.',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Each physical panel is tracked individually by serial in inventory.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'e.g. Invoice #2024-TATA-88',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.solarAmber,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Save Inward Purchase & Create Stock',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

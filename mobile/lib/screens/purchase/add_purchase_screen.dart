import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/formatters.dart';
import 'barcode_scanner_screen.dart';

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
  final _singleSerialController = TextEditingController();
  final _notesController = TextEditingController();
  final _serialFocusNode = FocusNode();

  DateTime _purchaseDate = DateTime.now();
  bool _isSubmitting = false;

  // List of entered/scanned serial numbers
  final List<String> _serials = [];

  // Toggle for bulk paste mode
  bool _isBulkPasteMode = false;
  final _bulkPasteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadPanels();
    });
  }

  @override
  void dispose() {
    _batchController.dispose();
    _supplierController.dispose();
    _wattageController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _singleSerialController.dispose();
    _notesController.dispose();
    _bulkPasteController.dispose();
    _serialFocusNode.dispose();
    super.dispose();
  }

  int get _enteredCount => _serials.length;

  int get _expectedQuantity => int.tryParse(_quantityController.text) ?? 0;

  Set<String> get _existingInventorySerials {
    final inv = context.read<InventoryProvider>();
    return inv.allPanels.map((p) => p.serialNumber.toUpperCase()).toSet();
  }

  /// Duplicates within the current entered serials list
  List<String> get _duplicateSerialsInEntry {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final s in _serials) {
      final normalized = s.toUpperCase();
      if (seen.contains(normalized)) {
        duplicates.add(normalized);
      } else {
        seen.add(normalized);
      }
    }
    return duplicates.toList();
  }

  /// Serials that conflict with existing database stock
  List<String> get _conflictsWithInventory {
    final invSet = _existingInventorySerials;
    return _serials
        .where((s) => invSet.contains(s.toUpperCase()))
        .map((s) => s.toUpperCase())
        .toSet()
        .toList();
  }

  bool get _hasDuplicates => _duplicateSerialsInEntry.isNotEmpty;

  void _addSingleSerial(String raw) {
    final serial = raw.trim().toUpperCase();
    if (serial.isEmpty) return;

    // Check duplicate in current batch
    if (_serials.any((s) => s.toUpperCase() == serial)) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicate serial: "$serial" is already in this batch.'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check duplicate in inventory
    if (_existingInventorySerials.contains(serial)) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conflict: "$serial" already exists in inventory.'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Add to list
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() {
      _serials.add(serial);
      _singleSerialController.clear();
      // Auto-update quantity if current quantity is 1 and we are scanning multiple, or if exceeded
      if (_serials.length > _expectedQuantity) {
        _quantityController.text = _serials.length.toString();
      }
    });

    _serialFocusNode.requestFocus();
  }

  void _editSerial(int index) {
    if (index < 0 || index >= _serials.length) return;
    final current = _serials[index];
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Serial #${index + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Serial Number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newSerial = controller.text.trim().toUpperCase();
              if (newSerial.isEmpty) return;

              // Check if duplicate of any OTHER item
              final isDuplicate = _serials.asMap().entries.any(
                    (entry) =>
                        entry.key != index &&
                        entry.value.toUpperCase() == newSerial,
                  );

              if (isDuplicate) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Serial "$newSerial" already exists in this batch.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              // Check existing inventory
              if (_existingInventorySerials.contains(newSerial)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Serial "$newSerial" already exists in inventory.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              setState(() {
                _serials[index] = newSerial;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeSerial(int index) {
    if (index >= 0 && index < _serials.length) {
      setState(() {
        _serials.removeAt(index);
      });
    }
  }

  void _openCameraScanner() async {
    final scannedResults = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (ctx) => BarcodeScannerScreen(
          targetQuantity: _expectedQuantity > 0 ? _expectedQuantity : 1,
          initialSerials: _serials,
          existingInventorySerials: _existingInventorySerials,
          batchNumber: _batchController.text.trim(),
        ),
      ),
    );

    if (scannedResults != null && mounted) {
      setState(() {
        _serials.clear();
        _serials.addAll(scannedResults);
        if (_serials.length > _expectedQuantity) {
          _quantityController.text = _serials.length.toString();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_serials.length} serial numbers registered from scanner.'),
          backgroundColor: AppColors.solarGreenDark,
        ),
      );
    }
  }

  void _applyBulkPaste() {
    final parsed = Formatters.parseSerials(_bulkPasteController.text);
    if (parsed.isEmpty) return;

    final added = <String>[];
    final duplicates = <String>[];
    final conflicts = <String>[];

    for (final raw in parsed) {
      final s = raw.trim().toUpperCase();
      if (_serials.any((existing) => existing.toUpperCase() == s)) {
        duplicates.add(s);
      } else if (_existingInventorySerials.contains(s)) {
        conflicts.add(s);
      } else {
        _serials.add(s);
        added.add(s);
      }
    }

    setState(() {
      if (_serials.length > _expectedQuantity) {
        _quantityController.text = _serials.length.toString();
      }
      _bulkPasteController.clear();
      _isBulkPasteMode = false;
    });

    String msg = 'Added ${added.length} serials.';
    if (duplicates.isNotEmpty) {
      msg += ' Skipped ${duplicates.length} duplicates.';
    }
    if (conflicts.isNotEmpty) {
      msg += ' Skipped ${conflicts.length} inventory conflicts.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: added.isNotEmpty ? AppColors.solarGreenDark : AppColors.danger,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_enteredCount != _expectedQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Entered $_enteredCount serial(s), but quantity is $_expectedQuantity. Please match the count.'),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Set Qty to $_enteredCount',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _quantityController.text = _enteredCount.toString();
              });
            },
          ),
        ),
      );
      return;
    }

    if (_hasDuplicates) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Duplicate serial numbers in entry: ${_duplicateSerialsInEntry.join(", ")}'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_conflictsWithInventory.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Serials already exist in inventory: ${_conflictsWithInventory.join(", ")}'),
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
            serialNumbers: _serials,
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
                'Batch recorded! ${_serials.length} panels of ${wattage}W added to inventory.'),
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
    final countMatch = _enteredCount == _expectedQuantity;

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

            // Serial Numbers Section with Barcode Scanner
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: countMatch
                      ? AppColors.solarGreen.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with count badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.barcode_reader,
                                size: 20, color: AppColors.primaryBlue),
                            SizedBox(width: 6),
                            Text(
                              'Panel Serial Numbers',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: countMatch
                                ? AppColors.solarGreenLight
                                : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: countMatch
                                  ? AppColors.solarGreenDark.withValues(alpha: 0.3)
                                  : AppColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$_enteredCount of $_expectedQuantity serials',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: countMatch
                                  ? AppColors.solarGreenDark
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Barcode Scanner Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _openCameraScanner,
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            label: const Text(
                              'Scan with Camera',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMain,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isBulkPasteMode = !_isBulkPasteMode;
                              });
                            },
                            icon: Icon(
                              _isBulkPasteMode ? Icons.close : Icons.paste,
                              size: 18,
                            ),
                            label: Text(
                              _isBulkPasteMode ? 'Close' : 'Bulk Paste',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Bulk Paste View
                    if (_isBulkPasteMode) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Paste multiple serials (comma, space or newline separated):',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _bulkPasteController,
                              maxLines: 3,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'HZ-540-001, HZ-540-002, HZ-540-003...',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.solarAmber,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _applyBulkPaste,
                              icon: const Icon(Icons.add_task, size: 16),
                              label: const Text('Parse & Add Serials'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Fast Input for Typing & Hardware / USB Barcode Scanner
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _singleSerialController,
                            focusNode: _serialFocusNode,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type or scan with hardware scanner...',
                              prefixIcon: const Icon(Icons.keyboard_outlined, size: 20),
                              suffixIcon: _singleSerialController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _singleSerialController.clear();
                                        });
                                      },
                                    )
                                  : null,
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: _addSingleSerial,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.solarGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _singleSerialController.text.trim().isEmpty
                              ? null
                              : () => _addSingleSerial(
                                  _singleSerialController.text),
                          child: const Text('Add'),
                        ),
                      ],
                    ),

                    // Duplicates and Conflicts Warnings
                    if (_hasDuplicates) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Duplicates in entry: ${_duplicateSerialsInEntry.join(", ")}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                // Keep only unique serials
                                final unique = <String>[];
                                for (final s in _serials) {
                                  if (!unique.any(
                                      (u) => u.toUpperCase() == s.toUpperCase())) {
                                    unique.add(s);
                                  }
                                }
                                setState(() {
                                  _serials.clear();
                                  _serials.addAll(unique);
                                });
                              },
                              child: const Text(
                                'Fix',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_conflictsWithInventory.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Already exists in inventory: ${_conflictsWithInventory.join(", ")}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Quantity Mismatch Notice & Auto-Sync
                    if (_enteredCount != _expectedQuantity && _enteredCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _enteredCount < _expectedQuantity
                                    ? 'Need ${_expectedQuantity - _enteredCount} more panel serial(s).'
                                    : '$_enteredCount serials entered for quantity $_expectedQuantity.',
                                style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setState(() {
                                  _quantityController.text = _enteredCount.toString();
                                });
                              },
                              child: Text(
                                'Set Qty to $_enteredCount',
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Serials List Header with Clear All
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Scanned / Entered Panels (${_serials.length}):',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_serials.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _serials.clear();
                              });
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Scanned Panels List (Scrollable box with individual edit & delete)
                    if (_serials.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.qr_code_scanner,
                                size: 36, color: AppColors.textMuted),
                            SizedBox(height: 6),
                            Text(
                              'No serial numbers added yet',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Use "Scan with Camera", type above, or use a handheld scanner',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _serials.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AppColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final sn = _serials[index];
                            final isDuplicate = _serials
                                    .where((s) => s.toUpperCase() == sn.toUpperCase())
                                    .length >
                                1;
                            final isConflict =
                                _existingInventorySerials.contains(sn.toUpperCase());

                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: isConflict || isDuplicate
                                    ? AppColors.dangerLight
                                    : AppColors.primaryBlueLight,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isConflict || isDuplicate
                                        ? AppColors.danger
                                        : AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                              title: Text(
                                sn,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isConflict || isDuplicate
                                      ? AppColors.danger
                                      : AppColors.textMain,
                                ),
                              ),
                              subtitle: (isConflict || isDuplicate)
                                  ? Text(
                                      isConflict
                                          ? 'Already in inventory'
                                          : 'Duplicate in batch',
                                      style: const TextStyle(
                                          fontSize: 10, color: AppColors.danger),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    color: AppColors.primaryBlue,
                                    tooltip: 'Edit Serial',
                                    onPressed: () => _editSerial(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    color: AppColors.danger,
                                    tooltip: 'Remove',
                                    onPressed: () => _removeSerial(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/panel_item.dart';
import '../../models/purchase.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirmation_dialog.dart';
import 'barcode_scanner_screen.dart';

class EditPurchaseScreen extends StatefulWidget {
  final PurchaseTransaction purchase;

  const EditPurchaseScreen({super.key, required this.purchase});

  @override
  State<EditPurchaseScreen> createState() => _EditPurchaseScreenState();
}

class _EditPurchaseScreenState extends State<EditPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _batchController;
  late final TextEditingController _supplierController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  final _quickSerialController = TextEditingController();
  final _searchSerialController = TextEditingController();

  late DateTime _purchaseDate;
  late String _selectedType;
  late List<String> _serials;
  final Map<String, PanelStatus> _panelStatuses = {};
  bool _isLoadingPanels = true;
  bool _isSaving = false;
  String _serialFilter = '';

  @override
  void initState() {
    super.initState();
    _batchController = TextEditingController(text: widget.purchase.batchNumber);
    _supplierController =
        TextEditingController(text: widget.purchase.supplierName ?? '');
    _priceController = TextEditingController(
        text: widget.purchase.unitPurchasePrice.toStringAsFixed(0));
    _notesController = TextEditingController(text: widget.purchase.notes ?? '');
    _purchaseDate = widget.purchase.purchaseDate;
    _selectedType = widget.purchase.type;
    _serials = List<String>.from(widget.purchase.serialNumbers);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPanelStatuses();
    });
  }

  @override
  void dispose() {
    _batchController.dispose();
    _supplierController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _quickSerialController.dispose();
    _searchSerialController.dispose();
    super.dispose();
  }

  Future<void> _loadPanelStatuses() async {
    try {
      final inv = context.read<InventoryProvider>();
      await inv.loadPanels();
      final map = <String, PanelStatus>{};
      for (final p in inv.allPanels) {
        map[p.serialNumber.toUpperCase()] = p.status;
      }
      if (mounted) {
        setState(() {
          _panelStatuses.clear();
          _panelStatuses.addAll(map);
          _isLoadingPanels = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPanels = false);
    }
  }

  Set<String> get _inventoryOtherSerials {
    final inv = context.read<InventoryProvider>();
    final originalBatchSerials =
        widget.purchase.serialNumbers.map((s) => s.toUpperCase()).toSet();
    return inv.allPanels
        .map((p) => p.serialNumber.toUpperCase())
        .where((s) => !originalBatchSerials.contains(s))
        .toSet();
  }

  double get _currentPrice => double.tryParse(_priceController.text) ?? 0.0;
  double get _totalAmount => _serials.length * _currentPrice;

  List<String> get _filteredSerials {
    if (_serialFilter.trim().isEmpty) return _serials;
    final q = _serialFilter.trim().toUpperCase();
    return _serials.where((s) => s.toUpperCase().contains(q)).toList();
  }

  void _addSerial(String raw) {
    final sn = raw.trim().toUpperCase();
    if (sn.isEmpty) return;

    if (_serials.any((s) => s.toUpperCase() == sn)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Serial "$sn" is already in this batch.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_inventoryOtherSerials.contains(sn)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Serial "$sn" already exists in another inventory batch.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _serials.add(sn);
      _quickSerialController.clear();
    });
  }

  void _openAddPanelsBottomSheet() {
    final bulkController = TextEditingController();
    final singleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppColors.solarAmber, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Add Panels to Batch',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Batch: ${_batchController.text.trim()} (${widget.purchase.wattage}W)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Divider(height: 24),

                    // Barcode scan quick launcher button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.primaryBlue),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan with Camera Scanner',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final scanned = await Navigator.of(context).push<List<String>>(
                          MaterialPageRoute(
                            builder: (_) => BarcodeScannerScreen(
                              targetQuantity: 1000,
                              initialSerials: _serials,
                              existingInventorySerials: _inventoryOtherSerials,
                              batchNumber: _batchController.text.trim(),
                            ),
                          ),
                        );
                        if (scanned != null && mounted) {
                          setState(() {
                            for (final sn in scanned) {
                              final upper = sn.trim().toUpperCase();
                              if (!_serials.any((s) => s.toUpperCase() == upper)) {
                                _serials.add(upper);
                              }
                            }
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Single entry row
                    const Text('Enter Single Serial Number',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: singleController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'e.g. SL540-100234',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (val) {
                              final sn = val.trim().toUpperCase();
                              if (sn.isNotEmpty) {
                                _addSerial(sn);
                                singleController.clear();
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            final sn = singleController.text.trim().toUpperCase();
                            if (sn.isNotEmpty) {
                              _addSerial(sn);
                              singleController.clear();
                              setModalState(() {});
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Bulk paste textarea
                    const Text('Or Paste Multiple Serial Numbers',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain)),
                    const SizedBox(height: 4),
                    const Text(
                      'Paste from Excel/WhatsApp/Notepad separated by newlines or commas.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bulkController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'SN001\nSN002\nSN003...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.solarAmber,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      label: const Text('Import Pasted Serials',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () {
                        final raw = bulkController.text;
                        final tokens = raw
                            .split(RegExp(r'[\n,\r\t;]+'))
                            .map((s) => s.trim().toUpperCase())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        int addedCount = 0;
                        int dupeCount = 0;
                        int conflictCount = 0;

                        for (final t in tokens) {
                          if (_serials.any((s) => s.toUpperCase() == t)) {
                            dupeCount++;
                            continue;
                          }
                          if (_inventoryOtherSerials.contains(t)) {
                            conflictCount++;
                            continue;
                          }
                          _serials.add(t);
                          addedCount++;
                        }

                        setState(() {});
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Imported $addedCount panel(s).'
                              '${dupeCount > 0 ? ' ($dupeCount duplicate(s) skipped)' : ''}'
                              '${conflictCount > 0 ? ' ($conflictCount existing stock skipped)' : ''}',
                            ),
                            backgroundColor: AppColors.solarGreenDark,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editSingleSerial(String oldSerial) async {
    final editController = TextEditingController(text: oldSerial);
    final isSold = _panelStatuses[oldSerial.toUpperCase()] == PanelStatus.sold;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Panel Serial Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSold) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.solarAmberLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.solarAmber),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: This panel is marked as SOLD. Updating its serial will also update the linked customer sale record.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: editController,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Serial Number',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newSn = editController.text.trim().toUpperCase();
                if (newSn.isEmpty) return;
                Navigator.pop(ctx, newSn);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != oldSerial) {
      if (_serials.any((s) => s.toUpperCase() == result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Serial "$result" already exists in this batch.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
      if (_inventoryOtherSerials.contains(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Serial "$result" already exists in inventory.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      setState(() {
        final idx = _serials.indexOf(oldSerial);
        if (idx != -1) {
          _serials[idx] = result;
          final status = _panelStatuses.remove(oldSerial.toUpperCase());
          if (status != null) {
            _panelStatuses[result] = status;
          }
        }
      });
    }
  }

  void _deleteSingleSerial(String serial) {
    final isSold = _panelStatuses[serial.toUpperCase()] == PanelStatus.sold;
    if (isSold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot remove "$serial". It has already been sold/dispatched to a customer.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_serials.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A batch purchase must have at least one serial number.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _serials.remove(serial);
      _panelStatuses.remove(serial.toUpperCase());
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one panel serial number is required.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final purchaseProvider = context.read<PurchaseProvider>();
      final batch = _batchController.text.trim();
      final supplier = _supplierController.text.trim();
      final price = double.parse(_priceController.text);
      final notes = _notesController.text.trim();

      await purchaseProvider.updatePurchase(
        id: widget.purchase.id,
        purchaseDate: _purchaseDate,
        supplierName: supplier.isEmpty ? null : supplier,
        batchNumber: batch,
        type: _selectedType,
        unitPurchasePrice: price,
        notes: notes.isEmpty ? null : notes,
        serialNumbers: _serials,
      );

      if (mounted) {
        context.read<DashboardProvider>().loadDashboard();
        context.read<InventoryProvider>().loadPanels();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch "$batch" updated successfully (${_serials.length} panels).'),
            backgroundColor: AppColors.solarGreenDark,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSerials;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Batch: ${widget.purchase.batchNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete Entire Purchase',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Delete Batch "${widget.purchase.batchNumber}"?',
                message:
                    'This will remove this inward shipment and its unsold inventory panels. This action cannot be undone.',
                confirmText: 'Delete Batch',
                isDestructive: true,
              );
              if (confirmed && context.mounted) {
                try {
                  await context
                      .read<PurchaseProvider>()
                      .deletePurchase(widget.purchase.id);
                  if (context.mounted) {
                    context.read<DashboardProvider>().loadDashboard();
                    context.read<InventoryProvider>().loadPanels();
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Batch Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Batch Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Batch Number
                    TextFormField(
                      controller: _batchController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Batch Number *',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Batch number is required'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Supplier Name
                    TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier / Manufacturer',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Panel Type & Wattage
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Panel Type *',
                              prefixIcon: Icon(Icons.solar_power),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'DCR',
                                child: Text('DCR'),
                              ),
                              DropdownMenuItem(
                                value: 'Non DCR',
                                child: Text('Non DCR'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedType = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Wattage',
                              prefixIcon: Icon(Icons.bolt_outlined),
                            ),
                            child: Text(
                              '${widget.purchase.wattage} W',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date & Price row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
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
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Purchase Date',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                Formatters.formatDate(_purchaseDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Unit Price (₹) *',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final p = double.tryParse(v);
                              if (p == null || p < 0) return 'Invalid price';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Remarks',
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Panels Management Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panels in Batch',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              '${_serials.length} registered panel units',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.solarAmber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('+ Add Panels',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          onPressed: _openAddPanelsBottomSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick add textfield
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quickSerialController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Quick add serial & hit Enter',
                              isDense: true,
                              prefixIcon: const Icon(Icons.qr_code, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (v) => _addSerial(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                          ),
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () =>
                              _addSerial(_quickSerialController.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search within batch
                    if (_serials.length > 5) ...[
                      TextField(
                        controller: _searchSerialController,
                        decoration: InputDecoration(
                          hintText: 'Filter serial numbers...',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (v) => setState(() => _serialFilter = v),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const Divider(height: 1),

                    // Panels list
                    if (_isLoadingPanels)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No serials match search query.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final sn = filtered[index];
                          final status = _panelStatuses[sn.toUpperCase()] ??
                              PanelStatus.available;
                          final isSold = status == PanelStatus.sold;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primaryBlueLight,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sn,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSold
                                        ? AppColors.solarAmberLight
                                        : AppColors.solarGreenLight,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSold
                                          ? AppColors.solarAmber
                                          : AppColors.solarGreenDark,
                                    ),
                                  ),
                                  child: Text(
                                    isSold ? 'Sold' : 'Available',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSold
                                          ? const Color(0xFFB45309)
                                          : AppColors.solarGreenDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: AppColors.primaryBlue),
                                  tooltip: 'Edit serial number',
                                  onPressed: () => _editSingleSerial(sn),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: isSold
                                        ? AppColors.textSecondary.withValues(alpha: 0.4)
                                        : AppColors.danger,
                                  ),
                                  tooltip: isSold
                                      ? 'Cannot delete sold panel'
                                      : 'Remove from batch',
                                  onPressed: isSold
                                      ? null
                                      : () => _deleteSingleSerial(sn),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_serials.length} Panels Total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(_totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.solarGreenDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Batch Changes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

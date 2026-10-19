import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/customer.dart';
import '../../models/panel_item.dart';
import '../../providers/sale_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../utils/formatters.dart';
import '../customer/add_customer_screen.dart';
import 'sale_barcode_scanner_screen.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  int _selectedWattage = 540;
  final _priceController = TextEditingController(text: '14500');
  final _notesController = TextEditingController();
  final _scanController = TextEditingController();
  final _scanFocusNode = FocusNode();

  DateTime _saleDate = DateTime.now();
  List<PanelItem> _availablePanels = [];
  final Set<String> _selectedSerials = {};
  bool _isLoadingPanels = false;
  bool _isSubmitting = false;

  String _searchQuery = '';
  String _filterTab = 'all'; // 'all', 'selected', 'unselected'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CustomerProvider>().loadCustomers();
      await context.read<InventoryProvider>().loadPanels();
      if (!mounted) return;

      final inv = context.read<InventoryProvider>();
      // If default 540 has 0 in stock, switch to the first wattage that has available stock
      if (inv.getAvailableCount(_selectedWattage) == 0) {
        final withStock =
            inv.availableWattages.where((w) => inv.getAvailableCount(w) > 0);
        if (withStock.isNotEmpty) {
          setState(() {
            _selectedWattage = withStock.first;
          });
        }
      }
      _fetchAvailablePanels();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailablePanels() async {
    setState(() => _isLoadingPanels = true);
    try {
      final panels = await context
          .read<InventoryProvider>()
          .getAvailablePanelsByWattage(_selectedWattage);
      setState(() {
        _availablePanels = panels;
        // Keep only selected serials that are available in new wattage
        _selectedSerials.removeWhere(
            (sn) => !panels.any((p) => p.serialNumber == sn));
      });
    } finally {
      setState(() => _isLoadingPanels = false);
    }
  }

  void _handleScanOrSubmit(String raw) {
    final serial = raw.trim().toUpperCase();
    if (serial.isEmpty) return;

    // 1. Check if already selected
    if (_selectedSerials.contains(serial)) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Panel "$serial" is already selected.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      _scanController.clear();
      _scanFocusNode.requestFocus();
      return;
    }

    // 2. Check if in available panels for this wattage
    final match = _availablePanels.cast<PanelItem?>().firstWhere(
          (p) => p?.serialNumber.toUpperCase() == serial,
          orElse: () => null,
        );

    if (match != null) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      setState(() {
        _selectedSerials.add(match.serialNumber);
        _scanController.clear();
        _searchQuery = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✓ Selected "${match.serialNumber}" (Batch: ${match.batchNumber}) • Total: ${_selectedSerials.length} panels'),
          backgroundColor: AppColors.solarGreenDark,
          duration: const Duration(seconds: 2),
        ),
      );
      _scanFocusNode.requestFocus();
      return;
    }

    // 3. Diagnose why it wasn't found from entire inventory
    final allPanels = context.read<InventoryProvider>().allPanels;
    final inAll = allPanels.cast<PanelItem?>().firstWhere(
          (p) => p?.serialNumber.toUpperCase() == serial,
          orElse: () => null,
        );

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    if (inAll != null) {
      if (inAll.wattage != _selectedWattage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Wattage Mismatch: "$serial" is ${inAll.wattage}W (current sale is ${_selectedWattage}W).'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (!inAll.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unavailable: Panel "$serial" is already SOLD and cannot be dispatched.'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Panel "$serial" is not available for selection.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Serial "$serial" not found in inventory for ${_selectedWattage}W stock.'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _scanController.clear();
    _scanFocusNode.requestFocus();
  }

  Future<void> _openCameraScanner() async {
    final allPanels = context.read<InventoryProvider>().allPanels;
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (ctx) => SaleBarcodeScannerScreen(
          wattage: _selectedWattage,
          availablePanels: _availablePanels,
          initiallySelectedSerials: _selectedSerials,
          allInventoryPanels: allPanels,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSerials.clear();
        _selectedSerials.addAll(result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedSerials.length} panels selected for sale.'),
          backgroundColor: AppColors.solarGreenDark,
        ),
      );
    }
  }

  List<PanelItem> get _filteredPanels {
    var list = _availablePanels;
    if (_filterTab == 'selected') {
      list =
          list.where((p) => _selectedSerials.contains(p.serialNumber)).toList();
    } else if (_filterTab == 'unselected') {
      list = list
          .where((p) => !_selectedSerials.contains(p.serialNumber))
          .toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((p) {
        return p.serialNumber.toLowerCase().contains(q) ||
            p.batchNumber.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  double get _unitPrice => double.tryParse(_priceController.text) ?? 0.0;
  double get _totalAmount => _selectedSerials.length * _unitPrice;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a KSEB customer.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedSerials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one physical solar panel.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final customers = context.read<CustomerProvider>().customers;
    final customer = customers.firstWhere((c) => c.id == _selectedCustomerId);

    // Show explicit confirmation dialog before committing
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Confirm Solar Sale & Dispatch',
      message:
          'Customer: ${customer.name ?? 'Customer'}\nKSEB Consumer #: ${customer.consumerNumber}\nPanels: ${_selectedSerials.length} units (${_selectedWattage}W)\nTotal Amount: ${Formatters.formatCurrency(_totalAmount)}\n\nCommit this sale and allocate serial numbers?',
      confirmText: 'Confirm & Dispatch',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await context.read<SaleProvider>().addSale(
            saleDate: _saleDate,
            customerId: _selectedCustomerId!,
            panelWattage: _selectedWattage,
            serialNumbers: _selectedSerials.toList(),
            unitSellingPrice: _unitPrice,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      if (mounted) {
        context.read<DashboardProvider>().loadDashboard();
        context.read<InventoryProvider>().loadPanels();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sale recorded! ${_selectedSerials.length} panels dispatched to ${customer.name ?? customer.consumerNumber}.'),
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
    final customers = context.watch<CustomerProvider>().customers;
    final inventory = context.watch<InventoryProvider>();
    final availableWattages = inventory.availableWattages;

    Customer? selectedCustomer;
    if (_selectedCustomerId != null && customers.isNotEmpty) {
      try {
        selectedCustomer =
            customers.firstWhere((c) => c.id == _selectedCustomerId);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Solar Sale'),
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
                title: const Text('Sale Date',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                subtitle: Text(
                  Formatters.formatDate(_saleDate),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _saleDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _saleDate = picked);
                },
              ),
            ),
            const SizedBox(height: 14),

            // Customer Selection Dropdown + Add button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: 'Select Customer (KSEB) *',
                      prefixIcon: Icon(Icons.person_search),
                    ),
                    items: customers.map((c) {
                      final label = c.name != null
                          ? '${c.name} (${c.consumerNumber})'
                          : c.consumerNumber;
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCustomerId = val);
                    },
                    validator: (v) => v == null ? 'Customer is required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Create New Customer',
                  onPressed: () async {
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AddCustomerScreen()),
                    );
                    if (res is Customer) {
                      setState(() => _selectedCustomerId = res.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // KSEB Consumer Confirmation Card
            if (selectedCustomer != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user,
                        color: AppColors.primaryBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KSEB Consumer #: ${selectedCustomer.consumerNumber}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          Text(
                            'Name: ${selectedCustomer.name ?? 'Customer'} | Phone: ${selectedCustomer.phone}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Wattage Selector Dropdown
            DropdownButtonFormField<int>(
              key: ValueKey(_selectedWattage),
              initialValue: availableWattages.contains(_selectedWattage)
                  ? _selectedWattage
                  : (availableWattages.isNotEmpty ? availableWattages.first : 540),
              decoration: const InputDecoration(
                labelText: 'Panel Wattage (W) *',
                prefixIcon: Icon(Icons.solar_power),
              ),
              items: availableWattages.map((w) {
                final inStock = inventory.getAvailableCount(w);
                final stockSuffix =
                    inStock > 0 ? ' ($inStock available)' : ' (0 available)';
                return DropdownMenuItem<int>(
                  value: w,
                  child: Text(
                    '${Formatters.formatWattage(w)}$stockSuffix',
                    style: TextStyle(
                      fontSize: 13,
                      color: inStock > 0 ? AppColors.textMain : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedWattage) {
                  setState(() {
                    _selectedWattage = val;
                    _selectedSerials.clear();
                  });
                  _fetchAvailablePanels();
                }
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Selling Price (₹) *',
                hintText: '14500',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val < 0) return 'Must be ≥ 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Available Panel Serials Multi-Select Chips with Barcode Scanner
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title and Select/Deselect All
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available ${_selectedWattage}W Panels (${_availablePanels.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        if (_availablePanels.isNotEmpty)
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_selectedSerials.length ==
                                        _availablePanels.length) {
                                      _selectedSerials.clear();
                                    } else {
                                      _selectedSerials.addAll(_availablePanels
                                          .map((p) => p.serialNumber));
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedSerials.length ==
                                          _availablePanels.length
                                      ? 'Deselect All'
                                      : 'Select All',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primaryBlue),
                                ),
                              ),
                              if (_selectedSerials.isNotEmpty &&
                                  _selectedSerials.length !=
                                      _availablePanels.length) ...[
                                const Text(' | ',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedSerials.clear();
                                    });
                                  },
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Primary Action: Camera Barcode Scanner Button
                    if (_availablePanels.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
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
                          label: Text(
                            'Scan Panel Barcodes (${_selectedSerials.length}/${_availablePanels.length} Selected)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Fast Hardware / Bluetooth Barcode Scanner & Search Input Field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _scanController,
                              focusNode: _scanFocusNode,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Scan barcode or type serial (Press Enter)...',
                                prefixIcon: const Icon(Icons.barcode_reader,
                                    size: 20),
                                suffixIcon: _scanController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _scanController.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              onSubmitted: _handleScanOrSubmit,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.solarGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _scanController.text.trim().isEmpty
                                ? null
                                : () => _handleScanOrSubmit(
                                    _scanController.text),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Filter Pills for easily managing large stocks (e.g. 500+ panels)
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text('All (${_availablePanels.length})'),
                            selected: _filterTab == 'all',
                            onSelected: (_) =>
                                setState(() => _filterTab = 'all'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text('Selected (${_selectedSerials.length})'),
                            selected: _filterTab == 'selected',
                            selectedColor: AppColors.primaryBlueLight,
                            onSelected: (_) =>
                                setState(() => _filterTab = 'selected'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(
                                'Unselected (${_availablePanels.length - _selectedSerials.length})'),
                            selected: _filterTab == 'unselected',
                            onSelected: (_) =>
                                setState(() => _filterTab = 'unselected'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (_isLoadingPanels)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_availablePanels.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.solarAmberLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No available ${_selectedWattage}W panels in stock. Please record an inward purchase first.',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      )
                    else if (_filteredPanels.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No panels match "$_searchQuery".'
                              : _filterTab == 'selected'
                                  ? 'No panels selected yet. Scan barcodes or tap below.'
                                  : 'All available panels are currently selected.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _filteredPanels.map((p) {
                              final isSelected =
                                  _selectedSerials.contains(p.serialNumber);
                              return FilterChip(
                                label: Text(
                                  p.serialNumber,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMain,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primaryBlue,
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSerials.add(p.serialNumber);
                                    } else {
                                      _selectedSerials.remove(p.serialNumber);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    const Divider(height: 20),

                    // Dynamic derived quantity and total amount calculation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Derived Quantity: ${_selectedSerials.length} panels',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          'Total: ${Formatters.formatCurrency(_totalAmount)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.solarGreenDark,
                          ),
                        ),
                      ],
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
                hintText: 'e.g. 5kW On-Grid Installation Phase 1',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.solarGreenDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSubmitting || _selectedSerials.isEmpty
                  ? null
                  : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Review & Confirm Sale (${_selectedSerials.length} Panels)',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

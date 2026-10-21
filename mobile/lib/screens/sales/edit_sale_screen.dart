import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/panel_item.dart';
import '../../models/sale.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import 'sale_barcode_scanner_screen.dart';

class EditSaleScreen extends StatefulWidget {
  final SaleTransaction sale;

  const EditSaleScreen({super.key, required this.sale});

  @override
  State<EditSaleScreen> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends State<EditSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  late String? _selectedCustomerId;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  final _searchController = TextEditingController();

  late DateTime _saleDate;
  final Set<String> _selectedSerials = {};
  List<PanelItem> _availableAndCurrentPanels = [];
  bool _isLoadingPanels = true;
  bool _isSaving = false;

  String _searchQuery = '';
  String _filterTab = 'all'; // 'all', 'selected', 'unselected'

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.sale.customerId;
    _priceController = TextEditingController(
        text: widget.sale.unitSellingPrice.toStringAsFixed(0));
    _notesController = TextEditingController(text: widget.sale.notes ?? '');
    _saleDate = widget.sale.saleDate;
    _selectedSerials.addAll(widget.sale.serialNumbers);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CustomerProvider>().loadCustomers();
      await _loadPanels();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPanels() async {
    setState(() => _isLoadingPanels = true);
    try {
      final inv = context.read<InventoryProvider>();
      await inv.loadPanels();

      // Panels available for this wattage
      final available = await inv.getAvailablePanelsByWattage(widget.sale.panelWattage);

      // Current panels in this sale (some might have status sold)
      final currentList = <PanelItem>[];
      for (final sn in widget.sale.serialNumbers) {
        final match = inv.allPanels.cast<PanelItem?>().firstWhere(
              (p) => p?.serialNumber.toUpperCase() == sn.toUpperCase(),
              orElse: () => null,
            );
        if (match != null) {
          currentList.add(match);
        } else {
          // Synthetic fallback
          currentList.add(
            PanelItem(
              id: sn,
              serialNumber: sn,
              batchNumber: 'N/A',
              wattage: widget.sale.panelWattage,
              purchaseId: '',
              purchasePrice: 0,
              status: PanelStatus.sold,
              saleId: widget.sale.id,
            ),
          );
        }
      }

      // Merge and deduplicate by serialNumber
      final combined = <String, PanelItem>{};
      for (final p in currentList) {
        combined[p.serialNumber.toUpperCase()] = p;
      }
      for (final p in available) {
        if (!combined.containsKey(p.serialNumber.toUpperCase())) {
          combined[p.serialNumber.toUpperCase()] = p;
        }
      }

      final list = combined.values.toList();
      list.sort((a, b) => a.serialNumber.compareTo(b.serialNumber));

      if (mounted) {
        setState(() {
          _availableAndCurrentPanels = list;
          _isLoadingPanels = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPanels = false);
    }
  }

  double get _currentPrice => double.tryParse(_priceController.text) ?? 0.0;
  double get _totalAmount => _selectedSerials.length * _currentPrice;

  List<PanelItem> get _filteredPanels {
    return _availableAndCurrentPanels.where((p) {
      final isSelected = _selectedSerials.contains(p.serialNumber);

      if (_filterTab == 'selected' && !isSelected) return false;
      if (_filterTab == 'unselected' && isSelected) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesSn = p.serialNumber.toLowerCase().contains(q);
        final matchesBatch = p.batchNumber.toLowerCase().contains(q);
        return matchesSn || matchesBatch;
      }

      return true;
    }).toList();
  }

  void _toggleSerial(String sn) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSerials.contains(sn)) {
        _selectedSerials.remove(sn);
      } else {
        _selectedSerials.add(sn);
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer for this sale.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedSerials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one panel must be selected for the sale.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final saleProvider = context.read<SaleProvider>();
      final price = double.parse(_priceController.text);
      final notes = _notesController.text.trim();

      await saleProvider.updateSale(
        id: widget.sale.id,
        saleDate: _saleDate,
        customerId: _selectedCustomerId,
        unitSellingPrice: price,
        serialNumbers: _selectedSerials.toList(),
        notes: notes.isEmpty ? null : notes,
      );

      if (mounted) {
        context.read<DashboardProvider>().loadDashboard();
        context.read<InventoryProvider>().loadPanels();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sale updated successfully (${_selectedSerials.length} panels dispatched).'),
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
    final customers = context.watch<CustomerProvider>().customers;
    final filtered = _filteredPanels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Sale Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Barcode Scanner',
            onPressed: () async {
              final inv = context.read<InventoryProvider>();
              final scannedSet =
                  await Navigator.of(context).push<Set<String>>(
                MaterialPageRoute(
                  builder: (_) => SaleBarcodeScannerScreen(
                    wattage: widget.sale.panelWattage,
                    availablePanels: _availableAndCurrentPanels,
                    initiallySelectedSerials: _selectedSerials,
                    allInventoryPanels: inv.allPanels,
                  ),
                ),
              );

              if (scannedSet != null && mounted) {
                setState(() {
                  _selectedSerials.clear();
                  _selectedSerials.addAll(scannedSet);
                });
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
            // Customer & Date Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sale Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${widget.sale.panelWattage}W Mono PERC',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Customer Selector
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Customer *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: customers.map((c) {
                        final label = c.name != null && c.name!.isNotEmpty
                            ? '${c.name} (${c.consumerNumber})'
                            : '${c.consumerNumber} - ${c.phone}';
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCustomerId = val);
                      },
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please select a customer'
                          : null,
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
                                initialDate: _saleDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() => _saleDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Sale Date',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                Formatters.formatDate(_saleDate),
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
                              labelText: 'Selling Price (₹) *',
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

            // Panels Selection Card
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
                              'Dispatched Panels Selection',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              '${_selectedSerials.length} of ${_availableAndCurrentPanels.length} available panels selected',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter tabs (All, Selected, Unselected)
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('All (${_availableAndCurrentPanels.length})'),
                          selected: _filterTab == 'all',
                          onSelected: (_) =>
                              setState(() => _filterTab = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: Text('Selected (${_selectedSerials.length})'),
                          selected: _filterTab == 'selected',
                          selectedColor: AppColors.solarGreenLight,
                          onSelected: (_) =>
                              setState(() => _filterTab = 'selected'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: Text(
                              'Available (${_availableAndCurrentPanels.length - _selectedSerials.length})'),
                          selected: _filterTab == 'unselected',
                          onSelected: (_) =>
                              setState(() => _filterTab = 'unselected'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search box
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search serial or batch number...',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 12),

                    const Divider(height: 1),

                    // List of Panels
                    if (_isLoadingPanels)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No panels match your filter.',
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
                          final panel = filtered[index];
                          final isSelected =
                              _selectedSerials.contains(panel.serialNumber);

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            activeColor: AppColors.solarGreenDark,
                            value: isSelected,
                            onChanged: (_) =>
                                _toggleSerial(panel.serialNumber),
                            title: Text(
                              panel.serialNumber,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.textMain
                                    : AppColors.textSecondary,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlueLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Batch: ${panel.batchNumber}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cost: ${Formatters.formatCurrency(panel.purchasePrice)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
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
                      '${_selectedSerials.length} Panels Selected',
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
                  backgroundColor: AppColors.solarGreenDark,
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
                        'Save Sale Changes',
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

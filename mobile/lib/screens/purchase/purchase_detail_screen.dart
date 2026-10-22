import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/panel_item.dart';
import '../../models/purchase.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirmation_dialog.dart';
import 'edit_purchase_screen.dart';
import 'barcode_scanner_screen.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseTransaction purchase;

  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late PurchaseTransaction _purchase;
  Map<String, PanelItem> _panelsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _purchase = widget.purchase;
    _loadPanelsData();
  }

  Future<void> _loadPanelsData() async {
    try {
      final inv = context.read<InventoryProvider>();
      await inv.loadPanels();
      if (!mounted) return;
      final map = <String, PanelItem>{};
      for (final p in inv.allPanels) {
        if (p.batchNumber == _purchase.batchNumber ||
            _purchase.serialNumbers.contains(p.serialNumber)) {
          map[p.serialNumber.toUpperCase()] = p;
        }
      }

      // Also refresh the purchase record from the provider
      final allP = context.read<PurchaseProvider>().allPurchases;
      final current =
          allP.cast<PurchaseTransaction?>().firstWhere(
                (p) => p?.id == _purchase.id,
                orElse: () => null,
              );

      setState(() {
        if (current != null) _purchase = current;
        _panelsMap = map;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditScreen() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPurchaseScreen(purchase: _purchase),
      ),
    );
    if (updated == true && mounted) {
      await _loadPanelsData();
    }
  }

  Future<void> _addPanelsDirectly() async {
    final inv = context.read<InventoryProvider>();
    final existingSerials =
        inv.allPanels.map((p) => p.serialNumber.toUpperCase()).toSet();

    final scanned = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          targetQuantity: 1000,
          initialSerials: _purchase.serialNumbers,
          existingInventorySerials: existingSerials,
          batchNumber: _purchase.batchNumber,
        ),
      ),
    );

    if (scanned != null && mounted) {
      final newSerials = scanned
          .map((s) => s.trim().toUpperCase())
          .where((s) => !_purchase.serialNumbers
              .map((p) => p.toUpperCase())
              .contains(s))
          .toList();

      if (newSerials.isNotEmpty) {
        try {
          await context
              .read<PurchaseProvider>()
              .addPanelsToPurchase(_purchase.id, newSerials);
          if (mounted) {
            context.read<DashboardProvider>().loadDashboard();
            context.read<InventoryProvider>().loadPanels();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Added ${newSerials.length} new panel(s) to batch "${_purchase.batchNumber}".'),
                backgroundColor: AppColors.solarGreenDark,
              ),
            );
            await _loadPanelsData();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _editPanelSerial(String oldSerial) async {
    final editController = TextEditingController(text: oldSerial);
    final panel = _panelsMap[oldSerial.toUpperCase()];
    final isSold = panel?.isSold == true;

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
                      Icon(Icons.info_outline,
                          size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This panel is SOLD. Updating its serial will update both inventory and the customer sales dispatch record.',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF78350F)),
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
                if (newSn.isNotEmpty) Navigator.pop(ctx, newSn);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != oldSerial) {
      if (!mounted) return;
      try {
        await context
            .read<PurchaseProvider>()
            .updatePanelSerialNumber(_purchase.id, oldSerial, result);
        if (mounted) {
          context.read<DashboardProvider>().loadDashboard();
          context.read<InventoryProvider>().loadPanels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Panel serial updated to "$result".'),
              backgroundColor: AppColors.solarGreenDark,
            ),
          );
          await _loadPanelsData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePanel(String serial) async {
    final panel = _panelsMap[serial.toUpperCase()];
    if (panel?.isSold == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cannot remove panel "$serial". It has already been sold/dispatched.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Remove Panel "$serial"?',
      message:
          'This panel will be removed from batch "${_purchase.batchNumber}" and inventory.',
      confirmText: 'Remove Panel',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      try {
        await context
            .read<PurchaseProvider>()
            .deletePanelFromPurchase(_purchase.id, serial);
        if (mounted) {
          context.read<DashboardProvider>().loadDashboard();
          context.read<InventoryProvider>().loadPanels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Panel "$serial" removed from batch.'),
              backgroundColor: AppColors.solarGreenDark,
            ),
          );
          await _loadPanelsData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Batch: ${_purchase.batchNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Batch Details & Panels',
            onPressed: _openEditScreen,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete Inward Purchase',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Delete Inward Batch "${_purchase.batchNumber}"?',
                message:
                    'This will delete the purchase and all uncommitted inventory panels. Panels that have been sold cannot be deleted.',
                confirmText: 'Delete Batch',
                isDestructive: true,
              );
              if (confirmed && context.mounted) {
                try {
                  await context
                      .read<PurchaseProvider>()
                      .deletePurchase(_purchase.id);
                  if (context.mounted) {
                    context.read<DashboardProvider>().loadDashboard();
                    context.read<InventoryProvider>().loadPanels();
                    Navigator.pop(context);
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _purchase.batchNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _purchase.type == 'DCR'
                                  ? AppColors.solarGreenLight
                                  : AppColors.solarAmberLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _purchase.type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _purchase.type == 'DCR'
                                    ? AppColors.solarGreenDark
                                    : AppColors.solarAmberDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_purchase.wattage}W',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow('Purchase Date',
                      Formatters.formatDate(_purchase.purchaseDate)),
                  _infoRow('Panel Type', _purchase.type),
                  _infoRow(
                      'Supplier', _purchase.supplierName ?? 'Not specified'),
                  _infoRow('Quantity', '${_purchase.quantity} Panels'),
                  _infoRow('Unit Price',
                      Formatters.formatCurrency(_purchase.unitPurchasePrice)),
                  _infoRow(
                    'Total Inward Amount',
                    Formatters.formatCurrency(_purchase.totalPurchaseAmount),
                    isBold: true,
                    valueColor: AppColors.solarGreenDark,
                  ),
                  if (_purchase.notes != null) ...[
                    const Divider(height: 24),
                    const Text('Notes',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(_purchase.notes!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header for panels with "+ Add Panels" button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Serialized Panels in Batch',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    Text(
                      '${_purchase.serialNumbers.length} units registered',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.solarAmber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Panels',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: _openEditScreen,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBlueLight,
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    tooltip: 'Scan & Add Panels',
                    onPressed: _addPanelsDirectly,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          Card(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _purchase.serialNumbers.length,
                    separatorBuilder: (_, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final sn = _purchase.serialNumbers[index];
                      final panel = _panelsMap[sn.toUpperCase()];
                      final isSold = panel?.isSold == true;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: isSold
                              ? AppColors.solarAmberLight
                              : AppColors.solarGreenLight,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSold
                                  ? const Color(0xFFB45309)
                                  : AppColors.solarGreenDark,
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
                              onPressed: () => _editPanelSerial(sn),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: isSold
                                    ? AppColors.textSecondary
                                        .withValues(alpha: 0.3)
                                    : AppColors.danger,
                              ),
                              tooltip: isSold
                                  ? 'Cannot delete sold panel'
                                  : 'Remove from batch',
                              onPressed:
                                  isSold ? null : () => _deletePanel(sn),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

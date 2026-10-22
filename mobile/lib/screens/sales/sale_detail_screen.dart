import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/panel_item.dart';
import '../../models/purchase.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../utils/formatters.dart';
import '../purchase/purchase_detail_screen.dart';
import 'edit_sale_screen.dart';

class SaleDetailScreen extends StatefulWidget {
  final SaleTransaction sale;

  const SaleDetailScreen({super.key, required this.sale});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late SaleTransaction _sale;
  Map<String, PanelItem> _panelsBySerial = {};
  Map<String, PurchaseTransaction> _purchasesById = {};
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
    _loadPanelAndPurchaseDetails();
  }

  Future<void> _loadPanelAndPurchaseDetails() async {
    try {
      final inventoryService =
          context.read<InventoryProvider>().inventoryService;
      final allPurchases =
          await inventoryService.purchaseRepository.getAllPurchases();
      if (!mounted) return;
      final allSales = context.read<SaleProvider>().allSales;
      final current = allSales.cast<SaleTransaction?>().firstWhere(
            (s) => s?.id == _sale.id,
            orElse: () => null,
          );

      if (current != null) {
        _sale = current;
      }

      final panelsMap = <String, PanelItem>{};
      final purchasesMap = <String, PurchaseTransaction>{};

      for (final sn in _sale.serialNumbers) {
        var panel =
            await inventoryService.panelRepository.getPanelBySerialNumber(sn);
        PurchaseTransaction? purchase;

        if (panel != null) {
          panelsMap[sn] = panel;
          if (panel.purchaseId.isNotEmpty) {
            purchase = await inventoryService.purchaseRepository
                .getPurchaseById(panel.purchaseId);
          }
          purchase ??= allPurchases.where((p) {
            return p.batchNumber == panel.batchNumber ||
                p.serialNumbers.contains(sn);
          }).firstOrNull;
        } else {
          purchase = allPurchases.where((p) {
            return p.serialNumbers.contains(sn);
          }).firstOrNull;

          if (purchase != null) {
            final syntheticPanel = PanelItem(
              id: 'item_$sn',
              serialNumber: sn,
              batchNumber: purchase.batchNumber,
              wattage: purchase.wattage,
              purchaseId: purchase.id,
              purchasePrice: purchase.unitPurchasePrice,
              status: PanelStatus.sold,
              saleId: _sale.id,
            );
            panelsMap[sn] = syntheticPanel;
          }
        }

        if (purchase != null && !purchasesMap.containsKey(purchase.id)) {
          purchasesMap[purchase.id] = purchase;
        }
      }

      if (mounted) {
        setState(() {
          _panelsBySerial = panelsMap;
          _purchasesById = purchasesMap;
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Sale & Dispatched Panels',
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditSaleScreen(sale: _sale),
                ),
              );
              if (updated == true && mounted) {
                await _loadPanelAndPurchaseDetails();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Cancel & Reconcile Sale',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Cancel Sale & Return Panels?',
                message:
                    'All ${_sale.serialNumbers.length} allocated solar panel(s) will be returned to available inventory immediately.',
                confirmText: 'Cancel Sale & Restore Stock',
                isDestructive: true,
              );

              if (confirmed && context.mounted) {
                try {
                  await context.read<SaleProvider>().deleteSale(_sale.id);
                  if (context.mounted) {
                    context.read<DashboardProvider>().loadDashboard();
                    context.read<InventoryProvider>().loadPanels();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Sale cancelled. Allocated panels restored to available stock.'),
                        backgroundColor: AppColors.solarGreenDark,
                      ),
                    );
                    Navigator.of(context).pop();
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
          // Customer & KSEB Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person,
                            color: AppColors.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sale.customerName ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              'KSEB Consumer #: ${_sale.consumerNumber}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _sale.type == 'DCR'
                              ? AppColors.solarGreenLight
                              : AppColors.solarAmberLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _sale.type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _sale.type == 'DCR'
                                ? AppColors.solarGreenDark
                                : AppColors.solarAmberDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow(
                      'Sale Date', Formatters.formatDate(_sale.saleDate)),
                  _infoRow('Panel Type', _sale.type),
                  _infoRow('Panel Wattage', '${_sale.panelWattage}W'),
                  _infoRow('Dispatched Quantity',
                      '${_sale.quantity} Panels'),
                  _infoRow('Unit Selling Price',
                      Formatters.formatCurrency(_sale.unitSellingPrice)),
                  _infoRow(
                    'Total Selling Amount',
                    Formatters.formatCurrency(_sale.totalSellingAmount),
                    isBold: true,
                    valueColor: AppColors.solarGreenDark,
                  ),
                  if (_sale.notes != null) ...[
                    const Divider(height: 24),
                    const Text('Notes',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(_sale.notes!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Source Inward Purchase Information
          if (_isLoadingDetails) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ] else if (_purchasesById.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Source Inward Purchase',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  '${_purchasesById.length} ${_purchasesById.length == 1 ? 'batch' : 'batches'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._purchasesById.values.map((purchase) {
              final countInSale = _sale.serialNumbers.where((sn) {
                final p = _panelsBySerial[sn];
                return p?.purchaseId == purchase.id ||
                    p?.batchNumber == purchase.batchNumber ||
                    purchase.serialNumbers.contains(sn);
              }).length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlueLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long,
                                    color: AppColors.primaryBlue, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Batch: ${purchase.batchNumber}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMain,
                                    ),
                                  ),
                                  if (purchase.supplierName != null &&
                                      purchase.supplierName!.isNotEmpty)
                                    Text(
                                      purchase.supplierName!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${purchase.wattage}W',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _infoRow('Purchase Date',
                          Formatters.formatDate(purchase.purchaseDate)),
                      _infoRow('Inward Unit Price',
                          Formatters.formatCurrency(purchase.unitPurchasePrice)),
                      _infoRow('Allocated from Batch',
                          '$countInSale of ${_sale.serialNumbers.length} dispatched ($countInSale/${purchase.quantity} in Batch)'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side:
                                const BorderSide(color: AppColors.primaryBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text(
                            'View Purchase Record',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PurchaseDetailScreen(purchase: purchase),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // Allocated Physical Panels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Allocated Serial Numbers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              Text(
                '${_sale.serialNumbers.length} dispatched',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.solarGreenDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sale.serialNumbers.length,
              separatorBuilder: (_, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final sn = _sale.serialNumbers[index];
                final panel = _panelsBySerial[sn];
                PurchaseTransaction? purchase;
                if (panel != null &&
                    _purchasesById.containsKey(panel.purchaseId)) {
                  purchase = _purchasesById[panel.purchaseId];
                } else {
                  purchase = _purchasesById.values.where((p) {
                    return p.serialNumbers.contains(sn) ||
                        (panel != null && p.batchNumber == panel.batchNumber);
                  }).firstOrNull;
                }

                final batchNum = panel?.batchNumber ?? purchase?.batchNumber;
                final inwardPrice =
                    panel?.purchasePrice ?? purchase?.unitPurchasePrice;

                return InkWell(
                  onTap: purchase != null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PurchaseDetailScreen(purchase: purchase!),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.solarGreenDark, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sn,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textMain,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.solarGreenLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Dispatched',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.solarGreenDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Batch
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlueLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.layers_outlined,
                                        size: 13,
                                        color: AppColors.primaryBlue),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Batch: ${batchNum ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Inward / Purchase Price
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_downward_rounded,
                                        size: 12,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Inward: ${inwardPrice != null ? Formatters.formatCurrency(inwardPrice) : 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Selling Price
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.solarGreenLight
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_upward_rounded,
                                        size: 12,
                                        color: AppColors.solarGreenDark),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sale: ${Formatters.formatCurrency(_sale.unitSellingPrice)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.solarGreenDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (purchase != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 30),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_outlined,
                                    size: 13, color: AppColors.primaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'View Inward Purchase (${purchase.batchNumber})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.chevron_right,
                                    size: 13, color: AppColors.primaryBlue),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
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

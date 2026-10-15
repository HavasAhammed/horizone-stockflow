import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../utils/formatters.dart';

class SaleDetailScreen extends StatelessWidget {
  final SaleTransaction sale;

  const SaleDetailScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Cancel & Reconcile Sale',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Cancel Sale & Return Panels?',
                message:
                    'All ${sale.serialNumbers.length} allocated solar panel(s) will be returned to available inventory immediately.',
                confirmText: 'Cancel Sale & Restore Stock',
                isDestructive: true,
              );

              if (confirmed && context.mounted) {
                try {
                  await context.read<SaleProvider>().deleteSale(sale.id);
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
                              sale.customerName ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              'KSEB Consumer #: ${sale.consumerNumber}',
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
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow('Sale Date', Formatters.formatDate(sale.saleDate)),
                  _infoRow('Panel Wattage', '${sale.panelWattage}W'),
                  _infoRow('Dispatched Quantity', '${sale.quantity} Panels'),
                  _infoRow('Unit Selling Price',
                      Formatters.formatCurrency(sale.unitSellingPrice)),
                  _infoRow(
                    'Total Selling Amount',
                    Formatters.formatCurrency(sale.totalSellingAmount),
                    isBold: true,
                    valueColor: AppColors.solarGreenDark,
                  ),
                  if (sale.notes != null) ...[
                    const Divider(height: 24),
                    const Text('Notes',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(sale.notes!, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

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
                '${sale.serialNumbers.length} dispatched',
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sale.serialNumbers.length,
              separatorBuilder: (_, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final sn = sale.serialNumbers[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle,
                      color: AppColors.solarGreenDark, size: 20),
                  title: Text(
                    sn,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.solarGreenLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Dispatched',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.solarGreenDark)),
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
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

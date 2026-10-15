import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/purchase.dart';
import '../../utils/formatters.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final PurchaseTransaction purchase;

  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Batch: ${purchase.batchNumber}'),
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
                      Text(
                        purchase.batchNumber,
                        style: const TextStyle(
                          fontSize: 18,
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
                          '${purchase.wattage}W',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow('Purchase Date',
                      Formatters.formatDate(purchase.purchaseDate)),
                  _infoRow(
                      'Supplier', purchase.supplierName ?? 'Not specified'),
                  _infoRow('Quantity', '${purchase.quantity} Panels'),
                  _infoRow('Unit Price',
                      Formatters.formatCurrency(purchase.unitPurchasePrice)),
                  _infoRow(
                    'Total Inward Amount',
                    Formatters.formatCurrency(purchase.totalPurchaseAmount),
                    isBold: true,
                    valueColor: AppColors.solarGreenDark,
                  ),
                  if (purchase.notes != null) ...[
                    const Divider(height: 24),
                    const Text('Notes',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(purchase.notes!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                '${purchase.serialNumbers.length} units',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: purchase.serialNumbers.length,
              separatorBuilder: (_, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final sn = purchase.serialNumbers[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primaryBlueLight,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue),
                    ),
                  ),
                  title: Text(
                    sn,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: const Icon(Icons.solar_power_outlined,
                      size: 18, color: AppColors.primaryBlue),
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

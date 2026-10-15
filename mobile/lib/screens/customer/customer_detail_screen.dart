import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/customer.dart';
import '../../models/sale.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../utils/formatters.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<SaleTransaction> _linkedSales = [];
  bool _isLoadingSales = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final sales = await context
        .read<CustomerProvider>()
        .getCustomerSales(widget.customer.id);
    if (mounted) {
      setState(() {
        _linkedSales = sales;
        _isLoadingSales = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name ?? 'Customer Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete Customer',
            onPressed: () async {
              if (_linkedSales.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot delete customer: There are ${_linkedSales.length} linked sale transaction(s). Deletion blocked to preserve warranty & installation records.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Delete Customer?',
                message:
                    'Are you sure you want to delete ${widget.customer.name ?? widget.customer.consumerNumber}?',
                confirmText: 'Delete',
                isDestructive: true,
              );

              if (confirmed && context.mounted) {
                try {
                  await context
                      .read<CustomerProvider>()
                      .deleteCustomer(widget.customer.id);
                  if (context.mounted) {
                    context.read<DashboardProvider>().loadDashboard();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer deleted.'),
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
          // Customer Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryBlueLight,
                        child: const Icon(Icons.person,
                            color: AppColors.primaryBlue, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customer.name ?? 'Unnamed Customer',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                            Text(
                              'KSEB: ${widget.customer.consumerNumber}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow('Phone Number', widget.customer.phone),
                  _infoRow('Site Address',
                      widget.customer.address ?? 'Not recorded'),
                  _infoRow('Registered On',
                      Formatters.formatDate(widget.customer.createdAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Linked Sales Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Linked Solar Installations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              Text(
                '${_linkedSales.length} records',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoadingSales)
            const Center(child: CircularProgressIndicator())
          else if (_linkedSales.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No sales recorded for this customer yet.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _linkedSales.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final sale = _linkedSales[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${sale.panelWattage}W Solar Installation',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              Formatters.formatCurrency(
                                  sale.totalSellingAmount),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.solarGreenDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${Formatters.formatDate(sale.saleDate)} • ${sale.quantity} panels dispatched',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Serials: ${sale.serialNumbers.join(', ')}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain)),
        ],
      ),
    );
  }
}

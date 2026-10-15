import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/dashboard_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/sale_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/badge_widget.dart';
import '../utils/formatters.dart';
import 'purchase/add_purchase_screen.dart';
import 'sales/add_sale_screen.dart';
import 'customer/add_customer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  void _refreshAll() {
    context.read<DashboardProvider>().loadDashboard();
    context.read<CustomerProvider>().loadCustomers();
    context.read<PurchaseProvider>().loadPurchases();
    context.read<SaleProvider>().loadSales();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.metrics == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final lowStock = provider.lowStockAlerts;
        final byWattage = provider.byWattage;

        return RefreshIndicator(
          onRefresh: () async => _refreshAll(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Quick Actions Bar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Record Sale', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddSaleScreen()),
                        );
                        if (res == true) _refreshAll();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.solarAmber,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.add_box, size: 16),
                      label: const Text('Add Purchase', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
                        );
                        if (res == true) _refreshAll();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Customer', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                        );
                        if (res == true) _refreshAll();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Low-Stock Warning Banner
              if (lowStock.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.solarAmberLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.solarAmber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.solarAmber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Low Stock Warning: ${lowStock.map((a) => '${a['wattage']}W has only ${a['available']} panel(s) left').join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // KPI Stat Cards Grid (2x2)
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Available Stock',
                      value: '${provider.totalAvailable} Panels',
                      subtext: 'In warehouse',
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.solarGreenDark,
                      iconBg: AppColors.solarGreenLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Total Purchased',
                      value: '${provider.totalPurchased} Panels',
                      subtext: 'Inward inventory',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.solarAmber,
                      iconBg: AppColors.solarAmberLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total Panels Sold',
                      value: '${provider.totalSold} Panels',
                      subtext: 'Customer dispatches',
                      icon: Icons.shopping_cart_outlined,
                      iconColor: AppColors.primaryBlue,
                      iconBg: AppColors.primaryBlueLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Stock Valuation',
                      value: Formatters.formatCurrency(provider.totalStockValue),
                      subtext: 'Cost basis of stock',
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.solarGreenDark,
                      iconBg: AppColors.solarGreenLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stock by Wattage Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stock Availability by Wattage',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (byWattage.isEmpty)
                        const Text(
                          'No panel inventory recorded yet.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        )
                      else
                        ...byWattage.entries.map((entry) {
                          final wattage = entry.key;
                          final counts = entry.value;
                          final isLow = counts['available']! <= 10;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 65,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlueLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${wattage}W',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Available: ${counts['available']} pcs',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isLow
                                              ? AppColors.solarAmber
                                              : AppColors.solarGreenDark,
                                        ),
                                      ),
                                      Text(
                                        'Sold: ${counts['sold']} pcs | Total inward: ${counts['total']} pcs',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                BadgeWidget(
                                  text: isLow ? 'Low Stock' : 'In Stock',
                                  type: isLow
                                      ? BadgeType.warning
                                      : BadgeType.success,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Recent Transactions Preview
              Consumer2<PurchaseProvider, SaleProvider>(
                builder: (context, pProvider, sProvider, _) {
                  final recentPurchases = pProvider.purchases.take(3).toList();
                  final recentSales = sProvider.sales.take(3).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recent Purchases
                      const Text(
                        'Recent Purchases',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (recentPurchases.isEmpty)
                        const Text('No recent purchases',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary))
                      else
                        ...recentPurchases.map((p) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.arrow_downward,
                                    color: AppColors.solarAmber),
                                title: Text('${p.batchNumber} (${p.wattage}W)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                subtitle: Text(
                                    '${Formatters.formatDate(p.purchaseDate)} • ${p.quantity} panels'),
                                trailing: Text(
                                  Formatters.formatCurrency(
                                      p.totalPurchaseAmount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                              ),
                            )),
                      const SizedBox(height: 16),

                      // Recent Sales
                      const Text(
                        'Recent Sales Dispatches',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (recentSales.isEmpty)
                        const Text('No recent sales',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary))
                      else
                        ...recentSales.map((s) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.arrow_upward,
                                    color: AppColors.solarGreenDark),
                                title: Text(
                                    '${s.customerName ?? 'Customer'} (${s.panelWattage}W)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                subtitle: Text(
                                    'KSEB: ${s.consumerNumber} • ${s.quantity} panels'),
                                trailing: Text(
                                  Formatters.formatCurrency(s.totalSellingAmount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.solarGreenDark,
                                      fontSize: 13),
                                ),
                              ),
                            )),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

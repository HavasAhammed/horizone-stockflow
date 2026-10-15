import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/sale_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/empty_state.dart';
import '../../utils/formatters.dart';
import 'sale_detail_screen.dart';
import 'add_sale_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SaleProvider>().loadSales();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SaleProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Search Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search KSEB consumer, customer, or serial...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => provider.setSearchQuery(val),
                ),
              ),

              // Wattage filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _filterChip(context, provider, 'All Wattages', null),
                    _filterChip(context, provider, '540W', 540),
                    _filterChip(context, provider, '450W', 450),
                    _filterChip(context, provider, '400W', 400),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Sales List
              Expanded(
                child: provider.isLoading && provider.sales.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.sales.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.shopping_cart_outlined,
                            title: 'No Sales Recorded',
                            message:
                                'Record solar panel dispatches and allocate serial numbers to KSEB customers.',
                            buttonText: 'Record First Sale',
                            onButtonPressed: () async {
                              final res = await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AddSaleScreen()),
                              );
                              if (res == true && context.mounted) {
                                provider.loadSales();
                                context.read<DashboardProvider>().loadDashboard();
                              }
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.sales.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final s = provider.sales[index];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SaleDetailScreen(sale: s),
                                      ),
                                    );
                                    provider.loadSales();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              s.customerName ?? 'Customer',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textMain,
                                              ),
                                            ),
                                            BadgeWidget(
                                              text: '${s.panelWattage}W',
                                              type: BadgeType.success,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'KSEB Consumer #: ${s.consumerNumber}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${s.quantity} panels • ${Formatters.formatDate(s.saleDate)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              Formatters.formatCurrency(
                                                  s.totalSellingAmount),
                                              style: const TextStyle(
                                                fontSize: 14,
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
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.solarGreenDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Sale',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddSaleScreen()),
          );
          if (res == true && context.mounted) {
            context.read<SaleProvider>().loadSales();
            context.read<DashboardProvider>().loadDashboard();
            context.read<InventoryProvider>().loadPanels();
          }
        },
      ),
    );
  }

  Widget _filterChip(
      BuildContext context, SaleProvider provider, String label, int? val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: false,
        onSelected: (_) => provider.setWattageFilter(val),
      ),
    );
  }
}

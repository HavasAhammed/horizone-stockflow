import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/empty_state.dart';
import '../../utils/formatters.dart';
import 'purchase_detail_screen.dart';
import 'add_purchase_screen.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().loadPurchases();
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
      body: Consumer<PurchaseProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Top Total Purchases Summary Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.solarAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.solarAmber,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL INWARD PURCHASES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.formatCurrency(provider.totalAmount),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${provider.totalQuantity} Panels • ${provider.purchases.length} Batches',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search batch, supplier, or serial...',
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
              Consumer<InventoryProvider>(
                builder: (context, inventoryProvider, _) {
                  final wattages = <int>{
                    ...provider.distinctWattages,
                    ...inventoryProvider.availableWattages,
                  }.toList()
                    ..sort((a, b) => b.compareTo(a));
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _filterChip(context, provider, 'All Wattages', null),
                        ...wattages.map((w) =>
                            _filterChip(context, provider, '${w}W', w)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Purchases List
              Expanded(
                child: provider.isLoading && provider.purchases.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.purchases.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.inventory_2_outlined,
                            title: 'No Purchases Found',
                            message:
                                'Record an inward shipment of solar panels to populate inventory.',
                            buttonText: 'Add Purchase Batch',
                            onButtonPressed: () async {
                              final res = await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AddPurchaseScreen()),
                              );
                              if (res == true && context.mounted) {
                                provider.loadPurchases();
                                context.read<DashboardProvider>().loadDashboard();
                              }
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.purchases.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final p = provider.purchases[index];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PurchaseDetailScreen(purchase: p),
                                      ),
                                    );
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
                                              p.batchNumber,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textMain,
                                              ),
                                            ),
                                            BadgeWidget(
                                              text: '${p.wattage}W',
                                              type: BadgeType.info,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          p.supplierName ?? 'Supplier reference not recorded',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${p.quantity} panels • ${Formatters.formatDate(p.purchaseDate)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              Formatters.formatCurrency(
                                                  p.totalPurchaseAmount),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textMain,
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
        backgroundColor: AppColors.solarAmber,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Batch', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
          );
          if (res == true && context.mounted) {
            context.read<PurchaseProvider>().loadPurchases();
            context.read<DashboardProvider>().loadDashboard();
            context.read<InventoryProvider>().loadPanels();
          }
        },
      ),
    );
  }

  Widget _filterChip(
      BuildContext context, PurchaseProvider provider, String label, int? val) {
    final isSelected = provider.wattageFilter == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (_) => provider.setWattageFilter(val),
      ),
    );
  }
}

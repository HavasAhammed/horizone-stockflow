import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/empty_state.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
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
      body: Consumer<CustomerProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search consumer #, phone, or name...',
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

              // Customer Directory List
              Expanded(
                child: provider.isLoading && provider.customers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.customers.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.people_outline,
                            title: 'No Customers Found',
                            message:
                                'Add KSEB customer accounts to register solar installations and dispatch panels.',
                            buttonText: 'Add Customer',
                            onButtonPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AddCustomerScreen()),
                              );
                              provider.loadCustomers();
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.customers.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final c = provider.customers[index];
                              return Card(
                                child: ListTile(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CustomerDetailScreen(customer: c),
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryBlueLight,
                                    child: const Icon(Icons.person,
                                        color: AppColors.primaryBlue, size: 22),
                                  ),
                                  title: Text(
                                    c.name ?? 'Unnamed Customer',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 3),
                                      Text(
                                        'KSEB: ${c.consumerNumber}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                      Text(
                                        c.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textSecondary),
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
        heroTag: 'customer_list_fab',
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );
          if (context.mounted) {
            context.read<CustomerProvider>().loadCustomers();
          }
        },
      ),
    );
  }
}

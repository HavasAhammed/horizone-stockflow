import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/confirmation_dialog.dart';
import '../login_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _thresholdController;
  late TextEditingController _apiUrlController;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _thresholdController = TextEditingController(
      text: settings.lowStockThreshold.toString(),
    );
    _apiUrlController = TextEditingController(text: settings.apiBaseUrl);
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String url) async {
    setState(() => _isTestingConnection = true);
    final api = ApiService(baseUrl: url);
    final isHealthy = await api.checkHealth();
    if (!mounted) return;
    setState(() => _isTestingConnection = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isHealthy ? AppColors.solarGreen : AppColors.danger,
        content: Text(
          isHealthy
              ? '✓ Successfully connected to Horizone Cloud API (MongoDB)'
              : '⚠️ Unable to connect to $url. Check URL or internet connection.',
        ),
      ),
    );
  }

  void _refreshAll() {
    context.read<DashboardProvider>().loadDashboard();
    context.read<CustomerProvider>().loadCustomers();
    context.read<PurchaseProvider>().loadPurchases();
    context.read<SaleProvider>().loadSales();
    context.read<InventoryProvider>().loadPanels();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryBlueLight,
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primaryBlue,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Manager',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.watch<AuthProvider>().userEmail ??
                              'user@horizone.com',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        BadgeWidget(
                          text: settings.isOfflineMode
                              ? 'Offline Local Mode'
                              : 'Cloud Sync (MongoDB)',
                          type: settings.isOfflineMode
                              ? BadgeType.neutral
                              : BadgeType.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cloud Database Synchronization Card
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
                        'Cloud Database Sync',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      Switch(
                        value: !settings.isOfflineMode,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (enabled) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final settingsProv = context.read<SettingsProvider>();
                          await settingsProv.updateSettings(
                            settings.copyWith(isOfflineMode: !enabled),
                          );
                          if (!mounted) return;
                          _refreshAll();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                enabled
                                    ? 'Cloud sync enabled. App is connected to MongoDB.'
                                    : 'Offline mode enabled. Changes will stay on this device.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Synchronizes all panel inventory, purchases, and sales in real-time with the web portal.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'API Base URL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiUrlController,
                    decoration: InputDecoration(
                      hintText: 'https://horizone-stockflow.onrender.com/api/v1',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, color: AppColors.primaryBlue),
                        tooltip: 'Save API URL',
                        onPressed: () async {
                          final newUrl = _apiUrlController.text.trim();
                          if (newUrl.isNotEmpty) {
                            final messenger = ScaffoldMessenger.of(context);
                            final settingsProv = context.read<SettingsProvider>();
                            await settingsProv.updateSettings(
                              settings.copyWith(apiBaseUrl: newUrl),
                            );
                            if (!mounted) return;
                            _refreshAll();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('API Base URL updated successfully.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _isTestingConnection
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check, size: 16),
                      label: Text(_isTestingConnection
                          ? 'Checking Server...'
                          : 'Test Cloud Connection'),
                      onPressed: _isTestingConnection
                          ? null
                          : () => _testConnection(_apiUrlController.text.trim()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // App Information Section
          Card(
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.info_outline,
                  title: 'Product',
                  value: 'StockFlow',
                ),
                const Divider(height: 1),
                _settingTile(
                  icon: Icons.solar_power_outlined,
                  title: 'Organization',
                  value: 'Horizone Energy',
                ),
                const Divider(height: 1),
                _settingTile(
                  icon: Icons.cloud_done_outlined,
                  title: 'Shared Database',
                  value: 'MongoDB Atlas',
                ),
                const Divider(height: 1),
                _settingTile(
                  icon: Icons.verified_outlined,
                  title: 'App Version',
                  value: 'v1.0.0 (Release 1)',
                ),
                const Divider(height: 1),
                _settingTile(
                  icon: Icons.currency_rupee,
                  title: 'System Currency',
                  value: 'INR (₹)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Inventory Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory Alerts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Low-stock threshold (panels per wattage):',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _thresholdController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 0) {
                              context.read<SettingsProvider>().updateSettings(
                                settings.copyWith(lowStockThreshold: parsed),
                              );
                              context.read<DashboardProvider>().loadDashboard();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Sign Out Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              onPressed: () async {
                final confirm = await ConfirmationDialog.show(
                  context: context,
                  title: 'Sign Out?',
                  message: 'Are you sure you want to sign out of StockFlow?',
                  confirmText: 'Sign Out',
                  isDestructive: true,
                );
                if (confirm && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBlue, size: 20),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMain,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/dashboard_provider.dart';
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

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _thresholdController =
        TextEditingController(text: settings.lowStockThreshold.toString());
    _apiUrlController = TextEditingController(text: settings.apiBaseUrl);
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
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
                    child: const Icon(Icons.person,
                        color: AppColors.primaryBlue, size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Manager (Local Admin)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.watch<AuthProvider>().userEmail ?? 'user@gmail.com',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const BadgeWidget(
                          text: 'Offline Local Operator',
                          type: BadgeType.info,
                        ),
                      ],
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
                  value: 'Horizone StockFlow',
                ),
                const Divider(height: 1),
                _settingTile(
                  icon: Icons.solar_power_outlined,
                  title: 'Organization',
                  value: 'Horizone Energy',
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
                                    settings.copyWith(
                                        lowStockThreshold: parsed),
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
          const SizedBox(height: 16),

          // Backend API Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend API Endpoint',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configured URL for future multi-device synchronization:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _apiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'http://localhost:5050/api/v1',
                      prefixIcon: Icon(Icons.cloud_outlined),
                    ),
                    onSubmitted: (val) {
                      context.read<SettingsProvider>().updateSettings(
                            settings.copyWith(apiBaseUrl: val.trim()),
                          );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Storage Mode & Architectural Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.solarAmberLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.solarAmber.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppColors.solarAmber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Local Storage Notice',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Hive offline local storage is currently active on this device. Data is securely persisted on this device between app restarts. Hive data on one device is not automatically shared with another device or the website until the shared database (PostgreSQL/MongoDB) is connected.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
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
                  message: 'Are you sure you want to sign out of Horizone StockFlow?',
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
      title: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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

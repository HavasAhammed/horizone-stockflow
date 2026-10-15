import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'home_screen.dart';
import 'sales/sales_list_screen.dart';
import 'purchase/purchase_list_screen.dart';
import 'customer/customer_list_screen.dart';
import 'settings/profile_settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SalesListScreen(),
    PurchaseListScreen(),
    CustomerListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/branding/logo.png',
              height: 32,
              errorBuilder: (_, error, stackTrace) => const Icon(
                Icons.solar_power,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Horizone StockFlow',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  'Solar Inventory Management',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            tooltip: 'Profile & Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryBlue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppColors.primaryBlue),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.primaryBlue),
            label: 'Purchase',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.primaryBlue),
            label: 'Customer',
          ),
        ],
      ),
    );
  }
}

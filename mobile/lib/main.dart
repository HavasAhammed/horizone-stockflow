import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'repositories/customer_repository.dart';
import 'repositories/purchase_repository.dart';
import 'repositories/sale_repository.dart';
import 'repositories/panel_repository.dart';
import 'repositories/settings_repository.dart';
import 'services/inventory_service.dart';

import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/sale_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/settings_provider.dart';

import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive offline persistence
  await Hive.initFlutter();

  // Open Hive boxes
  await Hive.openBox(AuthProvider.boxName);
  await Hive.openBox(HiveCustomerRepository.boxName);
  await Hive.openBox(HivePurchaseRepository.boxName);
  await Hive.openBox(HiveSaleRepository.boxName);
  await Hive.openBox(HivePanelRepository.boxName);
  await Hive.openBox(HiveSettingsRepository.boxName);

  // Initialize Repositories
  final customerRepo = HiveCustomerRepository();
  final purchaseRepo = HivePurchaseRepository();
  final saleRepo = HiveSaleRepository();
  final panelRepo = HivePanelRepository();
  final settingsRepo = HiveSettingsRepository();

  // Initialize Centralized Inventory Service
  final inventoryService = InventoryService(
    customerRepository: customerRepo,
    purchaseRepository: purchaseRepo,
    saleRepository: saleRepo,
    panelRepository: panelRepo,
    settingsRepository: settingsRepo,
  );

  // Seed sample data on first run for out-of-the-box demonstration
  await inventoryService.seedIfEmpty();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsRepository: settingsRepo)..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(inventoryService: inventoryService)..loadDashboard(),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomerProvider(inventoryService: inventoryService)..loadCustomers(),
        ),
        ChangeNotifierProvider(
          create: (_) => PurchaseProvider(inventoryService: inventoryService)..loadPurchases(),
        ),
        ChangeNotifierProvider(
          create: (_) => SaleProvider(inventoryService: inventoryService)..loadSales(),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(inventoryService: inventoryService)..loadPanels(),
        ),
      ],
      child: const HorizoneStockFlowApp(),
    ),
  );
}

class HorizoneStockFlowApp extends StatelessWidget {
  const HorizoneStockFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizone StockFlow',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../services/inventory_service.dart';

class DashboardProvider extends ChangeNotifier {
  final InventoryService inventoryService;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _metrics;

  DashboardProvider({required this.inventoryService});

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get metrics => _metrics;

  int get totalAvailable => (_metrics?['totalAvailable'] as int?) ?? 0;
  int get totalPurchased => (_metrics?['totalPurchased'] as int?) ?? 0;
  int get totalSold => (_metrics?['totalSold'] as int?) ?? 0;
  double get totalPurchaseAmount =>
      (_metrics?['totalPurchaseAmount'] as double?) ?? 0.0;
  double get totalSalesAmount =>
      (_metrics?['totalSalesAmount'] as double?) ?? 0.0;
  double get totalStockValue => (_metrics?['totalStockValue'] as double?) ?? 0.0;
  Map<int, Map<String, dynamic>> get byWattage =>
      (_metrics?['byWattage'] as Map<int, Map<String, dynamic>>?) ?? {};
  List<Map<String, dynamic>> get lowStockAlerts =>
      (_metrics?['lowStockAlerts'] as List<Map<String, dynamic>>?) ?? [];

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _metrics = await inventoryService.getDashboardMetrics();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

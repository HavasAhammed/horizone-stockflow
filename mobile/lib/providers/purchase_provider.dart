import 'package:flutter/foundation.dart';
import '../models/purchase.dart';
import '../services/inventory_service.dart';

class PurchaseProvider extends ChangeNotifier {
  final InventoryService inventoryService;

  List<PurchaseTransaction> _purchases = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  int? _wattageFilter;

  PurchaseProvider({required this.inventoryService});

  List<PurchaseTransaction> get purchases {
    List<PurchaseTransaction> list = _purchases;
    if (_wattageFilter != null) {
      list = list.where((p) => p.wattage == _wattageFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.batchNumber.toLowerCase().contains(q) ||
            (p.supplierName != null && p.supplierName!.toLowerCase().contains(q)) ||
            p.serialNumbers.any((sn) => sn.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get wattageFilter => _wattageFilter;
  List<PurchaseTransaction> get allPurchases => _purchases;

  int get totalQuantity => purchases.fold(0, (sum, p) => sum + p.quantity);
  double get totalAmount =>
      purchases.fold(0.0, (sum, p) => sum + p.totalPurchaseAmount);
  int get allTotalQuantity => _purchases.fold(0, (sum, p) => sum + p.quantity);
  double get allTotalAmount =>
      _purchases.fold(0.0, (sum, p) => sum + p.totalPurchaseAmount);

  List<int> get distinctWattages {
    final set = <int>{540, 450, 400, 330};
    for (final p in _purchases) {
      set.add(p.wattage);
    }
    final list = set.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setWattageFilter(int? wattage) {
    _wattageFilter = wattage;
    notifyListeners();
  }

  Future<void> loadPurchases() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _purchases = await inventoryService.getPurchases();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PurchaseTransaction> addPurchase({
    DateTime? purchaseDate,
    String? supplierName,
    required String batchNumber,
    required int wattage,
    required int quantity,
    required List<String> serialNumbers,
    required double unitPurchasePrice,
    String? notes,
  }) async {
    final p = await inventoryService.createPurchase(
      purchaseDate: purchaseDate,
      supplierName: supplierName,
      batchNumber: batchNumber,
      wattage: wattage,
      quantity: quantity,
      serialNumbers: serialNumbers,
      unitPurchasePrice: unitPurchasePrice,
      notes: notes,
    );
    await loadPurchases();
    return p;
  }

  Future<void> deletePurchase(String id) async {
    await inventoryService.deletePurchase(id);
    await loadPurchases();
  }
}

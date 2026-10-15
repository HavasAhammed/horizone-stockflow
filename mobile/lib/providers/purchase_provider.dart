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
      _purchases = await inventoryService.purchaseRepository.getAllPurchases();
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

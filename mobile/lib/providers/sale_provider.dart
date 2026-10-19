import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../services/inventory_service.dart';

class SaleProvider extends ChangeNotifier {
  final InventoryService inventoryService;

  List<SaleTransaction> _sales = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  int? _wattageFilter;

  SaleProvider({required this.inventoryService});

  List<SaleTransaction> get sales {
    List<SaleTransaction> list = _sales;
    if (_wattageFilter != null) {
      list = list.where((s) => s.panelWattage == _wattageFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return s.consumerNumber.toLowerCase().contains(q) ||
            (s.customerName != null && s.customerName!.toLowerCase().contains(q)) ||
            s.serialNumbers.any((sn) => sn.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get wattageFilter => _wattageFilter;
  List<SaleTransaction> get allSales => _sales;

  int get totalQuantity => sales.fold(0, (sum, s) => sum + s.quantity);
  double get totalAmount =>
      sales.fold(0.0, (sum, s) => sum + s.totalSellingAmount);
  int get allTotalQuantity => _sales.fold(0, (sum, s) => sum + s.quantity);
  double get allTotalAmount =>
      _sales.fold(0.0, (sum, s) => sum + s.totalSellingAmount);

  List<int> get distinctWattages {
    final set = <int>{540, 450, 400, 330};
    for (final s in _sales) {
      set.add(s.panelWattage);
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

  Future<void> loadSales() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sales = await inventoryService.saleRepository.getAllSales();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SaleTransaction> addSale({
    DateTime? saleDate,
    required String customerId,
    required int panelWattage,
    required List<String> serialNumbers,
    required double unitSellingPrice,
    String? notes,
  }) async {
    final s = await inventoryService.createSale(
      saleDate: saleDate,
      customerId: customerId,
      panelWattage: panelWattage,
      serialNumbers: serialNumbers,
      unitSellingPrice: unitSellingPrice,
      notes: notes,
    );
    await loadSales();
    return s;
  }

  Future<void> deleteSale(String id) async {
    await inventoryService.deleteSale(id);
    await loadSales();
  }
}

import 'package:flutter/foundation.dart';
import '../models/panel_item.dart';
import '../services/inventory_service.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryService inventoryService;

  List<PanelItem> _panels = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  int? _wattageFilter;
  PanelStatus? _statusFilter;

  InventoryProvider({required this.inventoryService});

  List<PanelItem> get panels {
    List<PanelItem> list = _panels;
    if (_wattageFilter != null) {
      list = list.where((p) => p.wattage == _wattageFilter).toList();
    }
    if (_statusFilter != null) {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.serialNumber.toLowerCase().contains(q) ||
            p.batchNumber.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  List<PanelItem> get allPanels => _panels;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get wattageFilter => _wattageFilter;
  PanelStatus? get statusFilter => _statusFilter;

  /// Returns all distinct wattages present in inventory panels plus standard default wattages [540, 450, 400, 330], sorted descending.
  List<int> get availableWattages {
    final set = <int>{540, 450, 400, 330};
    for (final p in _panels) {
      set.add(p.wattage);
    }
    final list = set.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Returns the number of currently available panels for a given wattage.
  int getAvailableCount(int wattage) {
    return _panels.where((p) => p.wattage == wattage && p.isAvailable).length;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setWattageFilter(int? wattage) {
    _wattageFilter = wattage;
    notifyListeners();
  }

  void setStatusFilter(PanelStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  Future<void> loadPanels() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _panels = await inventoryService.panelRepository.getAllPanels();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage) async {
    return inventoryService.panelRepository.getAvailablePanelsByWattage(wattage);
  }
}

import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../services/inventory_service.dart';

class CustomerProvider extends ChangeNotifier {
  final InventoryService inventoryService;

  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  CustomerProvider({required this.inventoryService});

  List<Customer> get customers {
    if (_searchQuery.isEmpty) return _customers;
    final q = _searchQuery.toLowerCase();
    return _customers.where((c) {
      return c.consumerNumber.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          (c.name != null && c.name!.toLowerCase().contains(q));
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _customers = await inventoryService.customerRepository.getAllCustomers();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer> addCustomer({
    required String consumerNumber,
    required String phone,
    String? name,
    String? address,
  }) async {
    final customer = await inventoryService.createCustomer(
      consumerNumber: consumerNumber,
      phone: phone,
      name: name,
      address: address,
    );
    await loadCustomers();
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    await inventoryService.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await inventoryService.deleteCustomer(id);
    await loadCustomers();
  }

  Future<List<SaleTransaction>> getCustomerSales(String customerId) async {
    return inventoryService.saleRepository.getSalesByCustomerId(customerId);
  }
}

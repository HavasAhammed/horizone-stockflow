import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import '../models/panel_item.dart';
import '../models/purchase.dart';
import '../models/sale.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  String baseUrl;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);

  ApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? 'https://horizone-stockflow.onrender.com/api/v1')
            .replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$baseUrl$cleanEndpoint';
    final uri = Uri.parse(fullUrl);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  dynamic _handleResponse(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    }

    String errorMsg = 'Server error (${res.statusCode})';
    if (body is Map && body['error'] != null) {
      errorMsg = body['error'].toString();
    } else if (body is Map && body['message'] != null) {
      errorMsg = body['message'].toString();
    }
    throw ApiException(errorMsg, res.statusCode);
  }

  // ==========================================
  // HEALTH & CONNECTIVITY
  // ==========================================
  Future<bool> checkHealth() async {
    try {
      final res = await _client.get(_uri('/health'), headers: _headers).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // CUSTOMERS
  // ==========================================
  Future<List<Customer>> getCustomers({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final res = await _client.get(_uri('/customers', params), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    return data.map((item) => Customer.fromMap(item as Map<dynamic, dynamic>)).toList();
  }

  Future<Customer> getCustomerById(String id) async {
    final res = await _client.get(_uri('/customers/$id'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return Customer.fromMap(data);
  }

  Future<List<SaleTransaction>> getCustomerSales(String customerId) async {
    final res = await _client.get(_uri('/sales', {'customerId': customerId}), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    return data.map((item) => SaleTransaction.fromMap(item as Map<dynamic, dynamic>)).toList();
  }

  Future<Customer> createCustomer({
    required String consumerNumber,
    required String phone,
    String? name,
    String? address,
  }) async {
    final payload = jsonEncode({
      'consumerNumber': consumerNumber.trim(),
      'phone': phone.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
    });

    final res = await _client.post(_uri('/customers'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return Customer.fromMap(data);
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final payload = jsonEncode({
      'consumerNumber': customer.consumerNumber.trim(),
      'phone': customer.phone.trim(),
      'name': customer.name?.trim(),
      'address': customer.address?.trim(),
    });

    final res = await _client.put(_uri('/customers/${customer.id}'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return Customer.fromMap(data);
  }

  Future<void> deleteCustomer(String id) async {
    final res = await _client.delete(_uri('/customers/$id'), headers: _headers).timeout(_timeout);
    _handleResponse(res);
  }

  // ==========================================
  // PURCHASES (INWARD SHIPMENTS)
  // ==========================================
  Future<List<PurchaseTransaction>> getPurchases({
    String? batch,
    int? wattage,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (batch != null && batch.isNotEmpty) params['batch'] = batch;
    if (wattage != null) params['wattage'] = wattage;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await _client.get(_uri('/purchases', params), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    return data.map((item) => PurchaseTransaction.fromMap(item as Map<dynamic, dynamic>)).toList();
  }

  Future<PurchaseTransaction> getPurchaseById(String id) async {
    final res = await _client.get(_uri('/purchases/$id'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return PurchaseTransaction.fromMap(data);
  }

  Future<PurchaseTransaction> createPurchase({
    DateTime? purchaseDate,
    String? supplierName,
    required String batchNumber,
    required int wattage,
    required int quantity,
    required List<String> serialNumbers,
    required double unitPurchasePrice,
    String? notes,
  }) async {
    final payload = jsonEncode({
      'purchaseDate': (purchaseDate ?? DateTime.now()).toIso8601String(),
      if (supplierName != null && supplierName.trim().isNotEmpty) 'supplierName': supplierName.trim(),
      'batchNumber': batchNumber.trim(),
      'wattage': wattage,
      'quantity': quantity,
      'serialNumbers': serialNumbers,
      'unitPurchasePrice': unitPurchasePrice,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });

    final res = await _client.post(_uri('/purchases'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return PurchaseTransaction.fromMap(data);
  }

  Future<PurchaseTransaction> updatePurchase(
    String id, {
    DateTime? purchaseDate,
    String? supplierName,
    String? batchNumber,
    double? unitPurchasePrice,
    String? notes,
    List<String>? serialNumbers,
  }) async {
    final payload = jsonEncode({
      if (purchaseDate != null) 'purchaseDate': purchaseDate.toIso8601String(),
      if (supplierName != null && supplierName.trim().isNotEmpty) 'supplierName': supplierName.trim(),
      if (batchNumber != null && batchNumber.trim().isNotEmpty) 'batchNumber': batchNumber.trim(),
      'unitPurchasePrice': ?unitPurchasePrice,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'serialNumbers': ?serialNumbers,
    });

    final res = await _client.put(_uri('/purchases/$id'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return PurchaseTransaction.fromMap(data);
  }

  Future<PurchaseTransaction> addPanelsToPurchase(String id, List<String> serialNumbers) async {
    final payload = jsonEncode({
      'serialNumbers': serialNumbers,
    });
    final res = await _client.post(_uri('/purchases/$id/panels'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return PurchaseTransaction.fromMap(data);
  }

  Future<PurchaseTransaction> updatePanelSerial(String id, String oldSerial, String newSerial) async {
    final payload = jsonEncode({
      'newSerialNumber': newSerial.trim().toUpperCase(),
    });
    final res = await _client.put(_uri('/purchases/$id/panels/$oldSerial'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return PurchaseTransaction.fromMap(data);
  }

  Future<PurchaseTransaction> deletePanelFromPurchase(String id, String serial) async {
    final res = await _client.delete(_uri('/purchases/$id/panels/$serial'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return PurchaseTransaction.fromMap(data);
  }

  Future<void> deletePurchase(String id) async {
    final res = await _client.delete(_uri('/purchases/$id'), headers: _headers).timeout(_timeout);
    _handleResponse(res);
  }

  // ==========================================
  // SALES (OUTWARD DISPATCHES)
  // ==========================================
  Future<List<SaleTransaction>> getSales({
    String? customerId,
    int? wattage,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (customerId != null && customerId.isNotEmpty) params['customerId'] = customerId;
    if (wattage != null) params['wattage'] = wattage;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await _client.get(_uri('/sales', params), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    return data.map((item) => SaleTransaction.fromMap(item as Map<dynamic, dynamic>)).toList();
  }

  Future<SaleTransaction> getSaleById(String id) async {
    final res = await _client.get(_uri('/sales/$id'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return SaleTransaction.fromMap(data);
  }

  Future<SaleTransaction> createSale({
    DateTime? saleDate,
    required String customerId,
    required int panelWattage,
    required List<String> serialNumbers,
    required double unitSellingPrice,
    String? notes,
  }) async {
    final payload = jsonEncode({
      'saleDate': (saleDate ?? DateTime.now()).toIso8601String(),
      'customerId': customerId,
      'panelWattage': panelWattage,
      'serialNumbers': serialNumbers,
      'unitSellingPrice': unitSellingPrice,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });

    final res = await _client.post(_uri('/sales'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return SaleTransaction.fromMap(data);
  }

  Future<SaleTransaction> updateSale(
    String id, {
    DateTime? saleDate,
    String? customerId,
    double? unitSellingPrice,
    List<String>? serialNumbers,
    String? notes,
  }) async {
    final payload = jsonEncode({
      if (saleDate != null) 'saleDate': saleDate.toIso8601String(),
      'customerId': ?customerId,
      'unitSellingPrice': ?unitSellingPrice,
      'serialNumbers': ?serialNumbers,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });

    final res = await _client.put(_uri('/sales/$id'), headers: _headers, body: payload).timeout(_timeout);
    final data = _handleResponse(res) as Map;
    return SaleTransaction.fromMap(data);
  }

  Future<void> deleteSale(String id) async {
    final res = await _client.delete(_uri('/sales/$id'), headers: _headers).timeout(_timeout);
    _handleResponse(res);
  }

  // ==========================================
  // INVENTORY
  // ==========================================
  Future<List<PanelItem>> getInventory({
    int? wattage,
    String? batch,
    String? status,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (wattage != null) params['wattage'] = wattage;
    if (batch != null && batch.isNotEmpty) params['batch'] = batch;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await _client.get(_uri('/inventory', params), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    return data.map((item) => PanelItem.fromMap(item as Map<dynamic, dynamic>)).toList();
  }

  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage) async {
    final res = await _client.get(_uri('/inventory/available/$wattage'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    return data.map((item) => PanelItem.fromMap(item as Map<dynamic, dynamic>)).toList();
  }

  Future<Map<int, Map<String, dynamic>>> getStockByWattage() async {
    final res = await _client.get(_uri('/inventory/by-wattage'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as List;
    final Map<int, Map<String, dynamic>> result = {};

    for (final item in data) {
      final map = item as Map<dynamic, dynamic>;
      final wattage = ((map['wattage'] ?? 0) as num).toInt();
      result[wattage] = {
        'available': ((map['availableCount'] ?? 0) as num).toInt(),
        'sold': ((map['soldCount'] ?? 0) as num).toInt(),
        'total': ((map['totalCount'] ?? 0) as num).toInt(),
        'availableAmount': ((map['availableAmount'] ?? 0.0) as num).toDouble(),
        'lowStockAlert': map['lowStockAlert'] == true,
      };
    }
    return result;
  }

  // ==========================================
  // DASHBOARD SUMMARY
  // ==========================================
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final res = await _client.get(_uri('/dashboard'), headers: _headers).timeout(_timeout);
    final data = _handleResponse(res) as Map<dynamic, dynamic>;

    // Normalize keys so mobile DashboardProvider receives expected fields
    final Map<int, Map<String, dynamic>> byWattage = {};
    if (data['stockByWattage'] is List) {
      for (final item in (data['stockByWattage'] as List)) {
        final map = item as Map<dynamic, dynamic>;
        final wattage = ((map['wattage'] ?? 0) as num).toInt();
        byWattage[wattage] = {
          'available': ((map['availableCount'] ?? 0) as num).toInt(),
          'sold': ((map['soldCount'] ?? 0) as num).toInt(),
          'total': ((map['totalCount'] ?? 0) as num).toInt(),
          'availableAmount': ((map['availableAmount'] ?? 0.0) as num).toDouble(),
        };
      }
    }

    final List<Map<String, dynamic>> lowStockAlerts = [];
    if (data['lowStockWarnings'] is List) {
      for (final item in (data['lowStockWarnings'] as List)) {
        final map = item as Map<dynamic, dynamic>;
        lowStockAlerts.add({
          'wattage': ((map['wattage'] ?? 0) as num).toInt(),
          'available': ((map['availableCount'] ?? 0) as num).toInt(),
          'threshold': ((map['threshold'] ?? 100) as num).toInt(),
        });
      }
    }

    final recentPurchases = (data['recentPurchases'] is List)
        ? (data['recentPurchases'] as List)
            .map((p) => PurchaseTransaction.fromMap(p as Map<dynamic, dynamic>))
            .toList()
        : <PurchaseTransaction>[];

    final recentSales = (data['recentSales'] is List)
        ? (data['recentSales'] as List)
            .map((s) => SaleTransaction.fromMap(s as Map<dynamic, dynamic>))
            .toList()
        : <SaleTransaction>[];

    return {
      'totalAvailable': ((data['totalAvailablePanels'] ?? 0) as num).toInt(),
      'totalPurchased': ((data['totalPurchasedPanels'] ?? 0) as num).toInt(),
      'totalSold': ((data['totalSoldPanels'] ?? 0) as num).toInt(),
      'totalPurchaseAmount': ((data['totalPurchaseAmount'] ?? 0.0) as num).toDouble(),
      'totalSalesAmount': ((data['totalSalesAmount'] ?? 0.0) as num).toDouble(),
      'totalStockValue': ((data['totalStockValue'] ?? 0.0) as num).toDouble(),
      'byWattage': byWattage,
      'lowStockAlerts': lowStockAlerts,
      'recentPurchases': recentPurchases,
      'recentSales': recentSales,
    };
  }
}

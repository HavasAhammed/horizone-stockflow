import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/panel_item.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../repositories/customer_repository.dart';
import '../repositories/panel_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/settings_repository.dart';
import 'api_service.dart';

class InventoryService {
  final CustomerRepository customerRepository;
  final PurchaseRepository purchaseRepository;
  final SaleRepository saleRepository;
  final PanelRepository panelRepository;
  final SettingsRepository settingsRepository;
  final ApiService? apiService;

  final Uuid _uuid = const Uuid();

  InventoryService({
    required this.customerRepository,
    required this.purchaseRepository,
    required this.saleRepository,
    required this.panelRepository,
    required this.settingsRepository,
    this.apiService,
  });

  Future<bool> _shouldUseApi() async {
    if (apiService == null) return false;
    final settings = await settingsRepository.getSettings();
    apiService!.baseUrl = settings.apiBaseUrl;
    return !settings.isOfflineMode;
  }

  // ==========================================
  // CUSTOMER OPERATIONS & INVARIANTS
  // ==========================================
  Future<List<Customer>> getCustomers({String? search}) async {
    if (await _shouldUseApi()) {
      try {
        final list = await apiService!.getCustomers(search: search);
        for (final c in list) {
          await customerRepository.saveCustomer(c);
        }
        return list;
      } catch (_) {
        return customerRepository.getAllCustomers();
      }
    }
    return customerRepository.getAllCustomers();
  }

  Future<List<SaleTransaction>> getCustomerSales(String customerId) async {
    if (await _shouldUseApi()) {
      try {
        return await apiService!.getCustomerSales(customerId);
      } catch (_) {}
    }
    return saleRepository.getSalesByCustomerId(customerId);
  }

  Future<Customer> createCustomer({
    required String consumerNumber,
    required String phone,
    String? name,
    String? address,
  }) async {
    final trimmedConsumer = consumerNumber.trim();
    final trimmedPhone = phone.trim();

    if (trimmedConsumer.isEmpty) {
      throw ArgumentError('KSEB consumer number is mandatory.');
    }
    if (trimmedPhone.isEmpty) {
      throw ArgumentError('Phone number is mandatory.');
    }

    if (await _shouldUseApi()) {
      final customer = await apiService!.createCustomer(
        consumerNumber: trimmedConsumer,
        phone: trimmedPhone,
        name: name,
        address: address,
      );
      await customerRepository.saveCustomer(customer);
      return customer;
    }

    final existing =
        await customerRepository.getCustomerByConsumerNumber(trimmedConsumer);
    if (existing != null) {
      throw StateError(
          'A customer with KSEB consumer number "$trimmedConsumer" already exists.');
    }

    final customer = Customer(
      id: _uuid.v4(),
      consumerNumber: trimmedConsumer,
      phone: trimmedPhone,
      name: name?.trim().isEmpty == true ? null : name?.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
    );

    await customerRepository.saveCustomer(customer);
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    final trimmedConsumer = customer.consumerNumber.trim();
    final trimmedPhone = customer.phone.trim();

    if (trimmedConsumer.isEmpty) {
      throw ArgumentError('KSEB consumer number cannot be empty.');
    }
    if (trimmedPhone.isEmpty) {
      throw ArgumentError('Phone number cannot be empty.');
    }

    if (await _shouldUseApi()) {
      final updated = await apiService!.updateCustomer(customer);
      await customerRepository.saveCustomer(updated);
      return;
    }

    final existing =
        await customerRepository.getCustomerByConsumerNumber(trimmedConsumer);
    if (existing != null && existing.id != customer.id) {
      throw StateError(
          'KSEB consumer number "$trimmedConsumer" is already used by another customer.');
    }

    final updated = customer.copyWith(
      consumerNumber: trimmedConsumer,
      phone: trimmedPhone,
      name: customer.name?.trim().isEmpty == true ? null : customer.name?.trim(),
      address: customer.address?.trim().isEmpty == true
          ? null
          : customer.address?.trim(),
      updatedAt: DateTime.now(),
    );

    await customerRepository.saveCustomer(updated);
  }

  Future<void> deleteCustomer(String id) async {
    if (await _shouldUseApi()) {
      await apiService!.deleteCustomer(id);
      await customerRepository.deleteCustomer(id);
      return;
    }

    final customer = await customerRepository.getCustomerById(id);
    if (customer == null) {
      throw StateError('Customer not found.');
    }

    // Safety rule: Prevent deletion if customer has linked sales
    final linkedSales = await saleRepository.getSalesByCustomerId(id);
    if (linkedSales.isNotEmpty) {
      throw StateError(
          'Cannot delete customer "${customer.name ?? customer.consumerNumber}". There are ${linkedSales.length} linked solar sale(s) on record. Archival or sale cancellation is required first.');
    }

    await customerRepository.deleteCustomer(id);
  }

  // ==========================================
  // PURCHASE OPERATIONS & INVARIANTS
  // ==========================================
  Future<List<PurchaseTransaction>> getPurchases({
    String? batch,
    int? wattage,
    String? search,
  }) async {
    if (await _shouldUseApi()) {
      try {
        final list = await apiService!.getPurchases(
          batch: batch,
          wattage: wattage,
          search: search,
        );
        for (final p in list) {
          await purchaseRepository.savePurchase(p);
        }
        return list;
      } catch (_) {
        return purchaseRepository.getAllPurchases();
      }
    }
    return purchaseRepository.getAllPurchases();
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
    final trimmedBatch = batchNumber.trim();
    if (trimmedBatch.isEmpty) {
      throw ArgumentError('Batch number is required.');
    }
    if (wattage <= 0) {
      throw ArgumentError('Panel wattage must be a positive integer in Watts.');
    }
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be a positive integer.');
    }
    if (unitPurchasePrice < 0) {
      throw ArgumentError('Unit purchase price cannot be negative.');
    }

    final cleanSerials = serialNumbers
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (cleanSerials.length != quantity) {
      throw ArgumentError(
          'Serial numbers count (${cleanSerials.length}) must match purchase quantity ($quantity).');
    }

    if (await _shouldUseApi()) {
      final purchase = await apiService!.createPurchase(
        purchaseDate: purchaseDate,
        supplierName: supplierName,
        batchNumber: trimmedBatch,
        wattage: wattage,
        quantity: quantity,
        serialNumbers: cleanSerials,
        unitPurchasePrice: unitPurchasePrice,
        notes: notes,
      );
      await purchaseRepository.savePurchase(purchase);

      final List<PanelItem> panels = cleanSerials.map((sn) {
        return PanelItem(
          id: sn,
          serialNumber: sn,
          batchNumber: trimmedBatch,
          wattage: wattage,
          purchaseId: purchase.id,
          purchasePrice: unitPurchasePrice,
          status: PanelStatus.available,
          saleId: null,
          createdAt: purchaseDate ?? DateTime.now(),
          updatedAt: purchaseDate ?? DateTime.now(),
        );
      }).toList();
      await panelRepository.savePanels(panels);

      return purchase;
    }

    // Duplicate check within submitted batch
    final uniqueSerials = <String>{};
    for (final sn in cleanSerials) {
      final upper = sn.toUpperCase();
      if (uniqueSerials.contains(upper)) {
        throw StateError('Duplicate serial number in batch entry: "$sn".');
      }
      uniqueSerials.add(upper);
    }

    // Duplicate check across overall inventory
    for (final sn in cleanSerials) {
      final existing = await panelRepository.getPanelBySerialNumber(sn);
      if (existing != null) {
        throw StateError(
            'Serial number "$sn" already exists in inventory (Batch: ${existing.batchNumber}, Status: ${existing.status.name}).');
      }
    }

    final pDate = purchaseDate ?? DateTime.now();
    final totalAmount = quantity * unitPurchasePrice;
    final purchase = PurchaseTransaction(
      id: _uuid.v4(),
      purchaseDate: pDate,
      supplierName: supplierName?.trim().isEmpty == true ? null : supplierName?.trim(),
      batchNumber: trimmedBatch,
      wattage: wattage,
      quantity: quantity,
      serialNumbers: cleanSerials,
      unitPurchasePrice: unitPurchasePrice,
      totalPurchaseAmount: totalAmount,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await purchaseRepository.savePurchase(purchase);

    // Atomically create individual panel items
    final List<PanelItem> panels = cleanSerials.map((sn) {
      return PanelItem(
        id: _uuid.v4(),
        serialNumber: sn,
        batchNumber: trimmedBatch,
        wattage: wattage,
        purchaseId: purchase.id,
        purchasePrice: unitPurchasePrice,
        status: PanelStatus.available,
        saleId: null,
        createdAt: pDate,
        updatedAt: pDate,
      );
    }).toList();

    await panelRepository.savePanels(panels);
    return purchase;
  }

  Future<void> deletePurchase(String purchaseId) async {
    if (await _shouldUseApi()) {
      final local = await purchaseRepository.getPurchaseById(purchaseId);
      await apiService!.deletePurchase(purchaseId);
      if (local != null) {
        await panelRepository.deletePanels(local.serialNumbers);
      }
      await purchaseRepository.deletePurchase(purchaseId);
      return;
    }

    final purchase = await purchaseRepository.getPurchaseById(purchaseId);
    if (purchase == null) throw StateError('Purchase record not found.');

    // Safety rule: Cannot delete if any panel was already sold
    for (final sn in purchase.serialNumbers) {
      final panel = await panelRepository.getPanelBySerialNumber(sn);
      if (panel != null && panel.isSold) {
        throw StateError(
            'Cannot delete purchase "$purchaseId". Panel "$sn" has already been sold in sale "${panel.saleId}". Delete or reconcile the sale first.');
      }
    }

    // Safe to delete: delete all associated panels
    await panelRepository.deletePanels(purchase.serialNumbers);
    await purchaseRepository.deletePurchase(purchaseId);
  }

  // ==========================================
  // SALE OPERATIONS & INVARIANTS
  // ==========================================
  Future<List<SaleTransaction>> getSales({
    String? customerId,
    int? wattage,
    String? search,
  }) async {
    if (await _shouldUseApi()) {
      try {
        final list = await apiService!.getSales(
          customerId: customerId,
          wattage: wattage,
          search: search,
        );
        for (final s in list) {
          await saleRepository.saveSale(s);
        }
        return list;
      } catch (_) {
        return saleRepository.getAllSales();
      }
    }
    return saleRepository.getAllSales();
  }

  Future<SaleTransaction> createSale({
    DateTime? saleDate,
    required String customerId,
    required int panelWattage,
    required List<String> serialNumbers,
    required double unitSellingPrice,
    String? notes,
  }) async {
    if (panelWattage <= 0) {
      throw ArgumentError('Wattage must be a positive integer.');
    }
    if (unitSellingPrice < 0) {
      throw ArgumentError('Unit selling price cannot be negative.');
    }

    final cleanSerials = serialNumbers
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (cleanSerials.isEmpty) {
      throw ArgumentError('At least one panel serial must be selected.');
    }

    if (await _shouldUseApi()) {
      final sale = await apiService!.createSale(
        saleDate: saleDate,
        customerId: customerId,
        panelWattage: panelWattage,
        serialNumbers: cleanSerials,
        unitSellingPrice: unitSellingPrice,
        notes: notes,
      );
      await saleRepository.saveSale(sale);

      for (final sn in cleanSerials) {
        final panel = await panelRepository.getPanelBySerialNumber(sn);
        if (panel != null) {
          await panelRepository.savePanel(panel.copyWith(
            status: PanelStatus.sold,
            saleId: sale.id,
            updatedAt: DateTime.now(),
          ));
        }
      }
      return sale;
    }

    final customer = await customerRepository.getCustomerById(customerId);
    if (customer == null) {
      throw StateError('Selected customer not found.');
    }

    // Verify all selected panels exist, match wattage, and are currently available
    final List<PanelItem> panelsToSell = [];
    for (final sn in cleanSerials) {
      final panel = await panelRepository.getPanelBySerialNumber(sn);
      if (panel == null) {
        throw StateError('Panel serial "$sn" not found in inventory.');
      }
      if (!panel.isAvailable) {
        throw StateError(
            'Panel serial "$sn" is already sold/dispatched. Cannot be sold again.');
      }
      if (panel.wattage != panelWattage) {
        throw StateError(
            'Panel serial "$sn" is ${panel.wattage}W, expected $panelWattage W.');
      }
      panelsToSell.add(panel);
    }

    final sDate = saleDate ?? DateTime.now();
    final quantity = cleanSerials.length;
    final totalSellingAmount = quantity * unitSellingPrice;

    final sale = SaleTransaction(
      id: _uuid.v4(),
      saleDate: sDate,
      customerId: customer.id,
      consumerNumber: customer.consumerNumber,
      customerName: customer.name,
      panelWattage: panelWattage,
      quantity: quantity,
      serialNumbers: cleanSerials,
      unitSellingPrice: unitSellingPrice,
      totalSellingAmount: totalSellingAmount,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saleRepository.saveSale(sale);

    // Atomically mark panels as sold
    final updatedPanels = panelsToSell.map((p) {
      return p.copyWith(
        status: PanelStatus.sold,
        saleId: sale.id,
        updatedAt: DateTime.now(),
      );
    }).toList();

    await panelRepository.savePanels(updatedPanels);
    return sale;
  }

  Future<void> deleteSale(String saleId) async {
    if (await _shouldUseApi()) {
      final local = await saleRepository.getSaleById(saleId);
      await apiService!.deleteSale(saleId);
      if (local != null) {
        for (final sn in local.serialNumbers) {
          final panel = await panelRepository.getPanelBySerialNumber(sn);
          if (panel != null) {
            await panelRepository.savePanel(panel.copyWith(
              status: PanelStatus.available,
              clearSaleId: true,
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
      await saleRepository.deleteSale(saleId);
      return;
    }

    final sale = await saleRepository.getSaleById(saleId);
    if (sale == null) throw StateError('Sale record not found.');

    // Reconcile: Return all panels back to available
    final List<PanelItem> restoredPanels = [];
    for (final sn in sale.serialNumbers) {
      final panel = await panelRepository.getPanelBySerialNumber(sn);
      if (panel != null) {
        restoredPanels.add(panel.copyWith(
          status: PanelStatus.available,
          clearSaleId: true,
          updatedAt: DateTime.now(),
        ));
      }
    }

    await panelRepository.savePanels(restoredPanels);
    await saleRepository.deleteSale(saleId);
  }

  // ==========================================
  // AGGREGATIONS & REPORTING
  // ==========================================
  Future<List<PanelItem>> getPanels({
    int? wattage,
    String? batch,
    String? status,
    String? search,
  }) async {
    if (await _shouldUseApi()) {
      try {
        final list = await apiService!.getInventory(
          wattage: wattage,
          batch: batch,
          status: status,
          search: search,
        );
        await panelRepository.savePanels(list);
        return list;
      } catch (_) {
        return panelRepository.getAllPanels();
      }
    }
    return panelRepository.getAllPanels();
  }

  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage) async {
    if (await _shouldUseApi()) {
      try {
        return await apiService!.getAvailablePanelsByWattage(wattage);
      } catch (_) {
        return panelRepository.getAvailablePanelsByWattage(wattage);
      }
    }
    return panelRepository.getAvailablePanelsByWattage(wattage);
  }

  Future<Map<int, Map<String, dynamic>>> getStockByWattage() async {
    if (await _shouldUseApi()) {
      try {
        return await apiService!.getStockByWattage();
      } catch (_) {}
    }

    final panels = await panelRepository.getAllPanels();
    final Map<int, Map<String, dynamic>> map = {};

    for (final p in panels) {
      map.putIfAbsent(p.wattage, () => {
        'available': 0,
        'sold': 0,
        'total': 0,
        'availableAmount': 0.0,
      });
      map[p.wattage]!['total'] = (map[p.wattage]!['total'] as int) + 1;
      if (p.isAvailable) {
        map[p.wattage]!['available'] = (map[p.wattage]!['available'] as int) + 1;
        map[p.wattage]!['availableAmount'] =
            (map[p.wattage]!['availableAmount'] as double) + p.purchasePrice;
      } else {
        map[p.wattage]!['sold'] = (map[p.wattage]!['sold'] as int) + 1;
      }
    }

    return map;
  }

  Future<Map<String, dynamic>> getDashboardMetrics() async {
    if (await _shouldUseApi()) {
      try {
        return await apiService!.getDashboardSummary();
      } catch (_) {}
    }

    final panels = await panelRepository.getAllPanels();
    final settings = await settingsRepository.getSettings();

    int available = 0;
    int sold = 0;
    double stockValue = 0.0;

    for (final p in panels) {
      if (p.isAvailable) {
        available++;
        stockValue += p.purchasePrice;
      } else {
        sold++;
      }
    }

    final byWattage = await getStockByWattage();
    final List<Map<String, dynamic>> lowStockAlerts = [];

    byWattage.forEach((wattage, counts) {
      final availableCount = (counts['available'] as int?) ?? 0;
      if (availableCount <= settings.lowStockThreshold) {
        lowStockAlerts.add({
          'wattage': wattage,
          'available': availableCount,
          'threshold': settings.lowStockThreshold,
        });
      }
    });

    final purchases = await purchaseRepository.getAllPurchases();
    final sales = await saleRepository.getAllSales();

    final totalPurchaseAmount = purchases.fold<double>(
      0.0,
      (sum, p) => sum + p.totalPurchaseAmount,
    );
    final totalSalesAmount = sales.fold<double>(
      0.0,
      (sum, s) => sum + s.totalSellingAmount,
    );

    return {
      'totalAvailable': available,
      'totalPurchased': panels.length,
      'totalSold': sold,
      'totalPurchaseAmount': totalPurchaseAmount,
      'totalSalesAmount': totalSalesAmount,
      'totalStockValue': stockValue,
      'byWattage': byWattage,
      'lowStockAlerts': lowStockAlerts,
      'recentPurchases': purchases.take(5).toList(),
      'recentSales': sales.take(5).toList(),
    };
  }

  Future<void> seedIfEmpty() async {
    // Clean initial state for real-world production usage
  }

  Future<void> clearAllData() async {
    final panels = await panelRepository.getAllPanels();
    await panelRepository.deletePanels(panels.map((p) => p.serialNumber).toList());

    final purchases = await purchaseRepository.getAllPurchases();
    for (final p in purchases) {
      await purchaseRepository.deletePurchase(p.id);
    }

    final sales = await saleRepository.getAllSales();
    for (final s in sales) {
      await saleRepository.deleteSale(s.id);
    }

    final customers = await customerRepository.getAllCustomers();
    for (final c in customers) {
      await customerRepository.deleteCustomer(c.id);
    }
  }

  /// Migrates all existing local Hive data (customers, purchases, panels, sales)
  /// to the live Cloud MongoDB database via the REST API.
  Future<Map<String, int>> syncLocalDataToCloud() async {
    if (apiService == null) {
      throw StateError('Cannot sync: Cloud API service is not configured.');
    }
    final settings = await settingsRepository.getSettings();
    apiService!.baseUrl = settings.apiBaseUrl;

    int customersSynced = 0;
    int purchasesSynced = 0;
    int salesSynced = 0;

    // 1. Sync Customers
    final localCustomers = await customerRepository.getAllCustomers();
    final cloudCustomers = await apiService!.getCustomers();
    final cloudConsumerNumbers = cloudCustomers
        .map((c) => c.consumerNumber.trim().toLowerCase())
        .toSet();

    for (final cust in localCustomers) {
      if (!cloudConsumerNumbers.contains(cust.consumerNumber.trim().toLowerCase())) {
        try {
          await apiService!.createCustomer(
            consumerNumber: cust.consumerNumber,
            phone: cust.phone,
            name: cust.name,
            address: cust.address,
          );
          customersSynced++;
        } catch (_) {}
      }
    }

    // Refresh cloud customers to map consumer numbers to cloud customer IDs
    final updatedCloudCustomers = await apiService!.getCustomers();
    final consumerToCloudId = {
      for (final c in updatedCloudCustomers)
        c.consumerNumber.trim().toLowerCase(): c.id
    };

    // 2. Sync Purchases
    final localPurchases = await purchaseRepository.getAllPurchases();
    final cloudPurchases = await apiService!.getPurchases();
    final cloudBatches = cloudPurchases
        .map((p) => p.batchNumber.trim().toLowerCase())
        .toSet();

    for (final purch in localPurchases) {
      if (!cloudBatches.contains(purch.batchNumber.trim().toLowerCase())) {
        try {
          await apiService!.createPurchase(
            purchaseDate: purch.purchaseDate,
            supplierName: purch.supplierName,
            batchNumber: purch.batchNumber,
            wattage: purch.wattage,
            quantity: purch.quantity,
            serialNumbers: purch.serialNumbers,
            unitPurchasePrice: purch.unitPurchasePrice,
            notes: purch.notes,
          );
          purchasesSynced++;
        } catch (_) {}
      }
    }

    // 3. Sync Sales
    final localSales = await saleRepository.getAllSales();
    final cloudSales = await apiService!.getSales();
    final cloudSaleSerials = <String>{};
    for (final s in cloudSales) {
      cloudSaleSerials.addAll(s.serialNumbers.map((sn) => sn.toUpperCase()));
    }

    for (final sale in localSales) {
      final alreadySold = sale.serialNumbers.any(
        (sn) => cloudSaleSerials.contains(sn.toUpperCase()),
      );
      if (!alreadySold) {
        final cloudCustomerId =
            consumerToCloudId[sale.consumerNumber.trim().toLowerCase()];
        if (cloudCustomerId != null) {
          try {
            await apiService!.createSale(
              saleDate: sale.saleDate,
              customerId: cloudCustomerId,
              panelWattage: sale.panelWattage,
              serialNumbers: sale.serialNumbers,
              unitSellingPrice: sale.unitSellingPrice,
              notes: sale.notes,
            );
            salesSynced++;
          } catch (_) {}
        }
      }
    }

    return {
      'customers': customersSynced,
      'purchases': purchasesSynced,
      'sales': salesSynced,
    };
  }
}


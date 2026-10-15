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

class InventoryService {
  final CustomerRepository customerRepository;
  final PurchaseRepository purchaseRepository;
  final SaleRepository saleRepository;
  final PanelRepository panelRepository;
  final SettingsRepository settingsRepository;

  final Uuid _uuid = const Uuid();

  InventoryService({
    required this.customerRepository,
    required this.purchaseRepository,
    required this.saleRepository,
    required this.panelRepository,
    required this.settingsRepository,
  });

  // ==========================================
  // CUSTOMER OPERATIONS & INVARIANTS
  // ==========================================
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
  Future<SaleTransaction> createSale({
    DateTime? saleDate,
    required String customerId,
    required int panelWattage,
    required List<String> serialNumbers,
    required double unitSellingPrice,
    String? notes,
  }) async {
    final customer = await customerRepository.getCustomerById(customerId);
    if (customer == null) {
      throw StateError('Selected customer not found.');
    }

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
  Future<Map<int, Map<String, int>>> getStockByWattage() async {
    final panels = await panelRepository.getAllPanels();
    final Map<int, Map<String, int>> map = {};

    for (final p in panels) {
      map.putIfAbsent(p.wattage, () => {'available': 0, 'sold': 0, 'total': 0});
      map[p.wattage]!['total'] = map[p.wattage]!['total']! + 1;
      if (p.isAvailable) {
        map[p.wattage]!['available'] = map[p.wattage]!['available']! + 1;
      } else {
        map[p.wattage]!['sold'] = map[p.wattage]!['sold']! + 1;
      }
    }

    return map;
  }

  Future<Map<String, dynamic>> getDashboardMetrics() async {
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
      if (counts['available']! <= settings.lowStockThreshold) {
        lowStockAlerts.add({
          'wattage': wattage,
          'available': counts['available'],
          'threshold': settings.lowStockThreshold,
        });
      }
    });

    final purchases = await purchaseRepository.getAllPurchases();
    final sales = await saleRepository.getAllSales();

    return {
      'totalAvailable': available,
      'totalPurchased': panels.length,
      'totalSold': sold,
      'totalStockValue': stockValue,
      'byWattage': byWattage,
      'lowStockAlerts': lowStockAlerts,
      'recentPurchases': purchases.take(5).toList(),
      'recentSales': sales.take(5).toList(),
    };
  }

  // Initial Seed for Offline Demo
  Future<void> seedIfEmpty() async {
    final existingPanels = await panelRepository.getAllPanels();
    if (existingPanels.isNotEmpty) return;

    // Seed Customers
    final c1 = await createCustomer(
      consumerNumber: '1155443322110',
      phone: '+91 98470 12345',
      name: 'Venu Gopal Nair',
      address: 'Sasthamangalam, Thiruvananthapuram',
    );
    await createCustomer(
      consumerNumber: '1155998877665',
      phone: '+91 94471 56789',
      name: 'Anjali Menon',
      address: 'Marine Drive, Kochi',
    );

    // Seed Purchases
    await createPurchase(
      purchaseDate: DateTime.now().subtract(const Duration(days: 15)),
      supplierName: 'Tata Power Solar Systems',
      batchNumber: 'BATCH-540-A1',
      wattage: 540,
      quantity: 12,
      serialNumbers: List.generate(
          12, (i) => 'HZ-540-26A${(i + 1).toString().padLeft(2, '0')}'),
      unitPurchasePrice: 11500,
      notes: 'Tier 1 Mono PERC 540W solar panels',
    );

    await createPurchase(
      purchaseDate: DateTime.now().subtract(const Duration(days: 10)),
      supplierName: 'Waaree Energies Ltd',
      batchNumber: 'BATCH-450-B1',
      wattage: 450,
      quantity: 8,
      serialNumbers: List.generate(
          8, (i) => 'HZ-450-26B${(i + 1).toString().padLeft(2, '0')}'),
      unitPurchasePrice: 9200,
      notes: 'Bifacial 450W panels for KSEB setups',
    );

    // Seed Sale (4 panels of 540W)
    await createSale(
      saleDate: DateTime.now().subtract(const Duration(days: 3)),
      customerId: c1.id,
      panelWattage: 540,
      serialNumbers: [
        'HZ-540-26A01',
        'HZ-540-26A02',
        'HZ-540-26A03',
        'HZ-540-26A04',
      ],
      unitSellingPrice: 14200,
      notes: '3kW On-Grid Rooftop Phase 1',
    );
  }
}

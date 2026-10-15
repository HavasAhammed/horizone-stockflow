import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/customer.dart';
import 'package:mobile/models/panel_item.dart';
import 'package:mobile/models/purchase.dart';
import 'package:mobile/models/sale.dart';
import 'package:mobile/models/app_settings.dart';
import 'package:mobile/repositories/customer_repository.dart';
import 'package:mobile/repositories/panel_repository.dart';
import 'package:mobile/repositories/purchase_repository.dart';
import 'package:mobile/repositories/sale_repository.dart';
import 'package:mobile/repositories/settings_repository.dart';
import 'package:mobile/services/inventory_service.dart';

// In-Memory Test Repositories
class InMemoryCustomerRepository implements CustomerRepository {
  final Map<String, Customer> _store = {};
  @override
  Future<List<Customer>> getAllCustomers() async => _store.values.toList();
  @override
  Future<Customer?> getCustomerById(String id) async => _store[id];
  @override
  Future<Customer?> getCustomerByConsumerNumber(String cn) async {
    final lower = cn.trim().toLowerCase();
    for (final c in _store.values) {
      if (c.consumerNumber.trim().toLowerCase() == lower) return c;
    }
    return null;
  }
  @override
  Future<void> saveCustomer(Customer c) async => _store[c.id] = c;
  @override
  Future<void> deleteCustomer(String id) async => _store.remove(id);
}

class InMemoryPurchaseRepository implements PurchaseRepository {
  final Map<String, PurchaseTransaction> _store = {};
  @override
  Future<List<PurchaseTransaction>> getAllPurchases() async => _store.values.toList();
  @override
  Future<PurchaseTransaction?> getPurchaseById(String id) async => _store[id];
  @override
  Future<void> savePurchase(PurchaseTransaction p) async => _store[p.id] = p;
  @override
  Future<void> deletePurchase(String id) async => _store.remove(id);
}

class InMemorySaleRepository implements SaleRepository {
  final Map<String, SaleTransaction> _store = {};
  @override
  Future<List<SaleTransaction>> getAllSales() async => _store.values.toList();
  @override
  Future<SaleTransaction?> getSaleById(String id) async => _store[id];
  @override
  Future<List<SaleTransaction>> getSalesByCustomerId(String customerId) async =>
      _store.values.where((s) => s.customerId == customerId).toList();
  @override
  Future<void> saveSale(SaleTransaction s) async => _store[s.id] = s;
  @override
  Future<void> deleteSale(String id) async => _store.remove(id);
}

class InMemoryPanelRepository implements PanelRepository {
  final Map<String, PanelItem> _store = {};
  @override
  Future<List<PanelItem>> getAllPanels() async => _store.values.toList();
  @override
  Future<PanelItem?> getPanelBySerialNumber(String sn) async => _store[sn];
  @override
  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage) async =>
      _store.values.where((p) => p.wattage == wattage && p.isAvailable).toList();
  @override
  Future<void> savePanel(PanelItem p) async => _store[p.serialNumber] = p;
  @override
  Future<void> savePanels(List<PanelItem> panels) async {
    for (final p in panels) {
      _store[p.serialNumber] = p;
    }
  }
  @override
  Future<void> deletePanel(String sn) async => _store.remove(sn);
  @override
  Future<void> deletePanels(List<String> sns) async {
    for (final sn in sns) {
      _store.remove(sn);
    }
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _settings = AppSettings();
  @override
  Future<AppSettings> getSettings() async => _settings;
  @override
  Future<void> saveSettings(AppSettings s) async => _settings = s;
}

void main() {
  late InventoryService service;
  late InMemoryCustomerRepository custRepo;
  late InMemoryPurchaseRepository purchRepo;
  late InMemorySaleRepository saleRepo;
  late InMemoryPanelRepository panelRepo;
  late InMemorySettingsRepository settingsRepo;

  setUp(() {
    custRepo = InMemoryCustomerRepository();
    purchRepo = InMemoryPurchaseRepository();
    saleRepo = InMemorySaleRepository();
    panelRepo = InMemoryPanelRepository();
    settingsRepo = InMemorySettingsRepository();

    service = InventoryService(
      customerRepository: custRepo,
      purchaseRepository: purchRepo,
      saleRepository: saleRepo,
      panelRepository: panelRepo,
      settingsRepository: settingsRepo,
    );
  });

  group('Customer Validation & Business Rules', () {
    test('requires mandatory KSEB consumer number and phone', () async {
      expect(
        () => service.createCustomer(consumerNumber: '', phone: '9847012345'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.createCustomer(consumerNumber: '1155443322110', phone: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('detects and rejects duplicate KSEB consumer numbers', () async {
      await service.createCustomer(
        consumerNumber: '1155443322110',
        phone: '9847012345',
        name: 'First User',
      );

      expect(
        () => service.createCustomer(
          consumerNumber: '  1155443322110  ',
          phone: '9447156789',
          name: 'Duplicate User',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Purchase & Serial Number Inventory Rules', () {
    test('enforces serial numbers count matching quantity', () async {
      expect(
        () => service.createPurchase(
          batchNumber: 'B1',
          wattage: 540,
          quantity: 3,
          serialNumbers: ['SN-1', 'SN-2'], // only 2 serials for 3 panels
          unitPurchasePrice: 10000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects duplicate serial numbers inside batch entry', () async {
      expect(
        () => service.createPurchase(
          batchNumber: 'B2',
          wattage: 540,
          quantity: 2,
          serialNumbers: ['SN-DUP', 'SN-DUP'],
          unitPurchasePrice: 10000,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects serial numbers that already exist in inventory', () async {
      await service.createPurchase(
        batchNumber: 'B3',
        wattage: 540,
        quantity: 1,
        serialNumbers: ['SN-GLOBAL-1'],
        unitPurchasePrice: 10000,
      );

      expect(
        () => service.createPurchase(
          batchNumber: 'B4',
          wattage: 540,
          quantity: 1,
          serialNumbers: ['SN-GLOBAL-1'],
          unitPurchasePrice: 10000,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Sales Allocation & Inventory Reconciliation', () {
    test('deducts inventory atomically and reconciles on sale deletion', () async {
      // 1. Create Customer
      final cust = await service.createCustomer(
        consumerNumber: '1155998877665',
        phone: '9847012345',
        name: 'Solar Client',
      );

      // 2. Add Purchase
      await service.createPurchase(
        batchNumber: 'BATCH-SALE-1',
        wattage: 540,
        quantity: 3,
        serialNumbers: ['HZ-540-01', 'HZ-540-02', 'HZ-540-03'],
        unitPurchasePrice: 11000,
      );

      // Verify panels are available
      final availableBefore = await panelRepo.getAvailablePanelsByWattage(540);
      expect(availableBefore.length, 3);

      // 3. Create Sale of 2 panels
      final sale = await service.createSale(
        customerId: cust.id,
        panelWattage: 540,
        serialNumbers: ['HZ-540-01', 'HZ-540-02'],
        unitSellingPrice: 14000,
      );

      expect(sale.quantity, 2);
      expect(sale.totalSellingAmount, 28000);

      // Verify available count decreased to 1
      final availableAfterSale = await panelRepo.getAvailablePanelsByWattage(540);
      expect(availableAfterSale.length, 1);
      expect(availableAfterSale.first.serialNumber, 'HZ-540-03');

      // Verify sold panel status
      final panel1 = await panelRepo.getPanelBySerialNumber('HZ-540-01');
      expect(panel1!.isSold, true);
      expect(panel1.saleId, sale.id);

      // 4. Prevent deleting customer while linked sales exist
      expect(
        () => service.deleteCustomer(cust.id),
        throwsA(isA<StateError>()),
      );

      // 5. Delete Sale and verify reconciliation
      await service.deleteSale(sale.id);

      final availableAfterReconciliation = await panelRepo.getAvailablePanelsByWattage(540);
      expect(availableAfterReconciliation.length, 3);

      final restoredPanel1 = await panelRepo.getPanelBySerialNumber('HZ-540-01');
      expect(restoredPanel1!.isAvailable, true);
      expect(restoredPanel1.saleId, isNull);
    });

    test('prevents purchase deletion when panels have been sold', () async {
      final cust = await service.createCustomer(
        consumerNumber: '1155000000001',
        phone: '9847011111',
      );

      final purchase = await service.createPurchase(
        batchNumber: 'BATCH-SAFE-DELETE',
        wattage: 450,
        quantity: 1,
        serialNumbers: ['HZ-450-SAFE-1'],
        unitPurchasePrice: 9000,
      );

      await service.createSale(
        customerId: cust.id,
        panelWattage: 450,
        serialNumbers: ['HZ-450-SAFE-1'],
        unitSellingPrice: 12000,
      );

      // Deleting purchase must throw StateError
      expect(
        () => service.deletePurchase(purchase.id),
        throwsA(isA<StateError>()),
      );
    });
  });
}

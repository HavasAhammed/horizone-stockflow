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
    String type = 'DCR',
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
    final panelType = type.trim().toUpperCase() == 'NON DCR' ? 'Non DCR' : 'DCR';
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
        type: panelType,
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
          type: panelType,
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
      type: panelType,
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
        type: panelType,
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

  Future<PurchaseTransaction> updatePurchase({
    required String id,
    DateTime? purchaseDate,
    String? supplierName,
    String? batchNumber,
    String? type,
    double? unitPurchasePrice,
    String? notes,
    List<String>? serialNumbers,
  }) async {
    if (await _shouldUseApi()) {
      final updated = await apiService!.updatePurchase(
        id,
        purchaseDate: purchaseDate,
        supplierName: supplierName,
        batchNumber: batchNumber,
        type: type,
        unitPurchasePrice: unitPurchasePrice,
        notes: notes,
        serialNumbers: serialNumbers,
      );
      await purchaseRepository.savePurchase(updated);

      if (serialNumbers != null) {
        final existing = await purchaseRepository.getPurchaseById(id);
        if (existing != null) {
          final removed = existing.serialNumbers.where((s) => !serialNumbers.contains(s)).toList();
          if (removed.isNotEmpty) {
            await panelRepository.deletePanels(removed);
          }
        }
        final List<PanelItem> newPanels = serialNumbers.map((sn) {
          return PanelItem(
            id: sn,
            serialNumber: sn,
            batchNumber: updated.batchNumber,
            wattage: updated.wattage,
            type: updated.type,
            purchaseId: updated.id,
            purchasePrice: updated.unitPurchasePrice,
            status: PanelStatus.available,
            saleId: null,
            createdAt: updated.purchaseDate,
            updatedAt: DateTime.now(),
          );
        }).toList();
        await panelRepository.savePanels(newPanels);
      }
      return updated;
    }

    final purchase = await purchaseRepository.getPurchaseById(id);
    if (purchase == null) throw StateError('Purchase record "$id" not found.');

    final trimmedBatch = batchNumber?.trim();
    if (trimmedBatch != null && trimmedBatch.isEmpty) {
      throw ArgumentError('Batch number cannot be empty.');
    }
    if (unitPurchasePrice != null && unitPurchasePrice < 0) {
      throw ArgumentError('Unit purchase price cannot be negative.');
    }

    final newBatch = trimmedBatch ?? purchase.batchNumber;
    final newType = type?.trim().isNotEmpty == true
        ? (type!.trim().toUpperCase() == 'NON DCR' ? 'Non DCR' : 'DCR')
        : purchase.type;
    final newPrice = unitPurchasePrice ?? purchase.unitPurchasePrice;
    final newDate = purchaseDate ?? purchase.purchaseDate;
    final newSupplier = supplierName != null
        ? (supplierName.trim().isEmpty ? null : supplierName.trim())
        : purchase.supplierName;
    final newNotes = notes != null
        ? (notes.trim().isEmpty ? null : notes.trim())
        : purchase.notes;

    List<String> finalSerials = purchase.serialNumbers;

    if (serialNumbers != null) {
      final clean = serialNumbers.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
      if (clean.isEmpty) {
        throw ArgumentError('Purchase batch must contain at least one panel serial number.');
      }
      final uniqueSet = clean.toSet();
      if (uniqueSet.length != clean.length) {
        throw StateError('Duplicate serial numbers in updated batch list.');
      }

      final oldUpperSet = purchase.serialNumbers.map((s) => s.toUpperCase()).toSet();
      final removed = purchase.serialNumbers.where((s) => !uniqueSet.contains(s.toUpperCase())).toList();
      final added = clean.where((s) => !oldUpperSet.contains(s)).toList();

      for (final sn in removed) {
        final panel = await panelRepository.getPanelBySerialNumber(sn);
        if (panel != null && panel.isSold) {
          throw StateError('Cannot remove panel "$sn" because it has already been sold in sale "${panel.saleId}".');
        }
      }

      for (final sn in added) {
        final existing = await panelRepository.getPanelBySerialNumber(sn);
        if (existing != null) {
          throw StateError('Serial number "$sn" already exists in inventory.');
        }
      }

      await panelRepository.deletePanels(removed);

      final List<PanelItem> createdPanels = added.map((sn) {
        return PanelItem(
          id: _uuid.v4(),
          serialNumber: sn,
          batchNumber: newBatch,
          wattage: purchase.wattage,
          type: newType,
          purchaseId: purchase.id,
          purchasePrice: newPrice,
          status: PanelStatus.available,
          saleId: null,
          createdAt: newDate,
          updatedAt: DateTime.now(),
        );
      }).toList();
      await panelRepository.savePanels(createdPanels);

      finalSerials = clean;
    }

    // Update existing panels if batch number, price, or type changed
    if (newBatch != purchase.batchNumber || newPrice != purchase.unitPurchasePrice || newType != purchase.type) {
      for (final sn in finalSerials) {
        final p = await panelRepository.getPanelBySerialNumber(sn);
        if (p != null) {
          await panelRepository.savePanel(p.copyWith(
            batchNumber: newBatch,
            purchasePrice: newPrice,
            type: newType,
            updatedAt: DateTime.now(),
          ));
        }
      }
    }

    final updated = purchase.copyWith(
      purchaseDate: newDate,
      supplierName: newSupplier,
      batchNumber: newBatch,
      type: newType,
      quantity: finalSerials.length,
      serialNumbers: finalSerials,
      unitPurchasePrice: newPrice,
      totalPurchaseAmount: finalSerials.length * newPrice,
      notes: newNotes,
      updatedAt: DateTime.now(),
    );

    await purchaseRepository.savePurchase(updated);
    return updated;
  }

  Future<PurchaseTransaction> addPanelsToPurchase(String purchaseId, List<String> newSerials) async {
    final clean = newSerials.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
    if (clean.isEmpty) {
      throw ArgumentError('At least one serial number is required.');
    }

    if (await _shouldUseApi()) {
      final updated = await apiService!.addPanelsToPurchase(purchaseId, clean);
      await purchaseRepository.savePurchase(updated);
      final List<PanelItem> newPanels = clean.map((sn) {
        return PanelItem(
          id: sn,
          serialNumber: sn,
          batchNumber: updated.batchNumber,
          wattage: updated.wattage,
          purchaseId: updated.id,
          purchasePrice: updated.unitPurchasePrice,
          status: PanelStatus.available,
          saleId: null,
          createdAt: updated.purchaseDate,
          updatedAt: DateTime.now(),
        );
      }).toList();
      await panelRepository.savePanels(newPanels);
      return updated;
    }

    final purchase = await purchaseRepository.getPurchaseById(purchaseId);
    if (purchase == null) throw StateError('Purchase record not found.');

    final combined = [...purchase.serialNumbers, ...clean];
    return updatePurchase(id: purchaseId, serialNumbers: combined);
  }

  Future<PurchaseTransaction> updatePanelSerialNumber(String purchaseId, String oldSerial, String newSerial) async {
    final trimmedOld = oldSerial.trim();
    final trimmedNew = newSerial.trim().toUpperCase();
    if (trimmedNew.isEmpty) throw ArgumentError('New serial number cannot be empty.');
    if (trimmedOld.toUpperCase() == trimmedNew) {
      final p = await purchaseRepository.getPurchaseById(purchaseId);
      return p!;
    }

    if (await _shouldUseApi()) {
      final updated = await apiService!.updatePanelSerial(purchaseId, trimmedOld, trimmedNew);
      await purchaseRepository.savePurchase(updated);
      final panel = await panelRepository.getPanelBySerialNumber(trimmedOld);
      if (panel != null) {
        await panelRepository.deletePanels([trimmedOld]);
        await panelRepository.savePanel(panel.copyWith(
          serialNumber: trimmedNew,
          updatedAt: DateTime.now(),
        ));
      }
      return updated;
    }

    final purchase = await purchaseRepository.getPurchaseById(purchaseId);
    if (purchase == null) throw StateError('Purchase record not found.');

    final snIndex = purchase.serialNumbers.indexWhere((s) => s.toUpperCase() == trimmedOld.toUpperCase());
    if (snIndex == -1) throw StateError('Serial "$oldSerial" not found in batch "${purchase.batchNumber}".');

    final existing = await panelRepository.getPanelBySerialNumber(trimmedNew);
    if (existing != null) {
      throw StateError('Serial number "$trimmedNew" already exists in inventory.');
    }

    final actualOld = purchase.serialNumbers[snIndex];
    final panel = await panelRepository.getPanelBySerialNumber(actualOld);
    if (panel != null) {
      await panelRepository.deletePanels([actualOld]);
      await panelRepository.savePanel(panel.copyWith(
        serialNumber: trimmedNew,
        updatedAt: DateTime.now(),
      ));

      if (panel.isSold && panel.saleId != null) {
        final sale = await saleRepository.getSaleById(panel.saleId!);
        if (sale != null) {
          final sIdx = sale.serialNumbers.indexWhere((s) => s.toUpperCase() == actualOld.toUpperCase());
          if (sIdx != -1) {
            final updatedSerials = List<String>.from(sale.serialNumbers);
            updatedSerials[sIdx] = trimmedNew;
            await saleRepository.saveSale(sale.copyWith(serialNumbers: updatedSerials, updatedAt: DateTime.now()));
          }
        }
      }
    }

    final updatedList = List<String>.from(purchase.serialNumbers);
    updatedList[snIndex] = trimmedNew;
    final updatedPurchase = purchase.copyWith(serialNumbers: updatedList, updatedAt: DateTime.now());
    await purchaseRepository.savePurchase(updatedPurchase);
    return updatedPurchase;
  }

  Future<PurchaseTransaction> deletePanelFromPurchase(String purchaseId, String serialNumber) async {
    final sn = serialNumber.trim().toUpperCase();
    if (await _shouldUseApi()) {
      final updated = await apiService!.deletePanelFromPurchase(purchaseId, sn);
      await purchaseRepository.savePurchase(updated);
      await panelRepository.deletePanels([sn]);
      return updated;
    }

    final purchase = await purchaseRepository.getPurchaseById(purchaseId);
    if (purchase == null) throw StateError('Purchase record not found.');

    final panel = await panelRepository.getPanelBySerialNumber(sn);
    if (panel != null && panel.isSold) {
      throw StateError('Cannot remove panel "$sn" because it has already been sold in sale "${panel.saleId}".');
    }

    final filtered = purchase.serialNumbers.where((s) => s.toUpperCase() != sn).toList();
    if (filtered.length == purchase.serialNumbers.length) {
      throw StateError('Serial "$serialNumber" not found in purchase.');
    }

    return updatePurchase(id: purchaseId, serialNumbers: filtered);
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
    String type = 'DCR',
    required List<String> serialNumbers,
    required double unitSellingPrice,
    String? notes,
  }) async {
    if (panelWattage <= 0) {
      throw ArgumentError('Wattage must be a positive integer.');
    }
    final saleType = type.trim().toUpperCase() == 'NON DCR' ? 'Non DCR' : 'DCR';
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
        type: saleType,
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

    // Verify all selected panels exist, match wattage and type, and are currently available
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
      if (panel.type != saleType) {
        throw StateError(
            'Panel serial "$sn" is ${panel.type}, expected $saleType.');
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
      type: saleType,
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

  Future<SaleTransaction> updateSale({
    required String id,
    DateTime? saleDate,
    String? customerId,
    String? type,
    double? unitSellingPrice,
    List<String>? serialNumbers,
    String? notes,
  }) async {
    if (unitSellingPrice != null && unitSellingPrice < 0) {
      throw ArgumentError('Unit selling price cannot be negative.');
    }

    if (await _shouldUseApi()) {
      final updated = await apiService!.updateSale(
        id,
        saleDate: saleDate,
        customerId: customerId,
        type: type,
        unitSellingPrice: unitSellingPrice,
        serialNumbers: serialNumbers,
        notes: notes,
      );
      await saleRepository.saveSale(updated);

      if (serialNumbers != null) {
        final localSale = await saleRepository.getSaleById(id);
        if (localSale != null) {
          final removed = localSale.serialNumbers.where((s) => !serialNumbers.contains(s)).toList();
          for (final sn in removed) {
            final p = await panelRepository.getPanelBySerialNumber(sn);
            if (p != null) {
              await panelRepository.savePanel(p.copyWith(
                status: PanelStatus.available,
                clearSaleId: true,
                updatedAt: DateTime.now(),
              ));
            }
          }
          for (final sn in serialNumbers) {
            final p = await panelRepository.getPanelBySerialNumber(sn);
            if (p != null) {
              await panelRepository.savePanel(p.copyWith(
                status: PanelStatus.sold,
                saleId: id,
                updatedAt: DateTime.now(),
              ));
            }
          }
        }
      }
      return updated;
    }

    final sale = await saleRepository.getSaleById(id);
    if (sale == null) throw StateError('Sale record "$id" not found.');

    Customer? newCustomer;
    if (customerId != null && customerId != sale.customerId) {
      newCustomer = await customerRepository.getCustomerById(customerId);
      if (newCustomer == null) throw StateError('Customer "$customerId" not found.');
    }

    final sDate = saleDate ?? sale.saleDate;
    final newType = type?.trim().isNotEmpty == true
        ? (type!.trim().toUpperCase() == 'NON DCR' ? 'Non DCR' : 'DCR')
        : sale.type;
    final price = unitSellingPrice ?? sale.unitSellingPrice;
    final sNotes = notes != null ? (notes.trim().isEmpty ? null : notes.trim()) : sale.notes;

    List<String> finalSerials = sale.serialNumbers;

    if (serialNumbers != null) {
      final clean = serialNumbers.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
      if (clean.isEmpty) {
        throw ArgumentError('Sale must contain at least one panel serial number.');
      }
      final uniqueSet = clean.toSet();
      if (uniqueSet.length != clean.length) {
        throw StateError('Duplicate serial numbers in sale selection.');
      }

      final oldUpper = sale.serialNumbers.map((s) => s.toUpperCase()).toSet();
      final removed = sale.serialNumbers.where((s) => !uniqueSet.contains(s.toUpperCase())).toList();
      final added = clean.where((s) => !oldUpper.contains(s)).toList();

      for (final sn in added) {
        final panel = await panelRepository.getPanelBySerialNumber(sn);
        if (panel == null) {
          throw StateError('Panel serial "$sn" not found in inventory.');
        }
        if (!panel.isAvailable) {
          throw StateError('Panel serial "$sn" is not available for sale.');
        }
        if (panel.wattage != sale.panelWattage) {
          throw StateError('Panel serial "$sn" is ${panel.wattage}W, expected ${sale.panelWattage}W.');
        }
        if (panel.type != newType) {
          throw StateError('Panel serial "$sn" is ${panel.type}, expected $newType.');
        }
      }

      // Reconcile removed panels -> available
      for (final sn in removed) {
        final panel = await panelRepository.getPanelBySerialNumber(sn);
        if (panel != null) {
          await panelRepository.savePanel(panel.copyWith(
            status: PanelStatus.available,
            clearSaleId: true,
            updatedAt: DateTime.now(),
          ));
        }
      }

      // Reconcile added panels -> sold
      for (final sn in added) {
        final panel = await panelRepository.getPanelBySerialNumber(sn);
        if (panel != null) {
          await panelRepository.savePanel(panel.copyWith(
            status: PanelStatus.sold,
            saleId: sale.id,
            updatedAt: DateTime.now(),
          ));
        }
      }

      finalSerials = clean;
    }

    final updated = sale.copyWith(
      saleDate: sDate,
      customerId: newCustomer?.id ?? sale.customerId,
      consumerNumber: newCustomer?.consumerNumber ?? sale.consumerNumber,
      customerName: newCustomer != null ? newCustomer.name : sale.customerName,
      type: newType,
      quantity: finalSerials.length,
      serialNumbers: finalSerials,
      unitSellingPrice: price,
      totalSellingAmount: finalSerials.length * price,
      notes: sNotes,
      updatedAt: DateTime.now(),
    );

    await saleRepository.saveSale(updated);
    return updated;
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

  Future<List<PanelItem>> getAvailablePanelsByWattage(int wattage, {String? type}) async {
    if (await _shouldUseApi()) {
      try {
        return await apiService!.getAvailablePanelsByWattage(wattage, type: type);
      } catch (_) {
        return panelRepository.getAvailablePanelsByWattage(wattage, type: type);
      }
    }
    return panelRepository.getAvailablePanelsByWattage(wattage, type: type);
  }

  Future<void> migrateExistingDataToDcr() async {
    try {
      final panels = await panelRepository.getAllPanels();
      final panelsToUpdate = <PanelItem>[];
      for (final p in panels) {
        if (p.type.isEmpty) {
          panelsToUpdate.add(p.copyWith(type: 'DCR'));
        }
      }
      if (panelsToUpdate.isNotEmpty) {
        await panelRepository.savePanels(panelsToUpdate);
      }

      final purchases = await purchaseRepository.getAllPurchases();
      for (final pu in purchases) {
        if (pu.type.isEmpty) {
          await purchaseRepository.savePurchase(pu.copyWith(type: 'DCR'));
        }
      }

      final sales = await saleRepository.getAllSales();
      for (final s in sales) {
        if (s.type.isEmpty) {
          await saleRepository.saveSale(s.copyWith(type: 'DCR'));
        }
      }
    } catch (_) {}
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


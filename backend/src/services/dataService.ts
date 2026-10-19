import { v4 as uuidv4 } from 'uuid';
import {
  Customer,
  PurchaseTransaction,
  SaleTransaction,
  PanelItem,
  StockByWattage,
  StockByBatch,
  DashboardSummary,
} from '../types/index.js';

export class DataService {
  private customers: Map<string, Customer> = new Map();
  private purchases: Map<string, PurchaseTransaction> = new Map();
  private sales: Map<string, SaleTransaction> = new Map();
  private panels: Map<string, PanelItem> = new Map(); // key is serialNumber
  private lowStockThreshold: number = 10;

  constructor() {
    this.seedInitialData();
  }

  public setLowStockThreshold(threshold: number) {
    if (threshold >= 0) {
      this.lowStockThreshold = threshold;
    }
  }

  public getLowStockThreshold(): number {
    return this.lowStockThreshold;
  }

  // --- SEED DATA ---
  private seedInitialData() {
    // 1. Initial Customers (Kerala KSEB consumers)
    const c1: Customer = {
      id: 'cust-101',
      consumerNumber: '1155443322110',
      phone: '+91 98470 12345',
      name: 'Venu Gopal Nair',
      address: 'TC 14/820, Sasthamangalam, Thiruvananthapuram',
      createdAt: '2026-03-01T10:00:00.000Z',
      updatedAt: '2026-03-01T10:00:00.000Z',
    };
    const c2: Customer = {
      id: 'cust-102',
      consumerNumber: '1155998877665',
      phone: '+91 94471 56789',
      name: 'Anjali Menon',
      address: 'Green Villa, Marine Drive, Kochi',
      createdAt: '2026-03-10T11:30:00.000Z',
      updatedAt: '2026-03-10T11:30:00.000Z',
    };
    const c3: Customer = {
      id: 'cust-103',
      consumerNumber: '1155332211998',
      phone: '+91 97450 88221',
      name: 'Muhammed Shafi',
      address: 'Maniyarath House, Bypass Road, Calicut',
      createdAt: '2026-03-15T09:15:00.000Z',
      updatedAt: '2026-03-15T09:15:00.000Z',
    };

    this.customers.set(c1.id, c1);
    this.customers.set(c2.id, c2);
    this.customers.set(c3.id, c3);

    // 2. Initial Purchase: 540W panels (Batch B-540-01)
    const p1Id = 'purch-201';
    const p1Serials = [
      'HZ-540-26A01',
      'HZ-540-26A02',
      'HZ-540-26A03',
      'HZ-540-26A04',
      'HZ-540-26A05',
      'HZ-540-26A06',
      'HZ-540-26A07',
      'HZ-540-26A08',
      'HZ-540-26A09',
      'HZ-540-26A10',
      'HZ-540-26A11',
      'HZ-540-26A12',
    ];
    const p1: PurchaseTransaction = {
      id: p1Id,
      purchaseDate: '2026-03-05T08:00:00.000Z',
      supplierName: 'Tata Power Solar Systems',
      batchNumber: 'BATCH-540-A1',
      wattage: 540,
      quantity: 12,
      serialNumbers: p1Serials,
      unitPurchasePrice: 11500,
      totalPurchaseAmount: 138000,
      notes: 'Tier 1 Mono PERC 540W panels for residential project installations',
      createdAt: '2026-03-05T08:00:00.000Z',
      updatedAt: '2026-03-05T08:00:00.000Z',
    };
    this.purchases.set(p1.id, p1);
    for (const sn of p1Serials) {
      this.panels.set(sn, {
        id: `pnl-${sn}`,
        serialNumber: sn,
        batchNumber: p1.batchNumber,
        wattage: p1.wattage,
        purchaseId: p1.id,
        purchasePrice: p1.unitPurchasePrice,
        status: 'available',
        saleId: null,
        createdAt: p1.purchaseDate,
        updatedAt: p1.purchaseDate,
      });
    }

    // 3. Second Purchase: 450W panels (Batch B-450-B1)
    const p2Id = 'purch-202';
    const p2Serials = [
      'HZ-450-26B01',
      'HZ-450-26B02',
      'HZ-450-26B03',
      'HZ-450-26B04',
      'HZ-450-26B05',
      'HZ-450-26B06',
      'HZ-450-26B07',
      'HZ-450-26B08',
    ];
    const p2: PurchaseTransaction = {
      id: p2Id,
      purchaseDate: '2026-03-12T09:30:00.000Z',
      supplierName: 'Waaree Energies Ltd',
      batchNumber: 'BATCH-450-B1',
      wattage: 450,
      quantity: 8,
      serialNumbers: p2Serials,
      unitPurchasePrice: 9200,
      totalPurchaseAmount: 73600,
      notes: 'Bifacial 450W panels for KSEB on-grid setup',
      createdAt: '2026-03-12T09:30:00.000Z',
      updatedAt: '2026-03-12T09:30:00.000Z',
    };
    this.purchases.set(p2.id, p2);
    for (const sn of p2Serials) {
      this.panels.set(sn, {
        id: `pnl-${sn}`,
        serialNumber: sn,
        batchNumber: p2.batchNumber,
        wattage: p2.wattage,
        purchaseId: p2.id,
        purchasePrice: p2.unitPurchasePrice,
        status: 'available',
        saleId: null,
        createdAt: p2.purchaseDate,
        updatedAt: p2.purchaseDate,
      });
    }

    // 4. Initial Sale: 4 panels of 540W to Customer 1
    const s1Id = 'sale-301';
    const s1Serials = ['HZ-540-26A01', 'HZ-540-26A02', 'HZ-540-26A03', 'HZ-540-26A04'];
    const s1: SaleTransaction = {
      id: s1Id,
      saleDate: '2026-03-18T14:20:00.000Z',
      customerId: c1.id,
      consumerNumber: c1.consumerNumber,
      customerName: c1.name,
      panelWattage: 540,
      quantity: s1Serials.length,
      serialNumbers: s1Serials,
      unitSellingPrice: 14200,
      totalSellingAmount: 56800,
      notes: '3kW On-Grid Rooftop solar installation phase 1',
      createdAt: '2026-03-18T14:20:00.000Z',
      updatedAt: '2026-03-18T14:20:00.000Z',
    };
    this.sales.set(s1.id, s1);
    for (const sn of s1Serials) {
      const panel = this.panels.get(sn);
      if (panel) {
        panel.status = 'sold';
        panel.saleId = s1.id;
        panel.updatedAt = s1.saleDate;
      }
    }
  }

  // ==========================================
  // CUSTOMER OPERATIONS
  // ==========================================
  public getAllCustomers(): Customer[] {
    return Array.from(this.customers.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  public getCustomerById(id: string): Customer | undefined {
    return this.customers.get(id);
  }

  public getCustomerByConsumerNumber(consumerNumber: string): Customer | undefined {
    const trimmed = consumerNumber.trim();
    return Array.from(this.customers.values()).find(
      (c) => c.consumerNumber.toLowerCase() === trimmed.toLowerCase()
    );
  }

  public createCustomer(data: {
    consumerNumber: string;
    phone: string;
    name?: string;
    address?: string;
  }): Customer {
    const consumerNumber = (data.consumerNumber || '').trim();
    const phone = (data.phone || '').trim();
    const name = (data.name || '').trim();
    const address = (data.address || '').trim();

    if (!consumerNumber) {
      throw new Error('KSEB consumer number is mandatory.');
    }
    if (!phone) {
      throw new Error('Phone number is mandatory.');
    }

    const existing = this.getCustomerByConsumerNumber(consumerNumber);
    if (existing) {
      throw new Error(
        `A customer with KSEB consumer number "${consumerNumber}" already exists (Customer: ${existing.name || 'Unnamed'}).`
      );
    }

    const now = new Date().toISOString();
    const customer: Customer = {
      id: uuidv4(),
      consumerNumber,
      phone,
      name: name || undefined,
      address: address || undefined,
      createdAt: now,
      updatedAt: now,
    };

    this.customers.set(customer.id, customer);
    return customer;
  }

  public updateCustomer(
    id: string,
    data: {
      consumerNumber?: string;
      phone?: string;
      name?: string;
      address?: string;
    }
  ): Customer {
    const customer = this.customers.get(id);
    if (!customer) {
      throw new Error(`Customer with ID "${id}" not found.`);
    }

    if (data.consumerNumber !== undefined) {
      const consumerNumber = data.consumerNumber.trim();
      if (!consumerNumber) {
        throw new Error('KSEB consumer number cannot be empty.');
      }
      const existing = this.getCustomerByConsumerNumber(consumerNumber);
      if (existing && existing.id !== id) {
        throw new Error(
          `KSEB consumer number "${consumerNumber}" is already in use by another customer.`
        );
      }
      customer.consumerNumber = consumerNumber;
    }

    if (data.phone !== undefined) {
      const phone = data.phone.trim();
      if (!phone) {
        throw new Error('Phone number cannot be empty.');
      }
      customer.phone = phone;
    }

    if (data.name !== undefined) {
      customer.name = data.name.trim() || undefined;
    }

    if (data.address !== undefined) {
      customer.address = data.address.trim() || undefined;
    }

    customer.updatedAt = new Date().toISOString();
    this.customers.set(customer.id, customer);
    return customer;
  }

  public deleteCustomer(id: string): boolean {
    const customer = this.customers.get(id);
    if (!customer) {
      throw new Error(`Customer with ID "${id}" not found.`);
    }

    // Safety rule: Prevent deletion if customer has linked sales
    const linkedSales = Array.from(this.sales.values()).filter((s) => s.customerId === id);
    if (linkedSales.length > 0) {
      throw new Error(
        `Cannot delete customer "${customer.name || customer.consumerNumber}". There are ${linkedSales.length} linked sale transaction(s) associated with this account. Archival or sale cancellation is required first.`
      );
    }

    this.customers.delete(id);
    return true;
  }

  public getCustomerSales(customerId: string): SaleTransaction[] {
    return Array.from(this.sales.values())
      .filter((s) => s.customerId === customerId)
      .sort((a, b) => new Date(b.saleDate).getTime() - new Date(a.saleDate).getTime());
  }

  // ==========================================
  // PURCHASE OPERATIONS
  // ==========================================
  public getAllPurchases(): PurchaseTransaction[] {
    return Array.from(this.purchases.values()).sort(
      (a, b) => new Date(b.purchaseDate).getTime() - new Date(a.purchaseDate).getTime()
    );
  }

  public getPurchaseById(id: string): PurchaseTransaction | undefined {
    return this.purchases.get(id);
  }

  public createPurchase(data: {
    purchaseDate?: string;
    supplierName?: string;
    batchNumber: string;
    wattage: number;
    quantity: number;
    serialNumbers: string[];
    unitPurchasePrice: number;
    notes?: string;
  }): PurchaseTransaction {
    const batchNumber = (data.batchNumber || '').trim();
    if (!batchNumber) {
      throw new Error('Batch number is required.');
    }

    const wattage = Math.floor(Number(data.wattage));
    if (isNaN(wattage) || wattage <= 0) {
      throw new Error('Wattage must be a positive integer in Watts.');
    }

    const quantity = Math.floor(Number(data.quantity));
    if (isNaN(quantity) || quantity <= 0) {
      throw new Error('Quantity must be a positive integer.');
    }

    const unitPurchasePrice = Number(data.unitPurchasePrice);
    if (isNaN(unitPurchasePrice) || unitPurchasePrice < 0) {
      throw new Error('Unit purchase price cannot be negative.');
    }

    const rawSerials = Array.isArray(data.serialNumbers) ? data.serialNumbers : [];
    const serials = rawSerials.map((s) => s.trim()).filter((s) => s.length > 0);

    if (serials.length !== quantity) {
      throw new Error(
        `Serial numbers count (${serials.length}) must match the purchase quantity (${quantity}).`
      );
    }

    // Check for internal duplicates in the submitted batch
    const uniqueSerials = new Set<string>();
    for (const sn of serials) {
      const lower = sn.toUpperCase();
      if (uniqueSerials.has(lower)) {
        throw new Error(`Duplicate serial number in batch entry: "${sn}".`);
      }
      uniqueSerials.add(lower);
    }

    // Check if any serial number already exists in overall inventory
    for (const sn of serials) {
      if (this.panels.has(sn)) {
        const existingPanel = this.panels.get(sn)!;
        throw new Error(
          `Serial number "${sn}" already exists in inventory (Batch: ${existingPanel.batchNumber}, Status: ${existingPanel.status}).`
        );
      }
    }

    const now = new Date().toISOString();
    const purchaseDate = data.purchaseDate ? new Date(data.purchaseDate).toISOString() : now;
    const totalPurchaseAmount = Math.round(quantity * unitPurchasePrice * 100) / 100;

    const purchase: PurchaseTransaction = {
      id: uuidv4(),
      purchaseDate,
      supplierName: data.supplierName?.trim() || undefined,
      batchNumber,
      wattage,
      quantity,
      serialNumbers: serials,
      unitPurchasePrice,
      totalPurchaseAmount,
      notes: data.notes?.trim() || undefined,
      createdAt: now,
      updatedAt: now,
    };

    // Commit purchase
    this.purchases.set(purchase.id, purchase);

    // Atomically create panel records
    for (const sn of serials) {
      const panel: PanelItem = {
        id: uuidv4(),
        serialNumber: sn,
        batchNumber,
        wattage,
        purchaseId: purchase.id,
        purchasePrice: unitPurchasePrice,
        status: 'available',
        saleId: null,
        createdAt: purchaseDate,
        updatedAt: purchaseDate,
      };
      this.panels.set(sn, panel);
    }

    return purchase;
  }

  public updatePurchase(
    id: string,
    data: {
      purchaseDate?: string;
      supplierName?: string;
      batchNumber?: string;
      unitPurchasePrice?: number;
      notes?: string;
    }
  ): PurchaseTransaction {
    const purchase = this.purchases.get(id);
    if (!purchase) {
      throw new Error(`Purchase record "${id}" not found.`);
    }

    if (data.purchaseDate) {
      purchase.purchaseDate = new Date(data.purchaseDate).toISOString();
    }
    if (data.supplierName !== undefined) {
      purchase.supplierName = data.supplierName.trim() || undefined;
    }
    if (data.batchNumber !== undefined) {
      const batchNumber = data.batchNumber.trim();
      if (!batchNumber) throw new Error('Batch number cannot be empty.');
      purchase.batchNumber = batchNumber;
      // update panels batch
      for (const sn of purchase.serialNumbers) {
        const p = this.panels.get(sn);
        if (p) p.batchNumber = batchNumber;
      }
    }
    if (data.unitPurchasePrice !== undefined) {
      const price = Number(data.unitPurchasePrice);
      if (isNaN(price) || price < 0) throw new Error('Price cannot be negative.');
      purchase.unitPurchasePrice = price;
      purchase.totalPurchaseAmount = Math.round(purchase.quantity * price * 100) / 100;
      for (const sn of purchase.serialNumbers) {
        const p = this.panels.get(sn);
        if (p) p.purchasePrice = price;
      }
    }
    if (data.notes !== undefined) {
      purchase.notes = data.notes.trim() || undefined;
    }

    purchase.updatedAt = new Date().toISOString();
    this.purchases.set(purchase.id, purchase);
    return purchase;
  }

  public deletePurchase(id: string): boolean {
    const purchase = this.purchases.get(id);
    if (!purchase) {
      throw new Error(`Purchase record "${id}" not found.`);
    }

    // Safety rule: Cannot delete purchase if any panel from this purchase has already been sold
    const soldPanels = purchase.serialNumbers.filter((sn) => {
      const p = this.panels.get(sn);
      return p && p.status === 'sold';
    });

    if (soldPanels.length > 0) {
      throw new Error(
        `Cannot delete purchase "${id}". ${soldPanels.length} panel(s) from this purchase have already been sold (e.g. ${soldPanels.slice(0, 3).join(', ')}). Delete or reconcile the sales first.`
      );
    }

    // Safe to delete: remove panel inventory records atomically
    for (const sn of purchase.serialNumbers) {
      this.panels.delete(sn);
    }

    this.purchases.delete(id);
    return true;
  }

  // ==========================================
  // SALES OPERATIONS
  // ==========================================
  public getAllSales(): SaleTransaction[] {
    return Array.from(this.sales.values()).sort(
      (a, b) => new Date(b.saleDate).getTime() - new Date(a.saleDate).getTime()
    );
  }

  public getSaleById(id: string): SaleTransaction | undefined {
    return this.sales.get(id);
  }

  public createSale(data: {
    saleDate?: string;
    customerId: string;
    panelWattage: number;
    serialNumbers: string[];
    unitSellingPrice: number;
    notes?: string;
  }): SaleTransaction {
    const customer = this.customers.get(data.customerId);
    if (!customer) {
      throw new Error(`Customer with ID "${data.customerId}" does not exist.`);
    }

    const wattage = Math.floor(Number(data.panelWattage));
    if (isNaN(wattage) || wattage <= 0) {
      throw new Error('Panel wattage must be a positive integer in Watts.');
    }

    const rawSerials = Array.isArray(data.serialNumbers) ? data.serialNumbers : [];
    const serials = rawSerials.map((s) => s.trim()).filter((s) => s.length > 0);

    if (serials.length === 0) {
      throw new Error('At least one panel serial number must be selected for the sale.');
    }

    // Check for duplicate serial selections
    const unique = new Set(serials);
    if (unique.size !== serials.length) {
      throw new Error('Sale contains duplicate panel serial selections.');
    }

    const unitSellingPrice = Number(data.unitSellingPrice);
    if (isNaN(unitSellingPrice) || unitSellingPrice < 0) {
      throw new Error('Unit selling price cannot be negative.');
    }

    // Verify all selected serials exist, match requested wattage, and are CURRENTLY AVAILABLE
    for (const sn of serials) {
      const panel = this.panels.get(sn);
      if (!panel) {
        throw new Error(`Panel serial "${sn}" not found in inventory.`);
      }
      if (panel.status !== 'available') {
        throw new Error(
          `Panel serial "${sn}" is already marked as ${panel.status} (Sale: ${panel.saleId || 'unknown'}). Cannot be sold again.`
        );
      }
      if (panel.wattage !== wattage) {
        throw new Error(
          `Panel serial "${sn}" is ${panel.wattage}W, which does not match requested sale wattage ${wattage}W.`
        );
      }
    }

    const quantity = serials.length;
    const now = new Date().toISOString();
    const saleDate = data.saleDate ? new Date(data.saleDate).toISOString() : now;
    const totalSellingAmount = Math.round(quantity * unitSellingPrice * 100) / 100;

    const sale: SaleTransaction = {
      id: uuidv4(),
      saleDate,
      customerId: customer.id,
      consumerNumber: customer.consumerNumber,
      customerName: customer.name,
      panelWattage: wattage,
      quantity,
      serialNumbers: serials,
      unitSellingPrice,
      totalSellingAmount,
      notes: data.notes?.trim() || undefined,
      createdAt: now,
      updatedAt: now,
    };

    // Commit sale record
    this.sales.set(sale.id, sale);

    // Atomically transition panels to 'sold'
    for (const sn of serials) {
      const panel = this.panels.get(sn)!;
      panel.status = 'sold';
      panel.saleId = sale.id;
      panel.updatedAt = now;
    }

    return sale;
  }

  public updateSale(
    id: string,
    data: {
      saleDate?: string;
      customerId?: string;
      unitSellingPrice?: number;
      serialNumbers?: string[];
      notes?: string;
    }
  ): SaleTransaction {
    const sale = this.sales.get(id);
    if (!sale) {
      throw new Error(`Sale transaction "${id}" not found.`);
    }

    let customer = this.customers.get(sale.customerId)!;
    if (data.customerId && data.customerId !== sale.customerId) {
      const newCust = this.customers.get(data.customerId);
      if (!newCust) throw new Error(`Customer "${data.customerId}" not found.`);
      customer = newCust;
      sale.customerId = newCust.id;
      sale.consumerNumber = newCust.consumerNumber;
      sale.customerName = newCust.name;
    }

    if (data.saleDate) {
      sale.saleDate = new Date(data.saleDate).toISOString();
    }
    if (data.notes !== undefined) {
      sale.notes = data.notes.trim() || undefined;
    }

    // Reconcile serial numbers if updated
    if (data.serialNumbers !== undefined) {
      const newSerials = data.serialNumbers.map((s) => s.trim()).filter((s) => s.length > 0);
      if (newSerials.length === 0) {
        throw new Error('Sale must contain at least one panel serial number.');
      }
      const uniqueNew = new Set(newSerials);
      if (uniqueNew.size !== newSerials.length) {
        throw new Error('Duplicate serials in updated selection.');
      }

      // Panels removed from sale
      const removedSerials = sale.serialNumbers.filter((sn) => !newSerials.includes(sn));
      // Panels added to sale
      const addedSerials = newSerials.filter((sn) => !sale.serialNumbers.includes(sn));

      // Validate added serials are currently available and match wattage
      for (const sn of addedSerials) {
        const panel = this.panels.get(sn);
        if (!panel) throw new Error(`Serial "${sn}" not found in inventory.`);
        if (panel.status !== 'available') {
          throw new Error(`Serial "${sn}" is not available for sale.`);
        }
        if (panel.wattage !== sale.panelWattage) {
          throw new Error(
            `Serial "${sn}" has wattage ${panel.wattage}W, expected ${sale.panelWattage}W.`
          );
        }
      }

      // Reconcile: release removed panels
      for (const sn of removedSerials) {
        const p = this.panels.get(sn);
        if (p) {
          p.status = 'available';
          p.saleId = null;
          p.updatedAt = new Date().toISOString();
        }
      }

      // Reconcile: assign added panels
      for (const sn of addedSerials) {
        const p = this.panels.get(sn)!;
        p.status = 'sold';
        p.saleId = sale.id;
        p.updatedAt = new Date().toISOString();
      }

      sale.serialNumbers = newSerials;
      sale.quantity = newSerials.length;
    }

    if (data.unitSellingPrice !== undefined) {
      const price = Number(data.unitSellingPrice);
      if (isNaN(price) || price < 0) throw new Error('Unit selling price cannot be negative.');
      sale.unitSellingPrice = price;
    }

    sale.totalSellingAmount = Math.round(sale.quantity * sale.unitSellingPrice * 100) / 100;
    sale.updatedAt = new Date().toISOString();
    this.sales.set(sale.id, sale);
    return sale;
  }

  public deleteSale(id: string): boolean {
    const sale = this.sales.get(id);
    if (!sale) {
      throw new Error(`Sale transaction "${id}" not found.`);
    }

    // Reconcile: Return all sold panels back to 'available' status
    const now = new Date().toISOString();
    for (const sn of sale.serialNumbers) {
      const panel = this.panels.get(sn);
      if (panel) {
        panel.status = 'available';
        panel.saleId = null;
        panel.updatedAt = now;
      }
    }

    this.sales.delete(id);
    return true;
  }

  // ==========================================
  // INVENTORY & DASHBOARD AGGREGATIONS
  // ==========================================
  public getAllPanels(filters?: {
    wattage?: number;
    batchNumber?: string;
    status?: 'available' | 'sold';
    search?: string;
  }): PanelItem[] {
    let result = Array.from(this.panels.values());

    if (filters) {
      if (filters.wattage) {
        result = result.filter((p) => p.wattage === filters.wattage);
      }
      if (filters.batchNumber) {
        result = result.filter((p) => p.batchNumber.toLowerCase() === filters.batchNumber!.toLowerCase());
      }
      if (filters.status) {
        result = result.filter((p) => p.status === filters.status);
      }
      if (filters.search) {
        const q = filters.search.toLowerCase();
        result = result.filter(
          (p) =>
            p.serialNumber.toLowerCase().includes(q) ||
            p.batchNumber.toLowerCase().includes(q)
        );
      }
    }

    return result.sort((a, b) => a.serialNumber.localeCompare(b.serialNumber));
  }

  public getAvailablePanelsByWattage(wattage: number): PanelItem[] {
    return Array.from(this.panels.values()).filter(
      (p) => p.wattage === wattage && p.status === 'available'
    );
  }

  public getStockByWattage(): StockByWattage[] {
    const map = new Map<number, { available: number; sold: number; total: number; availableAmount: number }>();

    for (const panel of this.panels.values()) {
      const entry = map.get(panel.wattage) || { available: 0, sold: 0, total: 0, availableAmount: 0 };
      entry.total += 1;
      if (panel.status === 'available') {
        entry.available += 1;
        entry.availableAmount += panel.purchasePrice;
      } else {
        entry.sold += 1;
      }
      map.set(panel.wattage, entry);
    }

    const list: StockByWattage[] = [];
    for (const [wattage, data] of map.entries()) {
      list.push({
        wattage,
        availableCount: data.available,
        soldCount: data.sold,
        totalCount: data.total,
        availableAmount: data.availableAmount,
        lowStockAlert: data.available <= this.lowStockThreshold,
      });
    }

    return list.sort((a, b) => b.wattage - a.wattage);
  }

  public getStockByBatch(): StockByBatch[] {
    const map = new Map<string, { wattage: number; available: number; sold: number; total: number }>();

    for (const panel of this.panels.values()) {
      const key = `${panel.batchNumber}-${panel.wattage}`;
      const entry = map.get(key) || {
        wattage: panel.wattage,
        available: 0,
        sold: 0,
        total: 0,
      };
      entry.total += 1;
      if (panel.status === 'available') {
        entry.available += 1;
      } else {
        entry.sold += 1;
      }
      map.set(key, entry);
    }

    const list: StockByBatch[] = [];
    for (const [key, data] of map.entries()) {
      const batchNumber = key.split('-').slice(0, -1).join('-');
      list.push({
        batchNumber,
        wattage: data.wattage,
        availableCount: data.available,
        soldCount: data.sold,
        totalCount: data.total,
      });
    }

    return list.sort((a, b) => a.batchNumber.localeCompare(b.batchNumber));
  }

  public getDashboardSummary(): DashboardSummary {
    let totalAvailablePanels = 0;
    let totalPurchasedPanels = 0;
    let totalSoldPanels = 0;
    let totalStockValue = 0;

    for (const panel of this.panels.values()) {
      totalPurchasedPanels += 1;
      if (panel.status === 'available') {
        totalAvailablePanels += 1;
        totalStockValue += panel.purchasePrice;
      } else {
        totalSoldPanels += 1;
      }
    }

    const stockByWattage = this.getStockByWattage();
    const stockByBatch = this.getStockByBatch();

    const lowStockWarnings = stockByWattage
      .filter((s) => s.lowStockAlert)
      .map((s) => ({
        wattage: s.wattage,
        availableCount: s.availableCount,
        threshold: this.lowStockThreshold,
      }));

    const recentPurchases = this.getAllPurchases().slice(0, 5);
    const recentSales = this.getAllSales().slice(0, 5);

    let totalPurchaseAmount = 0;
    for (const p of this.purchases.values()) {
      totalPurchaseAmount += p.totalPurchaseAmount;
    }

    let totalSalesAmount = 0;
    for (const s of this.sales.values()) {
      totalSalesAmount += s.totalSellingAmount;
    }

    return {
      totalAvailablePanels,
      totalPurchasedPanels,
      totalSoldPanels,
      totalPurchaseAmount: Math.round(totalPurchaseAmount * 100) / 100,
      totalSalesAmount: Math.round(totalSalesAmount * 100) / 100,
      totalStockValue: Math.round(totalStockValue * 100) / 100,
      lowStockWarnings,
      stockByWattage,
      stockByBatch,
      recentPurchases,
      recentSales,
    };
  }
}

export const dataService = new DataService();

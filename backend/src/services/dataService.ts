import { v4 as uuidv4 } from 'uuid';
import mongoose from 'mongoose';
import { CustomerModel } from '../models/Customer.js';
import { PanelModel } from '../models/Panel.js';
import { PurchaseModel } from '../models/Purchase.js';
import { SaleModel } from '../models/Sale.js';
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
  private lowStockThreshold: number = parseInt(process.env.LOW_STOCK_THRESHOLD || '100', 10);

  constructor() {
    this.seedInitialData();
  }

  public async initDatabase(uri?: string) {
    const mongoUri = uri || process.env.MONGODB_URI;
    if (!mongoUri) return;

    try {
      if (mongoose.connection.readyState === 0) {
        await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 8000 });
        console.log('⚡ Connected to MongoDB Atlas:', mongoose.connection.name);
      }

      const customerCount = await CustomerModel.countDocuments();
      if (customerCount > 0) {
        console.log(`⚡ Hydrating in-memory store from MongoDB Atlas (${customerCount} customers found)...`);
        await this.hydrateFromMongo();
      } else {
        console.log('⚡ Clean database ready for real-world production usage.');
      }
    } catch (err: any) {
      console.warn('⚠️ MongoDB Atlas connection notice (using memory store):', err.message);
    }
  }

  private async hydrateFromMongo() {
    try {
      const [customers, panels, purchases, sales] = await Promise.all([
        CustomerModel.find().lean(),
        PanelModel.find().lean(),
        PurchaseModel.find().lean(),
        SaleModel.find().lean(),
      ]);

      if (customers.length > 0) {
        this.customers.clear();
        for (const c of customers) {
          this.customers.set(c.id, {
            id: c.id,
            consumerNumber: c.consumerNumber,
            phone: c.phone,
            name: c.name,
            address: c.address,
            createdAt: c.createdAt ? new Date(c.createdAt).toISOString() : new Date().toISOString(),
            updatedAt: c.updatedAt ? new Date(c.updatedAt).toISOString() : new Date().toISOString(),
          });
        }
      }

      if (panels.length > 0) {
        this.panels.clear();
        for (const p of panels) {
          this.panels.set(p.serialNumber, {
            id: p.id,
            serialNumber: p.serialNumber,
            batchNumber: p.batchNumber,
            wattage: p.wattage,
            purchaseId: p.purchaseId,
            purchasePrice: p.purchasePrice,
            status: p.status as 'available' | 'sold',
            saleId: p.saleId,
            createdAt: p.createdAt ? new Date(p.createdAt).toISOString() : new Date().toISOString(),
            updatedAt: p.updatedAt ? new Date(p.updatedAt).toISOString() : new Date().toISOString(),
          });
        }
      }

      if (purchases.length > 0) {
        this.purchases.clear();
        for (const pu of purchases) {
          this.purchases.set(pu.id, {
            id: pu.id,
            purchaseDate: pu.purchaseDate ? new Date(pu.purchaseDate).toISOString() : new Date().toISOString(),
            supplierName: pu.supplierName,
            batchNumber: pu.batchNumber,
            wattage: pu.wattage,
            quantity: pu.quantity,
            serialNumbers: pu.serialNumbers,
            unitPurchasePrice: pu.unitPurchasePrice,
            totalPurchaseAmount: pu.totalPurchaseAmount,
            notes: pu.notes,
            createdAt: pu.createdAt ? new Date(pu.createdAt).toISOString() : new Date().toISOString(),
            updatedAt: pu.updatedAt ? new Date(pu.updatedAt).toISOString() : new Date().toISOString(),
          });
        }
      }

      if (sales.length > 0) {
        this.sales.clear();
        for (const s of sales) {
          this.sales.set(s.id, {
            id: s.id,
            saleDate: s.saleDate ? new Date(s.saleDate).toISOString() : new Date().toISOString(),
            customerId: s.customerId,
            consumerNumber: s.consumerNumber,
            customerName: s.customerName,
            panelWattage: s.panelWattage,
            quantity: s.quantity,
            serialNumbers: s.serialNumbers,
            unitSellingPrice: s.unitSellingPrice,
            totalSellingAmount: s.totalSellingAmount,
            notes: s.notes,
            createdAt: s.createdAt ? new Date(s.createdAt).toISOString() : new Date().toISOString(),
            updatedAt: s.updatedAt ? new Date(s.updatedAt).toISOString() : new Date().toISOString(),
          });
        }
      }
    } catch (err: any) {
      console.warn('⚠️ Error hydrating from MongoDB:', err.message);
    }
  }

  private async syncToMongo() {
    try {
      for (const c of this.customers.values()) {
        await CustomerModel.findOneAndUpdate({ id: c.id }, c, { upsert: true });
      }
      for (const p of this.panels.values()) {
        await PanelModel.findOneAndUpdate({ serialNumber: p.serialNumber }, p, { upsert: true });
      }
      for (const pu of this.purchases.values()) {
        await PurchaseModel.findOneAndUpdate({ id: pu.id }, pu, { upsert: true });
      }
      for (const s of this.sales.values()) {
        await SaleModel.findOneAndUpdate({ id: s.id }, s, { upsert: true });
      }
    } catch (e: any) {
      console.warn('⚠️ Sync to MongoDB error:', e.message);
    }
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
    // Clean initial state for real-world production usage
  }

  public async clearAllData() {
    this.customers.clear();
    this.purchases.clear();
    this.sales.clear();
    this.panels.clear();
    if (mongoose.connection.readyState === 1) {
      await Promise.all([
        CustomerModel.deleteMany({}),
        PanelModel.deleteMany({}),
        PurchaseModel.deleteMany({}),
        SaleModel.deleteMany({}),
      ]);
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
    if (mongoose.connection.readyState === 1) {
      CustomerModel.create(customer).catch((e) =>
        console.warn('Mongo create customer err:', e.message)
      );
    }
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
    if (mongoose.connection.readyState === 1) {
      CustomerModel.findOneAndUpdate({ id: customer.id }, customer).catch((e) =>
        console.warn('Mongo update customer err:', e.message)
      );
    }
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
    if (mongoose.connection.readyState === 1) {
      CustomerModel.deleteOne({ id }).catch((e) =>
        console.warn('Mongo delete customer err:', e.message)
      );
    }
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
    const newPanels: PanelItem[] = [];
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
      newPanels.push(panel);
    }

    if (mongoose.connection.readyState === 1) {
      PurchaseModel.create(purchase).catch((e) =>
        console.warn('Mongo create purchase err:', e.message)
      );
      PanelModel.insertMany(newPanels).catch((e) =>
        console.warn('Mongo insert panels err:', e.message)
      );
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
      serialNumbers?: string[];
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
      for (const sn of purchase.serialNumbers) {
        const p = this.panels.get(sn);
        if (p) p.purchasePrice = price;
      }
    }
    if (data.notes !== undefined) {
      purchase.notes = data.notes.trim() || undefined;
    }

    // Reconcile serial numbers if updated or added
    let removedSerials: string[] = [];
    let newPanels: PanelItem[] = [];

    if (data.serialNumbers !== undefined) {
      const newSerials = data.serialNumbers
        .map((s) => s.trim().toUpperCase())
        .filter((s) => s.length > 0);
      if (newSerials.length === 0) {
        throw new Error('Purchase batch must contain at least one panel serial number.');
      }
      const uniqueSet = new Set(newSerials);
      if (uniqueSet.size !== newSerials.length) {
        throw new Error('Duplicate serial numbers in updated batch list.');
      }

      const oldSerialsUpper = new Set(purchase.serialNumbers.map((s) => s.toUpperCase()));
      removedSerials = purchase.serialNumbers.filter((sn) => !uniqueSet.has(sn.toUpperCase()));
      const addedSerials = newSerials.filter((sn) => !oldSerialsUpper.has(sn));

      // Validate removed panels: cannot remove if already sold
      for (const sn of removedSerials) {
        const panel = this.panels.get(sn);
        if (panel && panel.status === 'sold') {
          throw new Error(
            `Cannot remove panel "${sn}" from batch "${purchase.batchNumber}" because it has already been sold in sale "${panel.saleId}".`
          );
        }
      }

      // Validate added panels: cannot already exist in inventory
      for (const sn of addedSerials) {
        if (this.panels.has(sn)) {
          const existing = this.panels.get(sn)!;
          throw new Error(
            `Serial number "${sn}" already exists in inventory (Batch: ${existing.batchNumber}, Status: ${existing.status}).`
          );
        }
      }

      // Remove panels
      for (const sn of removedSerials) {
        this.panels.delete(sn);
      }

      // Add new panels
      for (const sn of addedSerials) {
        const panel: PanelItem = {
          id: uuidv4(),
          serialNumber: sn,
          batchNumber: purchase.batchNumber,
          wattage: purchase.wattage,
          purchaseId: purchase.id,
          purchasePrice: purchase.unitPurchasePrice,
          status: 'available',
          saleId: null,
          createdAt: purchase.purchaseDate || new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        this.panels.set(sn, panel);
        newPanels.push(panel);
      }

      purchase.serialNumbers = newSerials;
      purchase.quantity = newSerials.length;
    }

    purchase.totalPurchaseAmount =
      Math.round(purchase.quantity * purchase.unitPurchasePrice * 100) / 100;
    purchase.updatedAt = new Date().toISOString();
    this.purchases.set(purchase.id, purchase);

    if (mongoose.connection.readyState === 1) {
      PurchaseModel.findOneAndUpdate({ id: purchase.id }, purchase).catch((e) =>
        console.warn('Mongo update purchase err:', e.message)
      );
      if (removedSerials.length > 0) {
        PanelModel.deleteMany({ serialNumber: { $in: removedSerials } }).catch((e) =>
          console.warn('Mongo remove panels err:', e.message)
        );
      }
      if (newPanels.length > 0) {
        PanelModel.insertMany(newPanels).catch((e) =>
          console.warn('Mongo insert new panels err:', e.message)
        );
      }
      PanelModel.updateMany(
        { serialNumber: { $in: purchase.serialNumbers } },
        {
          batchNumber: purchase.batchNumber,
          purchasePrice: purchase.unitPurchasePrice,
          updatedAt: purchase.updatedAt,
        }
      ).catch((e) => console.warn('Mongo update panels err:', e.message));
    }

    return purchase;
  }

  public addPanelsToPurchase(id: string, newSerialsToAdd: string[]): PurchaseTransaction {
    const purchase = this.purchases.get(id);
    if (!purchase) {
      throw new Error(`Purchase record "${id}" not found.`);
    }
    const cleanNew = newSerialsToAdd
      .map((s) => s.trim().toUpperCase())
      .filter((s) => s.length > 0);
    if (cleanNew.length === 0) {
      throw new Error('At least one serial number is required.');
    }
    return this.updatePurchase(id, {
      serialNumbers: [...purchase.serialNumbers, ...cleanNew],
    });
  }

  public updatePanelSerial(
    purchaseId: string,
    oldSerialRaw: string,
    newSerialRaw: string
  ): PurchaseTransaction {
    const purchase = this.purchases.get(purchaseId);
    if (!purchase) {
      throw new Error(`Purchase record "${purchaseId}" not found.`);
    }

    const oldSerial = oldSerialRaw.trim();
    const newSerial = newSerialRaw.trim().toUpperCase();
    if (!newSerial) {
      throw new Error('New serial number cannot be empty.');
    }
    if (oldSerial.toUpperCase() === newSerial) {
      return purchase;
    }

    const snIndex = purchase.serialNumbers.findIndex(
      (s) => s.toUpperCase() === oldSerial.toUpperCase()
    );
    if (snIndex === -1) {
      throw new Error(
        `Serial "${oldSerial}" not found in purchase batch "${purchase.batchNumber}".`
      );
    }

    if (this.panels.has(newSerial)) {
      const existing = this.panels.get(newSerial)!;
      throw new Error(
        `Serial number "${newSerial}" already exists in inventory (Batch: ${existing.batchNumber}, Status: ${existing.status}).`
      );
    }

    const actualOld = purchase.serialNumbers[snIndex];
    const panel = this.panels.get(actualOld);
    this.panels.delete(actualOld);

    if (panel) {
      panel.serialNumber = newSerial;
      panel.updatedAt = new Date().toISOString();
      this.panels.set(newSerial, panel);

      if (panel.status === 'sold' && panel.saleId) {
        const sale = this.sales.get(panel.saleId);
        if (sale) {
          const saleIdx = sale.serialNumbers.findIndex(
            (s) => s.toUpperCase() === actualOld.toUpperCase()
          );
          if (saleIdx !== -1) {
            sale.serialNumbers[saleIdx] = newSerial;
            sale.updatedAt = new Date().toISOString();
            if (mongoose.connection.readyState === 1) {
              SaleModel.findOneAndUpdate({ id: sale.id }, sale).catch((e) =>
                console.warn('Mongo update sale for renamed serial err:', e.message)
              );
            }
          }
        }
      }
    }

    purchase.serialNumbers[snIndex] = newSerial;
    purchase.updatedAt = new Date().toISOString();
    this.purchases.set(purchase.id, purchase);

    if (mongoose.connection.readyState === 1) {
      PurchaseModel.findOneAndUpdate({ id: purchase.id }, purchase).catch((e) =>
        console.warn('Mongo update purchase serial err:', e.message)
      );
      PanelModel.findOneAndUpdate(
        { serialNumber: actualOld },
        { serialNumber: newSerial, updatedAt: new Date().toISOString() }
      ).catch((e) => console.warn('Mongo update panel serial err:', e.message));
    }

    return purchase;
  }

  public deletePanelFromPurchase(id: string, serialNumberRaw: string): PurchaseTransaction {
    const purchase = this.purchases.get(id);
    if (!purchase) {
      throw new Error(`Purchase record "${id}" not found.`);
    }
    const sn = serialNumberRaw.trim().toUpperCase();
    const filtered = purchase.serialNumbers.filter((s) => s.toUpperCase() !== sn);
    if (filtered.length === purchase.serialNumbers.length) {
      throw new Error(
        `Serial "${serialNumberRaw}" not found in purchase "${purchase.batchNumber}".`
      );
    }
    return this.updatePurchase(id, { serialNumbers: filtered });
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

    if (mongoose.connection.readyState === 1) {
      PurchaseModel.deleteOne({ id }).catch((e) =>
        console.warn('Mongo delete purchase err:', e.message)
      );
      PanelModel.deleteMany({ serialNumber: { $in: purchase.serialNumbers } }).catch(
        (e) => console.warn('Mongo delete panels err:', e.message)
      );
    }

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

    if (mongoose.connection.readyState === 1) {
      SaleModel.create(sale).catch((e) =>
        console.warn('Mongo create sale err:', e.message)
      );
      PanelModel.updateMany(
        { serialNumber: { $in: serials } },
        { status: 'sold', saleId: sale.id, updatedAt: now }
      ).catch((e) => console.warn('Mongo update sold panels err:', e.message));
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

    if (mongoose.connection.readyState === 1) {
      SaleModel.findOneAndUpdate({ id: sale.id }, sale).catch((e) =>
        console.warn('Mongo update sale err:', e.message)
      );
      PanelModel.updateMany(
        { saleId: sale.id },
        { status: 'available', saleId: null, updatedAt: sale.updatedAt }
      )
        .then(() =>
          PanelModel.updateMany(
            { serialNumber: { $in: sale.serialNumbers } },
            { status: 'sold', saleId: sale.id, updatedAt: sale.updatedAt }
          )
        )
        .catch((e) => console.warn('Mongo update sale panels err:', e.message));
    }

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

    if (mongoose.connection.readyState === 1) {
      SaleModel.deleteOne({ id }).catch((e) =>
        console.warn('Mongo delete sale err:', e.message)
      );
      PanelModel.updateMany(
        { serialNumber: { $in: sale.serialNumbers } },
        { status: 'available', saleId: null, updatedAt: now }
      ).catch((e) => console.warn('Mongo revert sold panels err:', e.message));
    }

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

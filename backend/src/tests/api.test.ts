import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../app.js';
import { DataService, dataService } from '../services/dataService.js';

describe('Horizone StockFlow Backend API & Inventory Rules', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp();
  });

  describe('Health Endpoint', () => {
    it('should return healthy status', async () => {
      const res = await request(app).get('/api/v1/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body.service).toBe('Horizone StockFlow API');
    });
  });

  describe('Customer Business Rules & Validation', () => {
    it('requires mandatory consumerNumber and phone', async () => {
      const res = await request(app).post('/api/v1/customers').send({
        name: 'Incomplete Customer',
      });
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error).toMatch(/consumer number is mandatory/i);
    });

    it('requires mandatory phone when consumerNumber is given', async () => {
      const res = await request(app).post('/api/v1/customers').send({
        consumerNumber: '9988776655443',
        name: 'No Phone Customer',
      });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/phone number is mandatory/i);
    });

    it('creates valid customer with optional fields', async () => {
      const res = await request(app).post('/api/v1/customers').send({
        consumerNumber: '9988112233445',
        phone: '+91 99955 12345',
        name: 'Priya Pillai',
        address: 'Aluva, Ernakulam',
      });
      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.consumerNumber).toBe('9988112233445');
      expect(res.body.data.id).toBeDefined();
    });

    it('rejects duplicate KSEB consumer number', async () => {
      // First creation
      const consumer = '1122334455667';
      await request(app).post('/api/v1/customers').send({
        consumerNumber: consumer,
        phone: '+91 98980 00001',
        name: 'First User',
      });

      // Second creation with same consumer number
      const duplicateRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: consumer,
        phone: '+91 98980 00002',
        name: 'Duplicate User',
      });

      expect(duplicateRes.status).toBe(400);
      expect(duplicateRes.body.success).toBe(false);
      expect(duplicateRes.body.error).toMatch(/already exists/i);
    });

    it('prevents unsafe deletion of customer with linked sales', async () => {
      // Create test customer
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '9988776611223',
        phone: '+91 98470 99999',
        name: 'Linked Sale Cust',
      });
      const custId = custRes.body.data.id;

      // Create test purchase
      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-LINK-TEST',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 10000,
        serialNumbers: ['SN-LINK-TEST-001'],
      });

      // Create test sale
      await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        unitSellingPrice: 13000,
        serialNumbers: ['SN-LINK-TEST-001'],
      });

      const res = await request(app).delete(`/api/v1/customers/${custId}`);
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error).toMatch(/linked sale transaction/i);
    });
  });

  describe('Purchase & Serial Number Inventory Rules', () => {
    it('validates wattage, quantity and unit purchase price', async () => {
      const res = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-TEST-1',
        wattage: -50,
        quantity: 5,
        unitPurchasePrice: 1000,
        serialNumbers: ['S1', 'S2', 'S3', 'S4', 'S5'],
      });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/positive integer/i);
    });

    it('validates serial numbers count matches quantity', async () => {
      const res = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-TEST-2',
        wattage: 550,
        quantity: 3,
        unitPurchasePrice: 12000,
        serialNumbers: ['S1', 'S2'], // only 2 serials for 3 panels
      });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/must match the purchase quantity/i);
    });

    it('rejects duplicate serial numbers inside the same batch entry', async () => {
      const res = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-TEST-3',
        wattage: 550,
        quantity: 2,
        unitPurchasePrice: 12000,
        serialNumbers: ['DUPLICATE-SN-1', 'DUPLICATE-SN-1'],
      });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/duplicate serial number/i);
    });

    it('rejects serial numbers that already exist in inventory', async () => {
      // Create first purchase
      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-TEST-4A',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 11000,
        serialNumbers: ['GLOBAL-UNIQUE-SN-999'],
      });

      // Try to create another purchase with the same serial number
      const duplicateRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-TEST-4B',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 11000,
        serialNumbers: ['GLOBAL-UNIQUE-SN-999'],
      });

      expect(duplicateRes.status).toBe(400);
      expect(duplicateRes.body.error).toMatch(/already exists in inventory/i);
    });

    it('prevents deleting purchase if panels have been sold', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '8877665544332',
        phone: '+91 98470 88888',
        name: 'Sold Purchase Cust',
      });
      const custId = custRes.body.data.id;

      const purchRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-DEL-PURCH-TEST',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 10000,
        serialNumbers: ['SN-DEL-PURCH-001'],
      });
      const purchId = purchRes.body.data.id;

      await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        unitSellingPrice: 13000,
        serialNumbers: ['SN-DEL-PURCH-001'],
      });

      const res = await request(app).delete(`/api/v1/purchases/${purchId}`);
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error).toMatch(/have already been sold/i);
    });

    it('allows adding more panels to an existing purchase batch later', async () => {
      const purchaseRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-ADD-MORE',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 12000,
        serialNumbers: ['INITIAL-PANEL-001'],
      });
      expect(purchaseRes.status).toBe(201);
      const purchId = purchaseRes.body.data.id;

      // Add two more panels later
      const addRes = await request(app)
        .post(`/api/v1/purchases/${purchId}/panels`)
        .send({ serialNumbers: ['INITIAL-PANEL-002', 'INITIAL-PANEL-003'] });

      expect(addRes.status).toBe(200);
      expect(addRes.body.data.quantity).toBe(3);
      expect(addRes.body.data.totalPurchaseAmount).toBe(36000);
      expect(addRes.body.data.serialNumbers).toEqual([
        'INITIAL-PANEL-001',
        'INITIAL-PANEL-002',
        'INITIAL-PANEL-003',
      ]);

      // Verify the new panels exist in inventory
      const invRes = await request(app).get('/api/v1/inventory?batch=BATCH-ADD-MORE');
      expect(invRes.body.data.length).toBe(3);
      expect(invRes.body.data.map((p: any) => p.serialNumber)).toContain('INITIAL-PANEL-003');
    });

    it('allows editing an existing panel serial number in a batch', async () => {
      const purchaseRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-EDIT-PANEL',
        wattage: 450,
        quantity: 1,
        unitPurchasePrice: 10000,
        serialNumbers: ['TYPO-PANEL-999'],
      });
      const purchId = purchaseRes.body.data.id;

      // Correct typo in serial number
      const editRes = await request(app)
        .put(`/api/v1/purchases/${purchId}/panels/TYPO-PANEL-999`)
        .send({ newSerialNumber: 'FIXED-PANEL-999' });

      expect(editRes.status).toBe(200);
      expect(editRes.body.data.serialNumbers).toContain('FIXED-PANEL-999');
      expect(editRes.body.data.serialNumbers).not.toContain('TYPO-PANEL-999');

      // Verify inventory reflects the renamed panel
      const oldCheck = await request(app).get('/api/v1/inventory?search=TYPO-PANEL-999');
      expect(oldCheck.body.data.length).toBe(0);

      const newCheck = await request(app).get('/api/v1/inventory?search=FIXED-PANEL-999');
      expect(newCheck.body.data.length).toBe(1);
      expect(newCheck.body.data[0].serialNumber).toBe('FIXED-PANEL-999');
      expect(newCheck.body.data[0].batchNumber).toBe('BATCH-EDIT-PANEL');
    });
  });

  describe('Sales Allocation & Inventory Deduction', () => {
    it('successfully sells available panels and updates inventory', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '7766554433221',
        phone: '+91 98470 77777',
        name: 'Sale Test Cust',
      });
      const custId = custRes.body.data.id;

      const purchaseRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-SALE-TEST',
        wattage: 400,
        quantity: 2,
        unitPurchasePrice: 8000,
        serialNumbers: ['SALE-TEST-SN-1', 'SALE-TEST-SN-2'],
      });
      expect(purchaseRes.status).toBe(201);

      // Verify panel is available
      const panelBefore = await request(app).get('/api/v1/inventory?search=SALE-TEST-SN-1');
      expect(panelBefore.body.data[0].status).toBe('available');

      // Sell one panel
      const saleRes = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 400,
        unitSellingPrice: 11500,
        serialNumbers: ['SALE-TEST-SN-1'],
      });

      expect(saleRes.status).toBe(201);
      expect(saleRes.body.data.quantity).toBe(1);
      expect(saleRes.body.data.totalSellingAmount).toBe(11500);

      // Verify panel status is now 'sold'
      const panelAfter = await request(app).get('/api/v1/inventory?search=SALE-TEST-SN-1');
      expect(panelAfter.body.data[0].status).toBe('sold');
      expect(panelAfter.body.data[0].saleId).toBe(saleRes.body.data.id);
    });

    it('rejects selling a panel that is already sold', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '6655443322110',
        phone: '+91 98470 66666',
        name: 'Double Sell Cust',
      });
      const custId = custRes.body.data.id;

      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-DOUBLE-SELL',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 10000,
        serialNumbers: ['SN-DOUBLE-SELL-1'],
      });

      await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        unitSellingPrice: 13000,
        serialNumbers: ['SN-DOUBLE-SELL-1'],
      });

      const res = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        unitSellingPrice: 13000,
        serialNumbers: ['SN-DOUBLE-SELL-1'],
      });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/already marked as sold/i);
    });

    it('rejects selling panel with mismatched wattage', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '5544332211009',
        phone: '+91 98470 55555',
        name: 'Wattage Mismatch Cust',
      });
      const custId = custRes.body.data.id;

      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-WATT-TEST',
        wattage: 450,
        quantity: 1,
        unitPurchasePrice: 9000,
        serialNumbers: ['SN-WATT-450-TEST'],
      });

      const res = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540, // mismatch
        unitSellingPrice: 15000,
        serialNumbers: ['SN-WATT-450-TEST'],
      });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/does not match requested sale wattage/i);
    });

    it('reconciles inventory when a sale is deleted', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '4433221100998',
        phone: '+91 98470 44444',
        name: 'Sale Delete Cust',
      });
      const custId = custRes.body.data.id;

      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-RECONCILE',
        wattage: 450,
        quantity: 1,
        unitPurchasePrice: 9000,
        serialNumbers: ['SN-RECONCILE-TEST'],
      });

      const saleRes = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 450,
        unitSellingPrice: 12000,
        serialNumbers: ['SN-RECONCILE-TEST'],
      });
      expect(saleRes.status).toBe(201);

      // Check status is sold
      let panel = await request(app).get('/api/v1/inventory?search=SN-RECONCILE-TEST');
      expect(panel.body.data[0].status).toBe('sold');

      // Delete the sale
      const delRes = await request(app).delete(`/api/v1/sales/${saleRes.body.data.id}`);
      expect(delRes.status).toBe(200);

      // Verify panel is restored to 'available'
      panel = await request(app).get('/api/v1/inventory?search=SN-RECONCILE-TEST');
      expect(panel.body.data[0].status).toBe('available');
      expect(panel.body.data[0].saleId).toBeNull();
    });

    it('reconciles inventory when a sale is updated with new panel serials', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '9988776655443',
        phone: '+91 98470 99887',
        name: 'Sale Update Cust',
      });
      const custId = custRes.body.data.id;

      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-SALE-UPDATE',
        wattage: 540,
        quantity: 3,
        unitPurchasePrice: 11000,
        serialNumbers: ['SN-UPD-1', 'SN-UPD-2', 'SN-UPD-3'],
      });

      // Sell SN-UPD-1 and SN-UPD-2
      const saleRes = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        unitSellingPrice: 15000,
        serialNumbers: ['SN-UPD-1', 'SN-UPD-2'],
      });
      expect(saleRes.status).toBe(201);
      const saleId = saleRes.body.data.id;

      // Update sale: swap SN-UPD-2 for SN-UPD-3
      const updateRes = await request(app).put(`/api/v1/sales/${saleId}`).send({
        serialNumbers: ['SN-UPD-1', 'SN-UPD-3'],
      });
      expect(updateRes.status).toBe(200);
      expect(updateRes.body.data.serialNumbers).toEqual(['SN-UPD-1', 'SN-UPD-3']);

      // SN-UPD-2 should be available again
      const p2 = await request(app).get('/api/v1/inventory?search=SN-UPD-2');
      expect(p2.body.data[0].status).toBe('available');

      // SN-UPD-3 should now be sold
      const p3 = await request(app).get('/api/v1/inventory?search=SN-UPD-3');
      expect(p3.body.data[0].status).toBe('sold');
      expect(p3.body.data[0].saleId).toBe(saleId);
    });
  });

  describe('Inventory Grouping & Dashboard Reporting', () => {
    it('groups inventory correctly by wattage', async () => {
      await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-GROUP-TEST',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 10000,
        serialNumbers: ['SN-GROUP-540-1'],
      });

      const res = await request(app).get('/api/v1/inventory/by-wattage');
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThan(0);
      for (const item of res.body.data) {
        expect(item.wattage).toBeGreaterThan(0);
        expect(item.totalCount).toBe(item.availableCount + item.soldCount);
      }
    });

    it('provides comprehensive dashboard summary without conflating wattage and money', async () => {
      const res = await request(app).get('/api/v1/dashboard');
      expect(res.status).toBe(200);
      const data = res.body.data;
      expect(typeof data.totalAvailablePanels).toBe('number');
      expect(typeof data.totalPurchasedPanels).toBe('number');
      expect(typeof data.totalSoldPanels).toBe('number');
      expect(typeof data.totalStockValue).toBe('number');
      expect(Array.isArray(data.lowStockWarnings)).toBe(true);
      expect(Array.isArray(data.recentPurchases)).toBe(true);
      expect(Array.isArray(data.recentSales)).toBe(true);
    });
  });

  describe('Panel Type (DCR & Non DCR) Invariants', () => {
    it('defaults purchase and created panels to DCR if type is omitted', async () => {
      const purRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-DCR-DEF',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 10000,
        serialNumbers: ['SN-DCR-DEF-1'],
      });
      expect(purRes.status).toBe(201);
      expect(purRes.body.data.type).toBe('DCR');

      const panelRes = await request(app).get('/api/v1/inventory?search=SN-DCR-DEF-1');
      expect(panelRes.status).toBe(200);
      expect(panelRes.body.data[0].type).toBe('DCR');
    });

    it('records Non DCR purchase and creates Non DCR panels', async () => {
      const purRes = await request(app).post('/api/v1/purchases').send({
        batchNumber: 'BATCH-NON-DCR',
        wattage: 540,
        type: 'Non DCR',
        quantity: 1,
        unitPurchasePrice: 9500,
        serialNumbers: ['SN-NON-DCR-1'],
      });
      expect(purRes.status).toBe(201);
      expect(purRes.body.data.type).toBe('Non DCR');

      const panelRes = await request(app).get('/api/v1/inventory?search=SN-NON-DCR-1');
      expect(panelRes.status).toBe(200);
      expect(panelRes.body.data[0].type).toBe('Non DCR');
    });

    it('rejects selling Non DCR panel when sale requests DCR panels', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '3344556677889',
        phone: '+91 97777 88888',
        name: 'Type Test Cust',
      });
      const custId = custRes.body.data.id;

      // Try to sell the Non DCR panel in a DCR sale
      const saleRes = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        type: 'DCR',
        unitSellingPrice: 13000,
        serialNumbers: ['SN-NON-DCR-1'],
      });
      expect(saleRes.status).toBe(400);
      expect(saleRes.body.error).toMatch(/does not match requested sale type DCR/i);
    });

    it('successfully sells Non DCR panels when sale requests Non DCR', async () => {
      const custRes = await request(app).post('/api/v1/customers').send({
        consumerNumber: '4455667788990',
        phone: '+91 96666 77777',
        name: 'Non DCR Buyer',
      });
      const custId = custRes.body.data.id;

      const saleRes = await request(app).post('/api/v1/sales').send({
        customerId: custId,
        panelWattage: 540,
        type: 'Non DCR',
        unitSellingPrice: 12000,
        serialNumbers: ['SN-NON-DCR-1'],
      });
      expect(saleRes.status).toBe(201);
      expect(saleRes.body.data.type).toBe('Non DCR');
    });
  });
});

import { Request, Response, NextFunction } from 'express';
import { dataService } from '../services/dataService.js';

export const getPurchases = (req: Request, res: Response, next: NextFunction) => {
  try {
    const { batch, wattage, search } = req.query;
    let purchases = dataService.getAllPurchases();

    if (batch && typeof batch === 'string') {
      purchases = purchases.filter((p) => p.batchNumber.toLowerCase() === batch.toLowerCase());
    }
    if (wattage && !isNaN(Number(wattage))) {
      purchases = purchases.filter((p) => p.wattage === Number(wattage));
    }
    if (search && typeof search === 'string') {
      const q = search.toLowerCase().trim();
      purchases = purchases.filter(
        (p) =>
          p.batchNumber.toLowerCase().includes(q) ||
          (p.supplierName && p.supplierName.toLowerCase().includes(q)) ||
          p.serialNumbers.some((sn) => sn.toLowerCase().includes(q))
      );
    }

    res.json({ success: true, count: purchases.length, data: purchases });
  } catch (error) {
    next(error);
  }
};

export const getPurchaseById = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    const purchase = dataService.getPurchaseById(id);
    if (!purchase) {
      return res.status(404).json({ success: false, error: 'Purchase record not found' });
    }
    res.json({ success: true, data: purchase });
  } catch (error) {
    next(error);
  }
};

export const createPurchase = (req: Request, res: Response, next: NextFunction) => {
  try {
    const purchase = dataService.createPurchase(req.body);
    res.status(201).json({
      success: true,
      message: 'Purchase recorded and panel inventory updated successfully',
      data: purchase,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
};

export const updatePurchase = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    const purchase = dataService.updatePurchase(id, req.body);
    res.json({
      success: true,
      message: 'Purchase updated successfully',
      data: purchase,
    });
  } catch (error: any) {
    const status = error.message?.includes('not found') ? 404 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
};

export const deletePurchase = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    dataService.deletePurchase(id);
    res.json({
      success: true,
      message: 'Purchase and uncommitted inventory panels deleted successfully',
    });
  } catch (error: any) {
    const status = error.message?.includes('not found') ? 404 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
};

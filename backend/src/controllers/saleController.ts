import { Request, Response, NextFunction } from 'express';
import { dataService } from '../services/dataService.js';

export const getSales = (req: Request, res: Response, next: NextFunction) => {
  try {
    const { customerId, wattage, search } = req.query;
    let sales = dataService.getAllSales();

    if (customerId && typeof customerId === 'string') {
      sales = sales.filter((s) => s.customerId === customerId);
    }
    if (wattage && !isNaN(Number(wattage))) {
      sales = sales.filter((s) => s.panelWattage === Number(wattage));
    }
    if (search && typeof search === 'string') {
      const q = search.toLowerCase().trim();
      sales = sales.filter(
        (s) =>
          s.consumerNumber.toLowerCase().includes(q) ||
          (s.customerName && s.customerName.toLowerCase().includes(q)) ||
          s.serialNumbers.some((sn) => sn.toLowerCase().includes(q))
      );
    }

    res.json({ success: true, count: sales.length, data: sales });
  } catch (error) {
    next(error);
  }
};

export const getSaleById = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    const sale = dataService.getSaleById(id);
    if (!sale) {
      return res.status(404).json({ success: false, error: 'Sale record not found' });
    }
    res.json({ success: true, data: sale });
  } catch (error) {
    next(error);
  }
};

export const createSale = (req: Request, res: Response, next: NextFunction) => {
  try {
    const sale = dataService.createSale(req.body);
    res.status(201).json({
      success: true,
      message: 'Sale committed and panel inventory deducted successfully',
      data: sale,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
};

export const updateSale = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    const sale = dataService.updateSale(id, req.body);
    res.json({
      success: true,
      message: 'Sale updated and panel allocations reconciled successfully',
      data: sale,
    });
  } catch (error: any) {
    const status = error.message?.includes('not found') ? 404 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
};

export const deleteSale = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    dataService.deleteSale(id);
    res.json({
      success: true,
      message: 'Sale deleted and allocated panels returned to available inventory',
    });
  } catch (error: any) {
    const status = error.message?.includes('not found') ? 404 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
};

import { Request, Response, NextFunction } from 'express';
import { dataService } from '../services/dataService.js';

export const getInventory = (req: Request, res: Response, next: NextFunction) => {
  try {
    const { wattage, batch, status, search } = req.query;
    const filters: any = {};

    if (wattage && !isNaN(Number(wattage))) {
      filters.wattage = Number(wattage);
    }
    if (batch && typeof batch === 'string') {
      filters.batchNumber = batch;
    }
    if (status === 'available' || status === 'sold') {
      filters.status = status;
    }
    if (search && typeof search === 'string') {
      filters.search = search;
    }

    const panels = dataService.getAllPanels(filters);
    res.json({ success: true, count: panels.length, data: panels });
  } catch (error) {
    next(error);
  }
};

export const getAvailablePanelsByWattage = (req: Request, res: Response, next: NextFunction) => {
  try {
    const wattage = Number(String(req.params.wattage));
    if (isNaN(wattage) || wattage <= 0) {
      return res.status(400).json({ success: false, error: 'Invalid wattage parameter' });
    }
    const panels = dataService.getAvailablePanelsByWattage(wattage);
    res.json({ success: true, count: panels.length, data: panels });
  } catch (error) {
    next(error);
  }
};

export const getStockByWattage = (_req: Request, res: Response, next: NextFunction) => {
  try {
    const stock = dataService.getStockByWattage();
    res.json({ success: true, data: stock });
  } catch (error) {
    next(error);
  }
};

export const getStockByBatch = (_req: Request, res: Response, next: NextFunction) => {
  try {
    const stock = dataService.getStockByBatch();
    res.json({ success: true, data: stock });
  } catch (error) {
    next(error);
  }
};

export const getDashboardSummary = (_req: Request, res: Response, next: NextFunction) => {
  try {
    const summary = dataService.getDashboardSummary();
    res.json({ success: true, data: summary });
  } catch (error) {
    next(error);
  }
};

export const getHealth = (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'Horizone StockFlow API',
    version: '1.0.0',
    mode: 'development-in-memory',
    uptimeSeconds: Math.floor(process.uptime()),
  });
};

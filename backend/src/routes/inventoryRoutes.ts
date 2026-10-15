import { Router } from 'express';
import {
  getInventory,
  getAvailablePanelsByWattage,
  getStockByWattage,
  getStockByBatch,
  getDashboardSummary,
  getHealth,
} from '../controllers/inventoryController.js';

const router = Router();

router.get('/inventory', getInventory);
router.get('/inventory/by-wattage', getStockByWattage);
router.get('/inventory/by-batch', getStockByBatch);
router.get('/inventory/available/:wattage', getAvailablePanelsByWattage);
router.get('/dashboard', getDashboardSummary);
router.get('/health', getHealth);

export default router;

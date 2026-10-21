import { Router } from 'express';
import {
  getPurchases,
  getPurchaseById,
  createPurchase,
  updatePurchase,
  deletePurchase,
  addPanelsToPurchase,
  updatePanelSerial,
  deletePanelFromPurchase,
} from '../controllers/purchaseController.js';

const router = Router();

router.route('/')
  .get(getPurchases)
  .post(createPurchase);

router.route('/:id')
  .get(getPurchaseById)
  .put(updatePurchase)
  .delete(deletePurchase);

router.route('/:id/panels')
  .post(addPanelsToPurchase);

router.route('/:id/panels/:serial')
  .put(updatePanelSerial)
  .delete(deletePanelFromPurchase);

export default router;

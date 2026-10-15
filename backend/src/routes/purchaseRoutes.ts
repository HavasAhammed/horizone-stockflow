import { Router } from 'express';
import {
  getPurchases,
  getPurchaseById,
  createPurchase,
  updatePurchase,
  deletePurchase,
} from '../controllers/purchaseController.js';

const router = Router();

router.route('/')
  .get(getPurchases)
  .post(createPurchase);

router.route('/:id')
  .get(getPurchaseById)
  .put(updatePurchase)
  .delete(deletePurchase);

export default router;

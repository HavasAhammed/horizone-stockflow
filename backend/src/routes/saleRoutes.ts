import { Router } from 'express';
import {
  getSales,
  getSaleById,
  createSale,
  updateSale,
  deleteSale,
} from '../controllers/saleController.js';

const router = Router();

router.route('/')
  .get(getSales)
  .post(createSale);

router.route('/:id')
  .get(getSaleById)
  .put(updateSale)
  .delete(deleteSale);

export default router;

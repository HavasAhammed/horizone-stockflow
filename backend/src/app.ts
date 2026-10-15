import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import morgan from 'morgan';
import dotenv from 'dotenv';
import customerRoutes from './routes/customerRoutes.js';
import purchaseRoutes from './routes/purchaseRoutes.js';
import saleRoutes from './routes/saleRoutes.js';
import inventoryRoutes from './routes/inventoryRoutes.js';
import { errorHandler } from './middleware/errorHandler.js';

dotenv.config();

export const createApp = (): Express => {
  const app = express();

  // Middleware
  app.use(
    cors({
      origin: process.env.CORS_ORIGIN || '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  if (process.env.NODE_ENV !== 'test') {
    app.use(morgan('dev'));
  }

  // Versioned API Routes: /api/v1
  const prefix = process.env.API_PREFIX || '/api/v1';

  app.use(`${prefix}/customers`, customerRoutes);
  app.use(`${prefix}/purchases`, purchaseRoutes);
  app.use(`${prefix}/sales`, saleRoutes);
  app.use(`${prefix}`, inventoryRoutes);

  // Root welcome & info endpoint
  app.get('/', (_req: Request, res: Response) => {
    res.json({
      name: 'Horizone StockFlow API',
      version: '1.0.0',
      description: 'Solar Inventory Management System for Horizone Energy',
      documentation: `${prefix}/health`,
      endpoints: {
        customers: `${prefix}/customers`,
        purchases: `${prefix}/purchases`,
        sales: `${prefix}/sales`,
        inventory: `${prefix}/inventory`,
        dashboard: `${prefix}/dashboard`,
        health: `${prefix}/health`,
      },
      note: 'Development in-memory data store active. Repository interfaces prepared for PostgreSQL / MongoDB shared database integration.',
    });
  });

  // Catch-all 404 handler
  app.use((req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      error: `Endpoint not found: ${req.method} ${req.originalUrl}`,
    });
  });

  // Global Error Handler
  app.use(errorHandler);

  return app;
};

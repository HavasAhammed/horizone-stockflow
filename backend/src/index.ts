import dotenv from 'dotenv';
import { createApp } from './app.js';
import { dataService } from './services/dataService.js';

dotenv.config();

const app = createApp();
const PORT = process.env.PORT || 5050;

async function startServer() {
  await dataService.initDatabase();

  app.listen(PORT, () => {
    console.log(`⚡ Horizone StockFlow API server running on http://localhost:${PORT}`);
    console.log(`⚡ API Prefix: ${process.env.API_PREFIX || '/api/v1'}`);
    console.log(`⚡ Health endpoint: http://localhost:${PORT}${process.env.API_PREFIX || '/api/v1'}/health`);
  });
}

startServer();


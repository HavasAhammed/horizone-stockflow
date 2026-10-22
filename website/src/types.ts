export type PanelStatus = 'available' | 'sold';
export type PanelType = 'DCR' | 'Non DCR';

export interface PanelItem {
  id: string;
  serialNumber: string;
  batchNumber: string;
  wattage: number; // Watts
  type: PanelType;
  purchaseId: string;
  purchasePrice: number; // INR
  status: PanelStatus;
  saleId?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Customer {
  id: string;
  consumerNumber: string; // KSEB consumer number (mandatory)
  phone: string; // Phone number (mandatory)
  name?: string;
  address?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PurchaseTransaction {
  id: string;
  purchaseDate: string;
  supplierName?: string;
  batchNumber: string;
  wattage: number;
  type: PanelType;
  quantity: number;
  serialNumbers: string[];
  unitPurchasePrice: number;
  totalPurchaseAmount: number;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface SaleTransaction {
  id: string;
  saleDate: string;
  customerId: string;
  consumerNumber: string; // KSEB consumer confirmation
  customerName?: string;
  panelWattage: number;
  type: PanelType;
  quantity: number;
  serialNumbers: string[];
  unitSellingPrice: number;
  totalSellingAmount: number;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface StockByWattage {
  wattage: number;
  availableCount: number;
  soldCount: number;
  totalCount: number;
  availableAmount?: number;
  lowStockAlert: boolean;
}

export interface StockByBatch {
  batchNumber: string;
  wattage: number;
  availableCount: number;
  soldCount: number;
  totalCount: number;
}

export interface DashboardSummary {
  totalAvailablePanels: number;
  totalPurchasedPanels: number;
  totalSoldPanels: number;
  totalPurchaseAmount: number;
  totalSalesAmount: number;
  totalStockValue: number;
  lowStockWarnings: Array<{ wattage: number; availableCount: number; threshold: number }>;
  stockByWattage: StockByWattage[];
  stockByBatch: StockByBatch[];
  recentPurchases: PurchaseTransaction[];
  recentSales: SaleTransaction[];
}

export interface AppSettings {
  currency: string;
  currencySymbol: string;
  lowStockThreshold: number;
  apiBaseUrl: string;
  storageMode: 'api' | 'local';
}

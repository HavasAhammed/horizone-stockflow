export type PanelStatus = 'available' | 'sold';

export type PanelType = 'DCR' | 'Non DCR';

export interface PanelItem {
  id: string;
  serialNumber: string;
  batchNumber: string;
  wattage: number; // in Watts (W)
  type: PanelType; // 'DCR' | 'Non DCR'
  purchaseId: string;
  purchasePrice: number; // in INR
  status: PanelStatus;
  saleId?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Customer {
  id: string;
  consumerNumber: string; // KSEB Consumer number (mandatory, unique)
  phone: string; // Phone number (mandatory)
  name?: string;
  address?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PurchaseTransaction {
  id: string;
  purchaseDate: string; // ISO string
  supplierName?: string;
  batchNumber: string;
  wattage: number; // in Watts (W)
  type: PanelType; // 'DCR' | 'Non DCR'
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
  saleDate: string; // ISO string
  customerId: string;
  consumerNumber: string; // KSEB Consumer confirmation
  customerName?: string;
  panelWattage: number; // in Watts (W)
  type: PanelType; // 'DCR' | 'Non DCR'
  quantity: number; // derived from serialNumbers.length
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
  availableAmount: number;
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
  totalStockValue: number; // sum of unitPurchasePrice of all available panels
  lowStockWarnings: Array<{ wattage: number; availableCount: number; threshold: number }>;
  stockByWattage: StockByWattage[];
  stockByBatch: StockByBatch[];
  recentPurchases: PurchaseTransaction[];
  recentSales: SaleTransaction[];
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
  error?: string;
}

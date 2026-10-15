import type {
  Customer,
  PurchaseTransaction,
  SaleTransaction,
  PanelItem,
  StockByWattage,
  StockByBatch,
  DashboardSummary,
} from '../types';

const DEFAULT_API_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api/v1';

class ApiService {
  private baseUrl: string;

  constructor() {
    this.baseUrl = localStorage.getItem('horizone_api_url') || DEFAULT_API_URL;
  }

  public getBaseUrl(): string {
    return this.baseUrl;
  }

  public setBaseUrl(url: string) {
    this.baseUrl = url.replace(/\/+$/, '');
    localStorage.setItem('horizone_api_url', this.baseUrl);
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    const headers = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...options.headers,
    };

    try {
      const response = await fetch(url, { ...options, headers });
      const json = await response.json();

      if (!response.ok) {
        throw new Error(json.error || `Request failed with status ${response.status}`);
      }

      return json.data !== undefined ? json.data : json;
    } catch (err: any) {
      if (err.name === 'TypeError' && err.message.includes('fetch')) {
        throw new Error(
          `Unable to connect to Horizone StockFlow API at ${this.baseUrl}. Please verify the backend server is running.`
        );
      }
      throw err;
    }
  }

  // Health
  public async checkHealth(): Promise<{ status: string; service: string; mode: string }> {
    const url = `${this.baseUrl}/health`;
    const res = await fetch(url);
    if (!res.ok) throw new Error('Backend health check failed');
    return res.json();
  }

  // Dashboard
  public async getDashboardSummary(): Promise<DashboardSummary> {
    return this.request<DashboardSummary>('/dashboard');
  }

  // Customers
  public async getCustomers(search?: string): Promise<Customer[]> {
    const query = search ? `?search=${encodeURIComponent(search)}` : '';
    return this.request<Customer[]>(`/customers${query}`);
  }

  public async getCustomerById(id: string): Promise<Customer & { sales: SaleTransaction[] }> {
    return this.request<Customer & { sales: SaleTransaction[] }>(`/customers/${id}`);
  }

  public async createCustomer(customer: {
    consumerNumber: string;
    phone: string;
    name?: string;
    address?: string;
  }): Promise<Customer> {
    return this.request<Customer>('/customers', {
      method: 'POST',
      body: JSON.stringify(customer),
    });
  }

  public async updateCustomer(
    id: string,
    customer: Partial<Omit<Customer, 'id' | 'createdAt' | 'updatedAt'>>
  ): Promise<Customer> {
    return this.request<Customer>(`/customers/${id}`, {
      method: 'PUT',
      body: JSON.stringify(customer),
    });
  }

  public async deleteCustomer(id: string): Promise<void> {
    await this.request(`/customers/${id}`, { method: 'DELETE' });
  }

  // Purchases
  public async getPurchases(filters?: { batch?: string; wattage?: number; search?: string }): Promise<PurchaseTransaction[]> {
    const params = new URLSearchParams();
    if (filters?.batch) params.append('batch', filters.batch);
    if (filters?.wattage) params.append('wattage', String(filters.wattage));
    if (filters?.search) params.append('search', filters.search);
    const qs = params.toString() ? `?${params.toString()}` : '';
    return this.request<PurchaseTransaction[]>(`/purchases${qs}`);
  }

  public async getPurchaseById(id: string): Promise<PurchaseTransaction> {
    return this.request<PurchaseTransaction>(`/purchases/${id}`);
  }

  public async createPurchase(purchase: {
    purchaseDate?: string;
    supplierName?: string;
    batchNumber: string;
    wattage: number;
    quantity: number;
    serialNumbers: string[];
    unitPurchasePrice: number;
    notes?: string;
  }): Promise<PurchaseTransaction> {
    return this.request<PurchaseTransaction>('/purchases', {
      method: 'POST',
      body: JSON.stringify(purchase),
    });
  }

  public async updatePurchase(
    id: string,
    purchase: Partial<PurchaseTransaction>
  ): Promise<PurchaseTransaction> {
    return this.request<PurchaseTransaction>(`/purchases/${id}`, {
      method: 'PUT',
      body: JSON.stringify(purchase),
    });
  }

  public async deletePurchase(id: string): Promise<void> {
    await this.request(`/purchases/${id}`, { method: 'DELETE' });
  }

  // Sales
  public async getSales(filters?: { customerId?: string; wattage?: number; search?: string }): Promise<SaleTransaction[]> {
    const params = new URLSearchParams();
    if (filters?.customerId) params.append('customerId', filters.customerId);
    if (filters?.wattage) params.append('wattage', String(filters.wattage));
    if (filters?.search) params.append('search', filters.search);
    const qs = params.toString() ? `?${params.toString()}` : '';
    return this.request<SaleTransaction[]>(`/sales${qs}`);
  }

  public async getSaleById(id: string): Promise<SaleTransaction> {
    return this.request<SaleTransaction>(`/sales/${id}`);
  }

  public async createSale(sale: {
    saleDate?: string;
    customerId: string;
    panelWattage: number;
    serialNumbers: string[];
    unitSellingPrice: number;
    notes?: string;
  }): Promise<SaleTransaction> {
    return this.request<SaleTransaction>('/sales', {
      method: 'POST',
      body: JSON.stringify(sale),
    });
  }

  public async updateSale(
    id: string,
    sale: Partial<SaleTransaction>
  ): Promise<SaleTransaction> {
    return this.request<SaleTransaction>(`/sales/${id}`, {
      method: 'PUT',
      body: JSON.stringify(sale),
    });
  }

  public async deleteSale(id: string): Promise<void> {
    await this.request(`/sales/${id}`, { method: 'DELETE' });
  }

  // Inventory
  public async getInventory(filters?: {
    wattage?: number;
    batch?: string;
    status?: 'available' | 'sold';
    search?: string;
  }): Promise<PanelItem[]> {
    const params = new URLSearchParams();
    if (filters?.wattage) params.append('wattage', String(filters.wattage));
    if (filters?.batch) params.append('batch', filters.batch);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.search) params.append('search', filters.search);
    const qs = params.toString() ? `?${params.toString()}` : '';
    return this.request<PanelItem[]>(`/inventory${qs}`);
  }

  public async getAvailablePanelsByWattage(wattage: number): Promise<PanelItem[]> {
    return this.request<PanelItem[]>(`/inventory/available/${wattage}`);
  }

  public async getStockByWattage(): Promise<StockByWattage[]> {
    return this.request<StockByWattage[]>('/inventory/by-wattage');
  }

  public async getStockByBatch(): Promise<StockByBatch[]> {
    return this.request<StockByBatch[]>('/inventory/by-batch');
  }
}

export const apiService = new ApiService();

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Boxes,
  ShoppingCart,
  PackagePlus,
  IndianRupee,
  AlertTriangle,
  RefreshCw,
  PlusCircle,
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { Badge } from '../components/Badge';
import { apiService } from '../services/apiService';
import type { DashboardSummary } from '../types';

export const DashboardPage: React.FC = () => {
  const navigate = useNavigate();
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getDashboardSummary();
      setSummary(data);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch dashboard data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const formatDate = (isoStr: string) => {
    return new Date(isoStr).toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  };

  return (
    <div>
      {/* Top Controls & Quick Action Bar */}
      <div className="quick-actions-bar">
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => navigate('/sales?action=new')}
        >
          <ShoppingCart size={16} /> Record Sale
        </button>
        <button
          type="button"
          className="btn btn-solar"
          onClick={() => navigate('/purchases?action=new')}
        >
          <PackagePlus size={16} /> Add Purchase Batch
        </button>
        <button
          type="button"
          className="btn btn-secondary"
          onClick={() => navigate('/customers?action=new')}
        >
          <PlusCircle size={16} /> Add KSEB Customer
        </button>
        <button
          type="button"
          className="btn btn-secondary"
          style={{ marginLeft: 'auto' }}
          onClick={loadData}
          title="Refresh Dashboard"
        >
          <RefreshCw size={16} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      {/* Error Banner */}
      {error && (
        <div className="alert-banner alert-danger">
          <AlertTriangle size={20} />
          <div>
            <strong>Error connecting to backend:</strong> {error}
          </div>
        </div>
      )}

      {/* Low Stock Warnings */}
      {summary && summary.lowStockWarnings && summary.lowStockWarnings.length > 0 && (
        <div className="alert-banner alert-warning">
          <AlertTriangle size={20} />
          <div>
            <strong>Low Inventory Warning:</strong>{' '}
            {summary.lowStockWarnings
              .map(
                (w) =>
                  `${w.wattage}W Solar Panels have only ${w.availableCount} panel(s) remaining (threshold: ${w.threshold})`
              )
              .join('; ')}
          </div>
        </div>
      )}

      {/* Primary KPI Stats */}
      <div className="stats-grid">
        <StatCard
          label="Available In Stock"
          value={summary ? `${summary.totalAvailablePanels} Panels` : '...'}
          subtext="Ready for dispatch & installation"
          icon={<Boxes size={22} color="#10b981" />}
          iconBg="#ecfdf5"
        />
        <StatCard
          label="Total Purchased"
          value={summary ? `${summary.totalPurchasedPanels} Panels` : '...'}
          subtext="Cumulative inward panels"
          icon={<PackagePlus size={22} color="#f59e0b" />}
          iconBg="#fffbeb"
        />
        <StatCard
          label="Total Panels Sold"
          value={summary ? `${summary.totalSoldPanels} Panels` : '...'}
          subtext="Dispatched to customer sites"
          icon={<ShoppingCart size={22} color="#1b75bc" />}
          iconBg="#eff6ff"
        />
        <StatCard
          label="Total Stock Valuation"
          value={summary ? formatCurrency(summary.totalStockValue) : '...'}
          subtext="Cost basis of on-hand inventory"
          icon={<IndianRupee size={22} color="#059669" />}
          iconBg="#f0fdf4"
        />
      </div>

      {/* Stock by Wattage Grid */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">Stock Availability by Panel Wattage</h2>
          <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            Tracked at individual serial level
          </span>
        </div>
        <div className="card-body">
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: '16px',
            }}
          >
            {summary?.stockByWattage.map((item) => (
              <div
                key={item.wattage}
                style={{
                  padding: '16px',
                  borderRadius: '10px',
                  border: '1px solid var(--border-color)',
                  backgroundColor: '#ffffff',
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: '10px',
                  }}
                >
                  <span
                    style={{
                      fontSize: '1.2rem',
                      fontWeight: 700,
                      fontFamily: 'var(--font-heading)',
                      color: 'var(--text-main)',
                    }}
                  >
                    {item.wattage}W
                  </span>
                  {item.lowStockAlert ? (
                    <Badge variant="warning">Low Stock</Badge>
                  ) : (
                    <Badge variant="success">In Stock</Badge>
                  )}
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    fontSize: '0.9rem',
                    color: 'var(--text-muted)',
                  }}
                >
                  <span>Available:</span>
                  <strong style={{ color: 'var(--color-green-dark)' }}>
                    {item.availableCount}
                  </strong>
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    fontSize: '0.85rem',
                    color: 'var(--text-muted)',
                    marginTop: '4px',
                  }}
                >
                  <span>Sold:</span>
                  <span>{item.soldCount}</span>
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    fontSize: '0.85rem',
                    color: 'var(--text-muted)',
                    marginTop: '4px',
                    borderTop: '1px dashed var(--border-color)',
                    paddingTop: '6px',
                  }}
                >
                  <span>Total Inward:</span>
                  <span>{item.totalCount}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent Purchases & Sales Side-by-Side */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(450px, 1fr))',
          gap: '24px',
        }}
      >
        {/* Recent Purchases */}
        <div className="card">
          <div className="card-header">
            <h2 className="card-title">Recent Inward Purchases</h2>
            <button
              type="button"
              className="btn btn-secondary btn-sm"
              onClick={() => navigate('/purchases')}
            >
              View All
            </button>
          </div>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Batch / Supplier</th>
                  <th>Wattage</th>
                  <th>Qty</th>
                  <th>Total (₹)</th>
                </tr>
              </thead>
              <tbody>
                {summary?.recentPurchases && summary.recentPurchases.length > 0 ? (
                  summary.recentPurchases.map((p) => (
                    <tr key={p.id}>
                      <td>{formatDate(p.purchaseDate)}</td>
                      <td>
                        <strong>{p.batchNumber}</strong>
                        {p.supplierName && (
                          <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                            {p.supplierName}
                          </div>
                        )}
                      </td>
                      <td>{p.wattage}W</td>
                      <td>
                        <Badge variant="info">{p.quantity} pcs</Badge>
                      </td>
                      <td>{formatCurrency(p.totalPurchaseAmount)}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                      No purchase transactions recorded yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Recent Sales */}
        <div className="card">
          <div className="card-header">
            <h2 className="card-title">Recent Sales & Dispatches</h2>
            <button
              type="button"
              className="btn btn-secondary btn-sm"
              onClick={() => navigate('/sales')}
            >
              View All
            </button>
          </div>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Customer (KSEB)</th>
                  <th>Wattage</th>
                  <th>Qty</th>
                  <th>Amount (₹)</th>
                </tr>
              </thead>
              <tbody>
                {summary?.recentSales && summary.recentSales.length > 0 ? (
                  summary.recentSales.map((s) => (
                    <tr key={s.id}>
                      <td>{formatDate(s.saleDate)}</td>
                      <td>
                        <strong>{s.customerName || 'Customer'}</strong>
                        <div style={{ fontSize: '0.78rem', color: 'var(--color-primary)' }}>
                          KSEB: {s.consumerNumber}
                        </div>
                      </td>
                      <td>{s.panelWattage}W</td>
                      <td>
                        <Badge variant="success">{s.quantity} pcs</Badge>
                      </td>
                      <td>{formatCurrency(s.totalSellingAmount)}</td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                      No sales transactions recorded yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};

import React, { useState, useEffect } from 'react';
import {
  Boxes,
  Search,
  FileSpreadsheet,
  Layers,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import type { PanelItem, StockByWattage, StockByBatch } from '../types';
import { Badge } from '../components/Badge';

export const InventoryPage: React.FC = () => {
  const [panels, setPanels] = useState<PanelItem[]>([]);
  const [stockByWattage, setStockByWattage] = useState<StockByWattage[]>([]);
  const [stockByBatch, setStockByBatch] = useState<StockByBatch[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [wattageFilter, setWattageFilter] = useState('');
  const [batchFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState<'available' | 'sold' | ''>('');
  const [activeTab, setActiveTab] = useState<'serials' | 'wattage' | 'batches'>('serials');

  const loadInventory = async () => {
    try {
      setLoading(true);
      const [panelsData, wattageData, batchData] = await Promise.all([
        apiService.getInventory({
          search,
          wattage: wattageFilter ? Number(wattageFilter) : undefined,
          batch: batchFilter || undefined,
          status: statusFilter || undefined,
        }),
        apiService.getStockByWattage(),
        apiService.getStockByBatch(),
      ]);
      setPanels(panelsData);
      setStockByWattage(wattageData);
      setStockByBatch(batchData);
    } catch (err) {
      console.error('Failed to load inventory', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadInventory();
  }, [wattageFilter, batchFilter, statusFilter]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadInventory();
  };

  return (
    <div>
      {/* View Switcher Tabs */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '20px' }}>
        <button
          type="button"
          className={`btn ${activeTab === 'serials' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('serials')}
        >
          <Boxes size={16} /> Physical Serialized Panels ({panels.length})
        </button>
        <button
          type="button"
          className={`btn ${activeTab === 'wattage' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('wattage')}
        >
          <Layers size={16} /> Summary by Wattage
        </button>
        <button
          type="button"
          className={`btn ${activeTab === 'batches' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('batches')}
        >
          <FileSpreadsheet size={16} /> Summary by Batch
        </button>
      </div>

      {activeTab === 'serials' && (
        <>
          {/* Filter Bar */}
          <div className="card" style={{ marginBottom: '20px' }}>
            <div className="card-body" style={{ padding: '16px 20px' }}>
              <form
                onSubmit={handleSearchSubmit}
                style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}
              >
                <div style={{ flex: '1 1 250px' }}>
                  <input
                    type="text"
                    className="form-input"
                    placeholder="Search panel serial number or batch..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>

                <div style={{ width: '150px' }}>
                  <select
                    className="form-select"
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value as any)}
                  >
                    <option value="">All Statuses</option>
                    <option value="available">Available Only</option>
                    <option value="sold">Sold Only</option>
                  </select>
                </div>

                <div style={{ width: '140px' }}>
                  <select
                    className="form-select"
                    value={wattageFilter}
                    onChange={(e) => setWattageFilter(e.target.value)}
                  >
                    <option value="">All Wattages</option>
                    <option value="540">540W</option>
                    <option value="450">450W</option>
                    <option value="400">400W</option>
                  </select>
                </div>

                <button type="submit" className="btn btn-secondary">
                  <Search size={16} /> Search
                </button>
              </form>
            </div>
          </div>

          {/* Physical Panels Table */}
          <div className="card">
            <div className="card-header">
              <h2 className="card-title">Physical Panel Inventory Unit Records</h2>
              <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                Showing {panels.length} panel records
              </span>
            </div>
            <div className="table-responsive">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Serial Number</th>
                    <th>Batch Number</th>
                    <th>Wattage</th>
                    <th>Status</th>
                    <th>Inward Date</th>
                    <th>Purchase Price</th>
                    <th>Sale Allocation</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    <tr>
                      <td colSpan={7} style={{ textAlign: 'center', padding: '30px' }}>
                        Loading inventory...
                      </td>
                    </tr>
                  ) : panels.length === 0 ? (
                    <tr>
                      <td
                        colSpan={7}
                        style={{ textAlign: 'center', padding: '30px', color: 'var(--text-muted)' }}
                      >
                        No panels match current filter criteria.
                      </td>
                    </tr>
                  ) : (
                    panels.map((p) => (
                      <tr key={p.id}>
                        <td>
                          <span
                            style={{
                              fontFamily: 'monospace',
                              fontWeight: 600,
                              color: 'var(--text-main)',
                            }}
                          >
                            {p.serialNumber}
                          </span>
                        </td>
                        <td>{p.batchNumber}</td>
                        <td>
                          <strong>{p.wattage}W</strong>
                        </td>
                        <td>
                          {p.status === 'available' ? (
                            <Badge variant="success">Available</Badge>
                          ) : (
                            <Badge variant="neutral">Sold / Dispatched</Badge>
                          )}
                        </td>
                        <td>{new Date(p.createdAt).toLocaleDateString('en-IN')}</td>
                        <td>₹{p.purchasePrice.toLocaleString('en-IN')}</td>
                        <td>
                          {p.saleId ? (
                            <span style={{ fontSize: '0.8rem', fontFamily: 'monospace' }}>
                              {p.saleId}
                            </span>
                          ) : (
                            <span style={{ color: 'var(--text-muted)' }}>—</span>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {activeTab === 'wattage' && (
        <div className="card">
          <div className="card-header">
            <h2 className="card-title">Stock Aggregation by Solar Panel Wattage</h2>
          </div>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Panel Wattage</th>
                  <th>Available Panels</th>
                  <th>Sold Panels</th>
                  <th>Total Inward</th>
                  <th>Inventory Status</th>
                </tr>
              </thead>
              <tbody>
                {stockByWattage.map((item) => (
                  <tr key={item.wattage}>
                    <td>
                      <strong style={{ fontSize: '1.05rem' }}>{item.wattage}W</strong>
                    </td>
                    <td>
                      <span
                        style={{
                          fontSize: '1.1rem',
                          fontWeight: 700,
                          color: 'var(--color-green-dark)',
                        }}
                      >
                        {item.availableCount} units
                      </span>
                    </td>
                    <td>{item.soldCount} units</td>
                    <td>{item.totalCount} units</td>
                    <td>
                      {item.lowStockAlert ? (
                        <Badge variant="warning">Low Stock Alert</Badge>
                      ) : (
                        <Badge variant="success">Optimal Stock</Badge>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {activeTab === 'batches' && (
        <div className="card">
          <div className="card-header">
            <h2 className="card-title">Stock Aggregation by Inward Batch</h2>
          </div>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Batch Number</th>
                  <th>Wattage</th>
                  <th>Available Units</th>
                  <th>Sold Units</th>
                  <th>Batch Total</th>
                </tr>
              </thead>
              <tbody>
                {stockByBatch.map((b) => (
                  <tr key={`${b.batchNumber}-${b.wattage}`}>
                    <td>
                      <strong>{b.batchNumber}</strong>
                    </td>
                    <td>{b.wattage}W</td>
                    <td>
                      <strong style={{ color: 'var(--color-green-dark)' }}>
                        {b.availableCount}
                      </strong>
                    </td>
                    <td>{b.soldCount}</td>
                    <td>{b.totalCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};

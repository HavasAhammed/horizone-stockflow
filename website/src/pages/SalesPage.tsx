import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Search,
  Plus,
  Trash2,
  Eye,
  AlertCircle,
  CheckCircle2,
  Check,
  UserCheck,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import type { SaleTransaction, Customer, PanelItem } from '../types';
import { Modal } from '../components/Modal';
import { Badge } from '../components/Badge';

export const SalesPage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [sales, setSales] = useState<SaleTransaction[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [wattageFilter, setWattageFilter] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Modals state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [viewSale, setViewSale] = useState<SaleTransaction | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  // Available panels for selected wattage
  const [availablePanels, setAvailablePanels] = useState<PanelItem[]>([]);
  const [loadingPanels, setLoadingPanels] = useState(false);

  // Add form fields
  const [formData, setFormData] = useState({
    saleDate: new Date().toISOString().split('T')[0],
    customerId: '',
    panelWattage: 540,
    selectedSerials: [] as string[],
    unitSellingPrice: 14500,
    notes: '',
  });

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [salesData, custData] = await Promise.all([
        apiService.getSales({
          search,
          wattage: wattageFilter ? Number(wattageFilter) : undefined,
        }),
        apiService.getCustomers(),
      ]);
      setSales(salesData);
      setCustomers(custData);
      if (custData.length > 0 && !formData.customerId) {
        setFormData((prev) => ({ ...prev, customerId: custData[0].id }));
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load sales data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    if (searchParams.get('action') === 'new') {
      setIsAddModalOpen(true);
      setSearchParams({});
    }
  }, [searchParams]);

  // Load available panels whenever selected wattage changes in the form
  useEffect(() => {
    if (!isAddModalOpen) return;
    const fetchPanels = async () => {
      try {
        setLoadingPanels(true);
        const panels = await apiService.getAvailablePanelsByWattage(formData.panelWattage);
        setAvailablePanels(panels);
        // Clear selected serials that are no longer available in the new wattage
        setFormData((prev) => ({
          ...prev,
          selectedSerials: prev.selectedSerials.filter((sn) =>
            panels.some((p) => p.serialNumber === sn)
          ),
        }));
      } catch (err: any) {
        setError(`Failed to fetch panels for ${formData.panelWattage}W: ${err.message}`);
      } finally {
        setLoadingPanels(false);
      }
    };
    fetchPanels();
  }, [formData.panelWattage, isAddModalOpen]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadData();
  };

  const toggleSerialSelection = (sn: string) => {
    setFormData((prev) => {
      const exists = prev.selectedSerials.includes(sn);
      if (exists) {
        return { ...prev, selectedSerials: prev.selectedSerials.filter((s) => s !== sn) };
      } else {
        return { ...prev, selectedSerials: [...prev.selectedSerials, sn] };
      }
    });
  };

  const selectAllAvailable = () => {
    setFormData((prev) => ({
      ...prev,
      selectedSerials: availablePanels.map((p) => p.serialNumber),
    }));
  };

  const clearSelection = () => {
    setFormData((prev) => ({
      ...prev,
      selectedSerials: [],
    }));
  };

  const selectedCustomer = customers.find((c) => c.id === formData.customerId);

  const handleOpenConfirm = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!formData.customerId) {
      setError('Please select a customer.');
      return;
    }

    if (formData.selectedSerials.length === 0) {
      setError('Please select at least one solar panel to dispatch.');
      return;
    }

    setIsConfirmModalOpen(true);
  };

  const handleCommitSale = async () => {
    try {
      setIsConfirmModalOpen(false);
      await apiService.createSale({
        saleDate: new Date(formData.saleDate).toISOString(),
        customerId: formData.customerId,
        panelWattage: Number(formData.panelWattage),
        serialNumbers: formData.selectedSerials,
        unitSellingPrice: Number(formData.unitSellingPrice),
        notes: formData.notes.trim() || undefined,
      });

      setIsAddModalOpen(false);
      setSuccessMsg('Sale confirmed! Inventory updated and serial numbers allocated.');
      setFormData((prev) => ({
        ...prev,
        selectedSerials: [],
        notes: '',
      }));
      loadData();
    } catch (err: any) {
      setError(err.message || 'Failed to record sale');
    }
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    try {
      await apiService.deleteSale(deleteId);
      setDeleteId(null);
      setSuccessMsg('Sale deleted and panels returned to available stock inventory.');
      loadData();
    } catch (err: any) {
      setError(err.message || 'Cannot delete sale');
      setDeleteId(null);
    }
  };

  const formatCurrency = (amt: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amt);
  };

  return (
    <div>
      {/* Messages */}
      {error && (
        <div className="alert-banner alert-danger">
          <AlertCircle size={20} />
          <div>{error}</div>
        </div>
      )}
      {successMsg && (
        <div className="alert-banner alert-info">
          <CheckCircle2 size={20} color="#10b981" />
          <div>{successMsg}</div>
        </div>
      )}

      {/* Action & Filter Bar */}
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
                placeholder="Search KSEB consumer number, customer, or serial number..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            <div style={{ width: '160px' }}>
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
              <Search size={16} /> Filter
            </button>

            <button
              type="button"
              className="btn btn-primary"
              style={{ marginLeft: 'auto' }}
              onClick={() => setIsAddModalOpen(true)}
            >
              <Plus size={16} /> Record Sale
            </button>
          </form>
        </div>
      </div>

      {/* Sales Table */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">Sales & Outward Dispatches ({sales.length})</h2>
        </div>
        <div className="table-responsive">
          <table className="data-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Customer Name</th>
                <th>KSEB Consumer #</th>
                <th>Wattage (W)</th>
                <th>Panels Sold</th>
                <th>Unit Price (₹)</th>
                <th>Total Amount (₹)</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '30px' }}>
                    Loading sales records...
                  </td>
                </tr>
              ) : sales.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '30px', color: 'var(--text-muted)' }}>
                    No sales recorded matching current filters.
                  </td>
                </tr>
              ) : (
                sales.map((s) => (
                  <tr key={s.id}>
                    <td>{new Date(s.saleDate).toLocaleDateString('en-IN')}</td>
                    <td>
                      <strong>{s.customerName || 'Customer'}</strong>
                    </td>
                    <td>
                      <span style={{ fontFamily: 'monospace', color: 'var(--color-primary)', fontWeight: 600 }}>
                        {s.consumerNumber}
                      </span>
                    </td>
                    <td>
                      <strong>{s.panelWattage}W</strong>
                    </td>
                    <td>
                      <Badge variant="success">{s.quantity} pcs</Badge>
                    </td>
                    <td>{formatCurrency(s.unitSellingPrice)}</td>
                    <td>
                      <strong style={{ color: 'var(--color-green-dark)' }}>
                        {formatCurrency(s.totalSellingAmount)}
                      </strong>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => setViewSale(s)}
                          title="View Sale Details & Allocated Panels"
                        >
                          <Eye size={14} />
                        </button>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          style={{ color: 'var(--color-danger)' }}
                          onClick={() => setDeleteId(s.id)}
                          title="Cancel/Delete Sale"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Record Sale Modal */}
      <Modal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        title="Record New Sale & Dispatch"
        maxWidth="680px"
      >
        <form onSubmit={handleOpenConfirm}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Sale Date *</label>
              <input
                type="date"
                required
                className="form-input"
                value={formData.saleDate}
                onChange={(e) => setFormData({ ...formData, saleDate: e.target.value })}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Customer (KSEB Consumer) *</label>
              <select
                required
                className="form-select"
                value={formData.customerId}
                onChange={(e) => setFormData({ ...formData, customerId: e.target.value })}
              >
                {customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name ? `${c.name} (${c.consumerNumber})` : c.consumerNumber}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* KSEB Consumer Confirmation Banner */}
          {selectedCustomer && (
            <div
              style={{
                backgroundColor: '#eff6ff',
                border: '1px solid #bfdbfe',
                borderRadius: '8px',
                padding: '12px 16px',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                fontSize: '0.88rem',
              }}
            >
              <UserCheck size={20} color="#1b75bc" />
              <div>
                <strong>Customer: {selectedCustomer.name || 'Unnamed'}</strong> | KSEB Consumer #:{' '}
                <span style={{ fontFamily: 'monospace', fontWeight: 700, color: '#1b75bc' }}>
                  {selectedCustomer.consumerNumber}
                </span>{' '}
                | Phone: {selectedCustomer.phone}
              </div>
            </div>
          )}

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Panel Wattage (W) *</label>
              <select
                className="form-select"
                value={formData.panelWattage}
                onChange={(e) =>
                  setFormData({
                    ...formData,
                    panelWattage: Number(e.target.value),
                  })
                }
              >
                <option value="540">540W Mono PERC</option>
                <option value="450">450W Bifacial</option>
                <option value="400">400W High Efficiency</option>
                <option value="330">330W Polycrystalline</option>
              </select>
            </div>

            <div className="form-group">
              <label className="form-label">Unit Selling Price (₹) *</label>
              <input
                type="number"
                required
                min="0"
                step="50"
                className="form-input"
                value={formData.unitSellingPrice}
                onChange={(e) =>
                  setFormData({ ...formData, unitSellingPrice: Number(e.target.value) })
                }
              />
            </div>
          </div>

          {/* Available Serial Numbers Selector */}
          <div className="form-group">
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '8px',
              }}
            >
              <label className="form-label" style={{ margin: 0 }}>
                Select Available Physical Panels ({availablePanels.length} available) *
              </label>
              <div style={{ display: 'flex', gap: '8px', fontSize: '0.8rem' }}>
                <button
                  type="button"
                  style={{
                    background: 'none',
                    border: 'none',
                    color: 'var(--color-primary)',
                    cursor: 'pointer',
                    fontWeight: 600,
                  }}
                  onClick={selectAllAvailable}
                >
                  Select All
                </button>
                <span>|</span>
                <button
                  type="button"
                  style={{
                    background: 'none',
                    border: 'none',
                    color: 'var(--text-muted)',
                    cursor: 'pointer',
                  }}
                  onClick={clearSelection}
                >
                  Clear
                </button>
              </div>
            </div>

            {loadingPanels ? (
              <div style={{ padding: '16px', textAlign: 'center', color: 'var(--text-muted)' }}>
                Loading available panels...
              </div>
            ) : availablePanels.length === 0 ? (
              <div
                style={{
                  padding: '20px',
                  textAlign: 'center',
                  backgroundColor: '#fffbeb',
                  borderRadius: '8px',
                  color: '#b45309',
                }}
              >
                No available panels in stock for {formData.panelWattage}W. Please record an inward
                purchase first.
              </div>
            ) : (
              <div className="serial-chips-grid">
                {availablePanels.map((p) => {
                  const isSelected = formData.selectedSerials.includes(p.serialNumber);
                  return (
                    <div
                      key={p.serialNumber}
                      className={`serial-chip ${isSelected ? 'selected' : ''}`}
                      onClick={() => toggleSerialSelection(p.serialNumber)}
                    >
                      {p.serialNumber} {isSelected && '✓'}
                    </div>
                  );
                })}
              </div>
            )}

            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                marginTop: '10px',
                fontSize: '0.9rem',
                backgroundColor: '#f8fafc',
                padding: '10px 14px',
                borderRadius: '6px',
                border: '1px solid var(--border-color)',
              }}
            >
              <span>
                Derived Quantity: <strong>{formData.selectedSerials.length} panels</strong>
              </span>
              <span>
                Total Selling Amount:{' '}
                <strong style={{ color: 'var(--color-green-dark)' }}>
                  {formatCurrency(formData.selectedSerials.length * formData.unitSellingPrice)}
                </strong>
              </span>
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Notes</label>
            <input
              type="text"
              placeholder="e.g. 5kW On-Grid Rooftop Phase 1"
              className="form-input"
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
            />
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '20px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setIsAddModalOpen(false)}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={formData.selectedSerials.length === 0}
            >
              Proceed to Confirmation
            </button>
          </div>
        </form>
      </Modal>

      {/* Confirmation Dialog Before Committing Sale */}
      {isConfirmModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsConfirmModalOpen(false)}
          title="Confirm Solar Sale Transaction"
          maxWidth="520px"
        >
          <div style={{ marginBottom: '16px' }}>
            <p style={{ fontSize: '0.95rem', marginBottom: '14px' }}>
              Please review and confirm the sale details. Once committed, these specific panel serial
              numbers will be deducted from inventory and allocated to this KSEB customer.
            </p>

            <div
              style={{
                backgroundColor: '#f8fafc',
                borderRadius: '8px',
                border: '1px solid var(--border-color)',
                padding: '16px',
                display: 'grid',
                gap: '10px',
                fontSize: '0.9rem',
              }}
            >
              <div>
                <span style={{ color: 'var(--text-muted)' }}>Customer: </span>
                <strong>{selectedCustomer?.name || 'Unnamed'}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--text-muted)' }}>KSEB Consumer #: </span>
                <strong style={{ color: 'var(--color-primary)', fontFamily: 'monospace' }}>
                  {selectedCustomer?.consumerNumber}
                </strong>
              </div>
              <div>
                <span style={{ color: 'var(--text-muted)' }}>Wattage: </span>
                <strong>{formData.panelWattage}W</strong>
              </div>
              <div>
                <span style={{ color: 'var(--text-muted)' }}>Panels Selected: </span>
                <strong>{formData.selectedSerials.length} units</strong>
              </div>
              <div>
                <span style={{ color: 'var(--text-muted)' }}>Total Selling Value: </span>
                <strong style={{ color: 'var(--color-green-dark)', fontSize: '1.05rem' }}>
                  {formatCurrency(formData.selectedSerials.length * formData.unitSellingPrice)}
                </strong>
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setIsConfirmModalOpen(false)}
            >
              Back to Edit
            </button>
            <button
              type="button"
              className="btn btn-green"
              onClick={handleCommitSale}
            >
              <Check size={16} /> Confirm & Dispatch
            </button>
          </div>
        </Modal>
      )}

      {/* View Sale Details */}
      {viewSale && (
        <Modal
          isOpen={true}
          onClose={() => setViewSale(null)}
          title={`Sale Details: ${viewSale.id}`}
          maxWidth="600px"
        >
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '16px' }}>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Date:</span>
              <div>{new Date(viewSale.saleDate).toLocaleDateString('en-IN')}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Customer:</span>
              <div>{viewSale.customerName || 'Customer'}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>KSEB Consumer #:</span>
              <div style={{ fontFamily: 'monospace', color: 'var(--color-primary)', fontWeight: 600 }}>
                {viewSale.consumerNumber}
              </div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Wattage:</span>
              <div>{viewSale.panelWattage}W</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Quantity:</span>
              <div>{viewSale.quantity} Panels</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Total Amount:</span>
              <div>
                <strong style={{ color: 'var(--color-green-dark)' }}>
                  {formatCurrency(viewSale.totalSellingAmount)}
                </strong>
              </div>
            </div>
          </div>

          <div style={{ marginBottom: '16px' }}>
            <span style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: '8px' }}>
              Allocated Serial Numbers ({viewSale.serialNumbers.length}):
            </span>
            <div className="serial-chips-grid">
              {viewSale.serialNumbers.map((sn) => (
                <span key={sn} className="serial-chip selected">
                  {sn}
                </span>
              ))}
            </div>
          </div>

          {viewSale.notes && (
            <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '16px' }}>
              <strong>Notes:</strong> {viewSale.notes}
            </div>
          )}

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setViewSale(null)}
            >
              Close
            </button>
          </div>
        </Modal>
      )}

      {/* Delete Confirmation */}
      {deleteId && (
        <Modal
          isOpen={true}
          onClose={() => setDeleteId(null)}
          title="Confirm Sale Cancellation / Deletion"
        >
          <p style={{ marginBottom: '16px' }}>
            Are you sure you want to delete this sale record?
          </p>
          <div className="alert-banner alert-warning" style={{ marginBottom: '16px' }}>
            <AlertCircle size={18} />
            <span>
              All serialized panels allocated to this sale will be returned to 'available' stock
              inventory immediately.
            </span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setDeleteId(null)}
            >
              Keep Sale
            </button>
            <button
              type="button"
              className="btn btn-danger"
              onClick={handleDelete}
            >
              Confirm Deletion & Restore Panels
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
};

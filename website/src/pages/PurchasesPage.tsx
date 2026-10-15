import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Search,
  Plus,
  Trash2,
  Edit,
  Eye,
  AlertCircle,
  CheckCircle2,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import type { PurchaseTransaction } from '../types';
import { Modal } from '../components/Modal';
import { Badge } from '../components/Badge';

export const PurchasesPage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [purchases, setPurchases] = useState<PurchaseTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [wattageFilter, setWattageFilter] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Modals state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [viewPurchase, setViewPurchase] = useState<PurchaseTransaction | null>(null);
  const [editPurchase, setEditPurchase] = useState<PurchaseTransaction | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  // Add form fields
  const [formData, setFormData] = useState({
    purchaseDate: new Date().toISOString().split('T')[0],
    supplierName: '',
    batchNumber: '',
    wattage: 540,
    quantity: 1,
    unitPurchasePrice: 11500,
    serialsText: '',
    notes: '',
  });

  const loadPurchases = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getPurchases({
        search,
        wattage: wattageFilter ? Number(wattageFilter) : undefined,
      });
      setPurchases(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load purchase records');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPurchases();
    if (searchParams.get('action') === 'new') {
      setIsAddModalOpen(true);
      setSearchParams({});
    }
  }, [searchParams]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadPurchases();
  };

  // Helper to parse serials from text area
  const parsedSerials = formData.serialsText
    .split(/[\n,\s]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const duplicateSerialsInInput = parsedSerials.filter(
    (item, index) => parsedSerials.indexOf(item) !== index
  );

  const handleAddSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMsg(null);

    if (parsedSerials.length !== Number(formData.quantity)) {
      setError(
        `Quantity (${formData.quantity}) does not match entered serial numbers (${parsedSerials.length}).`
      );
      return;
    }

    if (duplicateSerialsInInput.length > 0) {
      setError(`Duplicate serials found in entry: ${duplicateSerialsInInput.join(', ')}`);
      return;
    }

    try {
      await apiService.createPurchase({
        purchaseDate: new Date(formData.purchaseDate).toISOString(),
        supplierName: formData.supplierName.trim() || undefined,
        batchNumber: formData.batchNumber.trim(),
        wattage: Number(formData.wattage),
        quantity: Number(formData.quantity),
        serialNumbers: parsedSerials,
        unitPurchasePrice: Number(formData.unitPurchasePrice),
        notes: formData.notes.trim() || undefined,
      });

      setIsAddModalOpen(false);
      setSuccessMsg('Purchase registered and physical panel records created successfully.');
      setFormData({
        purchaseDate: new Date().toISOString().split('T')[0],
        supplierName: '',
        batchNumber: '',
        wattage: 540,
        quantity: 1,
        unitPurchasePrice: 11500,
        serialsText: '',
        notes: '',
      });
      loadPurchases();
    } catch (err: any) {
      setError(err.message || 'Failed to register purchase');
    }
  };

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editPurchase) return;
    try {
      await apiService.updatePurchase(editPurchase.id, {
        supplierName: editPurchase.supplierName,
        batchNumber: editPurchase.batchNumber,
        unitPurchasePrice: Number(editPurchase.unitPurchasePrice),
        notes: editPurchase.notes,
      });
      setEditPurchase(null);
      setSuccessMsg('Purchase updated successfully.');
      loadPurchases();
    } catch (err: any) {
      setError(err.message || 'Failed to update purchase');
    }
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    try {
      await apiService.deletePurchase(deleteId);
      setDeleteId(null);
      setSuccessMsg('Purchase and associated uncommitted panels removed.');
      loadPurchases();
    } catch (err: any) {
      setError(err.message || 'Cannot delete purchase');
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

      {/* Action Header & Search */}
      <div className="card" style={{ marginBottom: '20px' }}>
        <div className="card-body" style={{ padding: '16px 20px' }}>
          <form
            onSubmit={handleSearchSubmit}
            style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}
          >
            <div style={{ flex: '1 1 250px', position: 'relative' }}>
              <input
                type="text"
                className="form-input"
                placeholder="Search batch, supplier, or serial number..."
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
                <option value="330">330W</option>
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
              <Plus size={16} /> Add Purchase Batch
            </button>
          </form>
        </div>
      </div>

      {/* Purchases Table */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">Panel Purchase Transactions ({purchases.length})</h2>
        </div>
        <div className="table-responsive">
          <table className="data-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Batch Number</th>
                <th>Supplier</th>
                <th>Wattage (W)</th>
                <th>Quantity</th>
                <th>Unit Price (₹)</th>
                <th>Total (₹)</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '30px' }}>
                    Loading purchases...
                  </td>
                </tr>
              ) : purchases.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '30px', color: 'var(--text-muted)' }}>
                    No purchase transactions matching current criteria.
                  </td>
                </tr>
              ) : (
                purchases.map((p) => (
                  <tr key={p.id}>
                    <td>{new Date(p.purchaseDate).toLocaleDateString('en-IN')}</td>
                    <td>
                      <strong>{p.batchNumber}</strong>
                    </td>
                    <td>{p.supplierName || '—'}</td>
                    <td>
                      <strong>{p.wattage}W</strong>
                    </td>
                    <td>
                      <Badge variant="info">{p.quantity} panels</Badge>
                    </td>
                    <td>{formatCurrency(p.unitPurchasePrice)}</td>
                    <td>
                      <strong>{formatCurrency(p.totalPurchaseAmount)}</strong>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => setViewPurchase(p)}
                          title="View Details & Serial Numbers"
                        >
                          <Eye size={14} />
                        </button>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => setEditPurchase(p)}
                          title="Edit Details"
                        >
                          <Edit size={14} />
                        </button>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          style={{ color: 'var(--color-danger)' }}
                          onClick={() => setDeleteId(p.id)}
                          title="Delete Batch"
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

      {/* Add Purchase Modal */}
      <Modal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        title="Add Inward Purchase Batch"
        maxWidth="650px"
      >
        <form onSubmit={handleAddSubmit}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Purchase Date *</label>
              <input
                type="date"
                required
                className="form-input"
                value={formData.purchaseDate}
                onChange={(e) => setFormData({ ...formData, purchaseDate: e.target.value })}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Batch Number *</label>
              <input
                type="text"
                required
                placeholder="e.g. BATCH-540-K2"
                className="form-input"
                value={formData.batchNumber}
                onChange={(e) => setFormData({ ...formData, batchNumber: e.target.value })}
              />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Supplier Name / Reference</label>
              <input
                type="text"
                placeholder="e.g. Tata Power Solar Systems"
                className="form-input"
                value={formData.supplierName}
                onChange={(e) => setFormData({ ...formData, supplierName: e.target.value })}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Panel Wattage (W) *</label>
              <input
                type="number"
                required
                min="50"
                step="5"
                className="form-input"
                value={formData.wattage}
                onChange={(e) => setFormData({ ...formData, wattage: Number(e.target.value) })}
              />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="form-group">
              <label className="form-label">Quantity (pcs) *</label>
              <input
                type="number"
                required
                min="1"
                className="form-input"
                value={formData.quantity}
                onChange={(e) => setFormData({ ...formData, quantity: Number(e.target.value) })}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Unit Purchase Price (₹) *</label>
              <input
                type="number"
                required
                min="0"
                step="50"
                className="form-input"
                value={formData.unitPurchasePrice}
                onChange={(e) =>
                  setFormData({ ...formData, unitPurchasePrice: Number(e.target.value) })
                }
              />
            </div>
          </div>

          <div className="form-group">
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                marginBottom: '6px',
              }}
            >
              <label className="form-label" style={{ margin: 0 }}>
                Individual Panel Serial Numbers *
              </label>
              <span
                style={{
                  fontSize: '0.8rem',
                  fontWeight: 600,
                  color:
                    parsedSerials.length === Number(formData.quantity)
                      ? 'var(--color-green-dark)'
                      : 'var(--color-danger)',
                }}
              >
                {parsedSerials.length} of {formData.quantity} serials entered
              </span>
            </div>
            <textarea
              required
              rows={5}
              placeholder="Paste panel serial numbers separated by comma, space or new line (e.g. HZ-540-001, HZ-540-002)..."
              className="form-textarea"
              style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
              value={formData.serialsText}
              onChange={(e) => setFormData({ ...formData, serialsText: e.target.value })}
            />
            {duplicateSerialsInInput.length > 0 && (
              <div style={{ color: 'var(--color-danger)', fontSize: '0.8rem', marginTop: '4px' }}>
                Duplicate serials in input: {duplicateSerialsInInput.join(', ')}
              </div>
            )}
            <div className="form-hint">
              Bulk paste supported. Every single panel is tracked in inventory with its serial.
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Notes</label>
            <input
              type="text"
              placeholder="e.g. Invoice #9923, Tier 1 warranty"
              className="form-input"
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
            />
          </div>

          <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setIsAddModalOpen(false)}
            >
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              Confirm & Save Purchase
            </button>
          </div>
        </form>
      </Modal>

      {/* View Purchase Details Modal */}
      {viewPurchase && (
        <Modal
          isOpen={true}
          onClose={() => setViewPurchase(null)}
          title={`Purchase Details: ${viewPurchase.batchNumber}`}
          maxWidth="600px"
        >
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '18px' }}>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Date:</span>
              <div>{new Date(viewPurchase.purchaseDate).toLocaleDateString('en-IN')}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Supplier:</span>
              <div>{viewPurchase.supplierName || '—'}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Wattage:</span>
              <div>{viewPurchase.wattage}W</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Quantity:</span>
              <div>{viewPurchase.quantity} Panels</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Unit Price:</span>
              <div>{formatCurrency(viewPurchase.unitPurchasePrice)}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Total Amount:</span>
              <div>
                <strong>{formatCurrency(viewPurchase.totalPurchaseAmount)}</strong>
              </div>
            </div>
          </div>

          <div style={{ marginBottom: '16px' }}>
            <span style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: '8px' }}>
              Serialized Panels in this Batch ({viewPurchase.serialNumbers.length}):
            </span>
            <div className="serial-chips-grid">
              {viewPurchase.serialNumbers.map((sn) => (
                <span key={sn} className="serial-chip">
                  {sn}
                </span>
              ))}
            </div>
          </div>

          {viewPurchase.notes && (
            <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '16px' }}>
              <strong>Notes:</strong> {viewPurchase.notes}
            </div>
          )}

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setViewPurchase(null)}
            >
              Close
            </button>
          </div>
        </Modal>
      )}

      {/* Edit Modal */}
      {editPurchase && (
        <Modal
          isOpen={true}
          onClose={() => setEditPurchase(null)}
          title={`Edit Purchase: ${editPurchase.batchNumber}`}
        >
          <form onSubmit={handleEditSubmit}>
            <div className="form-group">
              <label className="form-label">Batch Number</label>
              <input
                type="text"
                required
                className="form-input"
                value={editPurchase.batchNumber}
                onChange={(e) =>
                  setEditPurchase({ ...editPurchase, batchNumber: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label className="form-label">Supplier Name</label>
              <input
                type="text"
                className="form-input"
                value={editPurchase.supplierName || ''}
                onChange={(e) =>
                  setEditPurchase({ ...editPurchase, supplierName: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label className="form-label">Unit Purchase Price (₹)</label>
              <input
                type="number"
                min="0"
                step="50"
                className="form-input"
                value={editPurchase.unitPurchasePrice}
                onChange={(e) =>
                  setEditPurchase({
                    ...editPurchase,
                    unitPurchasePrice: Number(e.target.value),
                  })
                }
              />
            </div>

            <div className="form-group">
              <label className="form-label">Notes</label>
              <input
                type="text"
                className="form-input"
                value={editPurchase.notes || ''}
                onChange={(e) =>
                  setEditPurchase({ ...editPurchase, notes: e.target.value })
                }
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setEditPurchase(null)}
              >
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                Update Purchase
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Delete Confirmation Modal */}
      {deleteId && (
        <Modal
          isOpen={true}
          onClose={() => setDeleteId(null)}
          title="Confirm Purchase Deletion"
        >
          <p style={{ marginBottom: '16px', fontSize: '0.95rem' }}>
            Are you sure you want to delete this purchase batch?
          </p>
          <div className="alert-banner alert-warning" style={{ marginBottom: '16px' }}>
            <AlertCircle size={18} />
            <span>
              If any panels from this batch have already been sold, deletion will be blocked
              to protect sales record integrity.
            </span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setDeleteId(null)}
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn btn-danger"
              onClick={handleDelete}
            >
              Confirm Deletion
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
};

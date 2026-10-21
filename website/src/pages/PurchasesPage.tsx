import React, { useState, useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Search,
  Plus,
  Trash2,
  Edit,
  Eye,
  AlertCircle,
  CheckCircle2,
  Scan,
  Barcode,
  ClipboardPaste,
  Check,
  X,
  PackagePlus,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import type { PurchaseTransaction } from '../types';
import { Modal } from '../components/Modal';
import { Badge } from '../components/Badge';
import { WebBarcodeScannerModal } from '../components/WebBarcodeScannerModal';

export const PurchasesPage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [purchases, setPurchases] = useState<PurchaseTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [wattageFilter, setWattageFilter] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const availableWattages = useMemo(() => {
    const set = new Set<number>([540, 450, 400, 330]);
    purchases.forEach((p) => set.add(p.wattage));
    return Array.from(set).sort((a, b) => b - a);
  }, [purchases]);

  // Modals state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [viewPurchase, setViewPurchase] = useState<PurchaseTransaction | null>(null);
  const [editPurchase, setEditPurchase] = useState<PurchaseTransaction | null>(null);
  const [newSerialInEdit, setNewSerialInEdit] = useState('');
  const [deleteId, setDeleteId] = useState<string | null>(null);

  // Barcode scanner & individual serials state
  const [serials, setSerials] = useState<string[]>([]);
  const [singleSerialInput, setSingleSerialInput] = useState('');
  const [isScannerModalOpen, setIsScannerModalOpen] = useState(false);
  const [isBulkPasteOpen, setIsBulkPasteOpen] = useState(false);
  const [bulkPasteText, setBulkPasteText] = useState('');
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [editingValue, setEditingValue] = useState('');
  const [existingInventorySerials, setExistingInventorySerials] = useState<Set<string>>(new Set());

  // Add form fields
  const [formData, setFormData] = useState({
    purchaseDate: new Date().toISOString().split('T')[0],
    supplierName: '',
    batchNumber: '',
    wattage: 540,
    quantity: 1,
    unitPurchasePrice: 11500,
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

  const loadInventorySerials = async () => {
    try {
      const inventory = await apiService.getInventory();
      setExistingInventorySerials(new Set(inventory.map((p) => p.serialNumber.toUpperCase())));
    } catch {
      // ignore
    }
  };

  useEffect(() => {
    loadPurchases();
    loadInventorySerials();
    if (searchParams.get('action') === 'new') {
      setIsAddModalOpen(true);
      setSearchParams({});
    }
  }, [searchParams]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadPurchases();
  };

  // Find duplicates in entry
  const duplicateSerialsInEntry = useMemo(() => {
    const seen = new Set<string>();
    const dupes = new Set<string>();
    serials.forEach((s) => {
      const u = s.toUpperCase();
      if (seen.has(u)) dupes.add(u);
      else seen.add(u);
    });
    return Array.from(dupes);
  }, [serials]);

  // Find conflicts with existing inventory
  const conflictsWithInventory = useMemo(() => {
    return serials
      .filter((s) => existingInventorySerials.has(s.toUpperCase()))
      .map((s) => s.toUpperCase());
  }, [serials, existingInventorySerials]);

  const handleAddSingleSerial = (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const val = singleSerialInput.trim().toUpperCase();
    if (!val) return;

    if (serials.some((s) => s.toUpperCase() === val)) {
      setError(`Duplicate serial: "${val}" is already added to this batch.`);
      return;
    }

    if (existingInventorySerials.has(val)) {
      setError(`Conflict: "${val}" already exists in inventory.`);
      return;
    }

    setError(null);
    const updated = [...serials, val];
    setSerials(updated);
    setSingleSerialInput('');

    // If added serials exceed quantity, auto-update quantity
    if (updated.length > Number(formData.quantity)) {
      setFormData((prev) => ({ ...prev, quantity: updated.length }));
    }
  };

  const handleSaveEditSerial = (index: number) => {
    const val = editingValue.trim().toUpperCase();
    if (!val) return;

    const isDuplicate = serials.some((s, idx) => idx !== index && s.toUpperCase() === val);
    if (isDuplicate) {
      setError(`Serial "${val}" already exists in this batch.`);
      return;
    }

    if (existingInventorySerials.has(val)) {
      setError(`Serial "${val}" already exists in inventory.`);
      return;
    }

    setError(null);
    const updated = [...serials];
    updated[index] = val;
    setSerials(updated);
    setEditingIndex(null);
    setEditingValue('');
  };

  const handleRemoveSerial = (index: number) => {
    setSerials((prev) => prev.filter((_, i) => i !== index));
  };

  const handleApplyBulkPaste = () => {
    const tokens = bulkPasteText
      .split(/[\n,\s]+/)
      .map((s) => s.trim().toUpperCase())
      .filter((s) => s.length > 0);

    if (tokens.length === 0) return;

    const added: string[] = [];
    const dupes: string[] = [];
    const conflicts: string[] = [];
    const currentSet = new Set(serials.map((s) => s.toUpperCase()));

    for (const t of tokens) {
      if (currentSet.has(t)) {
        dupes.push(t);
      } else if (existingInventorySerials.has(t)) {
        conflicts.push(t);
      } else {
        currentSet.add(t);
        added.push(t);
      }
    }

    const updated = [...serials, ...added];
    setSerials(updated);
    setBulkPasteText('');
    setIsBulkPasteOpen(false);

    if (updated.length > Number(formData.quantity)) {
      setFormData((prev) => ({ ...prev, quantity: updated.length }));
    }

    if (dupes.length > 0 || conflicts.length > 0) {
      setError(
        `Added ${added.length} serials. Skipped ${dupes.length} duplicates and ${conflicts.length} inventory conflicts.`
      );
    } else {
      setError(null);
      setSuccessMsg(`Added ${added.length} serial numbers.`);
    }
  };

  const handleAddSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMsg(null);

    if (serials.length !== Number(formData.quantity)) {
      setError(
        `Purchase quantity is ${formData.quantity}, but you have entered ${serials.length} serial numbers. Please match the count.`
      );
      return;
    }

    if (duplicateSerialsInEntry.length > 0) {
      setError(`Duplicate serials found in entry: ${duplicateSerialsInEntry.join(', ')}`);
      return;
    }

    if (conflictsWithInventory.length > 0) {
      setError(`Serials already exist in inventory: ${conflictsWithInventory.join(', ')}`);
      return;
    }

    try {
      await apiService.createPurchase({
        purchaseDate: new Date(formData.purchaseDate).toISOString(),
        supplierName: formData.supplierName.trim() || undefined,
        batchNumber: formData.batchNumber.trim(),
        wattage: Number(formData.wattage),
        quantity: Number(formData.quantity),
        serialNumbers: serials,
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
        notes: '',
      });
      setSerials([]);
      setSingleSerialInput('');
      loadPurchases();
      loadInventorySerials();
    } catch (err: any) {
      setError(err.message || 'Failed to register purchase');
    }
  };

  const handleAddSerialToEdit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editPurchase || !newSerialInEdit.trim()) return;
    const sn = newSerialInEdit.trim().toUpperCase();
    if (editPurchase.serialNumbers.some((s) => s.toUpperCase() === sn)) {
      setError(`Serial "${sn}" already exists in this batch.`);
      return;
    }
    if (existingInventorySerials.has(sn)) {
      setError(`Serial "${sn}" already exists in inventory.`);
      return;
    }
    setError(null);
    setEditPurchase({
      ...editPurchase,
      serialNumbers: [...editPurchase.serialNumbers, sn],
      quantity: editPurchase.serialNumbers.length + 1,
    });
    setNewSerialInEdit('');
  };

  const handleRemoveSerialFromEdit = (index: number) => {
    if (!editPurchase) return;
    if (editPurchase.serialNumbers.length <= 1) {
      setError('A batch purchase must contain at least one panel serial number.');
      return;
    }
    setError(null);
    const updated = editPurchase.serialNumbers.filter((_, i) => i !== index);
    setEditPurchase({
      ...editPurchase,
      serialNumbers: updated,
      quantity: updated.length,
    });
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
        serialNumbers: editPurchase.serialNumbers,
      });
      setEditPurchase(null);
      setSuccessMsg('Purchase and panel serials updated successfully.');
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

  const { totalPurchasePanels, totalPurchaseExpenditure } = useMemo(() => {
    return purchases.reduce(
      (acc, p) => ({
        totalPurchasePanels: acc.totalPurchasePanels + (p.quantity || 0),
        totalPurchaseExpenditure: acc.totalPurchaseExpenditure + (p.totalPurchaseAmount || 0),
      }),
      { totalPurchasePanels: 0, totalPurchaseExpenditure: 0 }
    );
  }, [purchases]);

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

      {/* Top Total Purchases Summary Card */}
      <div
        className="card"
        style={{
          marginBottom: '20px',
          background: 'linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%)',
          borderColor: '#fde68a',
        }}
      >
        <div
          className="card-body"
          style={{
            padding: '16px 20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: '16px',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div
              style={{
                width: '48px',
                height: '48px',
                borderRadius: '10px',
                backgroundColor: 'rgba(217, 119, 6, 0.15)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#d97706',
              }}
            >
              <PackagePlus size={26} />
            </div>
            <div>
              <div
                style={{
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  letterSpacing: '0.05em',
                  textTransform: 'uppercase',
                  color: '#92400e',
                  marginBottom: '2px',
                }}
              >
                Total Inward Purchases
              </div>
              <div
                style={{
                  fontSize: '1.5rem',
                  fontWeight: 800,
                  color: '#1e293b',
                  lineHeight: 1.2,
                }}
              >
                {formatCurrency(totalPurchaseExpenditure)}
              </div>
              <div
                style={{
                  fontSize: '0.85rem',
                  color: '#b45309',
                  fontWeight: 600,
                  marginTop: '2px',
                }}
              >
                {totalPurchasePanels} Panels &bull; {purchases.length} Batches
              </div>
            </div>
          </div>
        </div>
      </div>

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
                {availableWattages.map((w) => (
                  <option key={w} value={w}>
                    {w}W
                  </option>
                ))}
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

          {/* Barcode Scanner & Serial Numbers Suite */}
          <div
            className="form-group"
            style={{
              border: '1px solid var(--color-border)',
              borderRadius: '8px',
              padding: '14px',
              background: 'var(--color-bg)',
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
              <label
                className="form-label"
                style={{
                  margin: 0,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  fontWeight: 600,
                }}
              >
                <Barcode size={18} color="var(--color-primary)" />
                Panel Serial Numbers *
              </label>
              <span
                style={{
                  fontSize: '0.85rem',
                  fontWeight: 700,
                  padding: '3px 8px',
                  borderRadius: '6px',
                  backgroundColor:
                    serials.length === Number(formData.quantity)
                      ? 'var(--color-green-light)'
                      : 'var(--color-danger-light)',
                  color:
                    serials.length === Number(formData.quantity)
                      ? 'var(--color-green-dark)'
                      : 'var(--color-danger)',
                }}
              >
                {serials.length} of {formData.quantity} serials entered
              </span>
            </div>

            {/* Action Buttons: Camera Scanner & Bulk Paste */}
            <div style={{ display: 'flex', gap: '8px', marginBottom: '10px' }}>
              <button
                type="button"
                className="btn btn-primary"
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                }}
                onClick={() => setIsScannerModalOpen(true)}
              >
                <Scan size={18} />
                Scan with Camera
              </button>
              <button
                type="button"
                className="btn btn-secondary"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                }}
                onClick={() => setIsBulkPasteOpen(!isBulkPasteOpen)}
              >
                <ClipboardPaste size={16} />
                {isBulkPasteOpen ? 'Close Paste' : 'Bulk Paste'}
              </button>
            </div>

            {/* Bulk Paste Box */}
            {isBulkPasteOpen && (
              <div
                style={{
                  background: '#fff',
                  border: '1px solid var(--color-border)',
                  borderRadius: '6px',
                  padding: '10px',
                  marginBottom: '10px',
                }}
              >
                <label className="form-label" style={{ fontSize: '0.8rem' }}>
                  Paste serial numbers separated by comma, space or newline:
                </label>
                <textarea
                  rows={3}
                  className="form-textarea"
                  placeholder="HZ-540-001, HZ-540-002, HZ-540-003..."
                  style={{ fontFamily: 'monospace', fontSize: '0.85rem', marginBottom: '8px' }}
                  value={bulkPasteText}
                  onChange={(e) => setBulkPasteText(e.target.value)}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  style={{ width: '100%', fontSize: '0.85rem' }}
                  onClick={handleApplyBulkPaste}
                >
                  Parse & Add Serials
                </button>
              </div>
            )}

            {/* Hardware Scanner & Quick Input Field */}
            <div style={{ display: 'flex', gap: '8px', marginBottom: '10px' }}>
              <div style={{ flex: 1, position: 'relative' }}>
                <input
                  type="text"
                  className="form-input"
                  placeholder="Scan with handheld barcode scanner or type serial..."
                  style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                  value={singleSerialInput}
                  onChange={(e) => setSingleSerialInput(e.target.value.toUpperCase())}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddSingleSerial();
                    }
                  }}
                />
              </div>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ display: 'flex', alignItems: 'center', gap: '4px' }}
                onClick={() => handleAddSingleSerial()}
              >
                <Plus size={16} /> Add
              </button>
            </div>

            {/* Warnings: In-batch Duplicates */}
            {duplicateSerialsInEntry.length > 0 && (
              <div
                className="alert-banner alert-danger"
                style={{ margin: '0 0 10px 0', padding: '8px 12px', fontSize: '0.8rem' }}
              >
                <AlertCircle size={16} />
                <div style={{ flex: 1 }}>
                  Duplicate serials detected: {duplicateSerialsInEntry.join(', ')}
                </div>
                <button
                  type="button"
                  className="btn btn-secondary"
                  style={{ padding: '2px 8px', fontSize: '0.75rem' }}
                  onClick={() => {
                    const unique = Array.from(new Set(serials.map((s) => s.toUpperCase())));
                    setSerials(unique);
                  }}
                >
                  Deduplicate
                </button>
              </div>
            )}

            {/* Warnings: Inventory Conflicts */}
            {conflictsWithInventory.length > 0 && (
              <div
                className="alert-banner alert-danger"
                style={{ margin: '0 0 10px 0', padding: '8px 12px', fontSize: '0.8rem' }}
              >
                <AlertCircle size={16} />
                <div>Already exists in inventory: {conflictsWithInventory.join(', ')}</div>
              </div>
            )}

            {/* Quantity Mismatch Sync Hint */}
            {serials.length !== Number(formData.quantity) && serials.length > 0 && (
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  background: 'var(--color-bg)',
                  border: '1px solid var(--color-border)',
                  borderRadius: '6px',
                  padding: '6px 10px',
                  fontSize: '0.8rem',
                  marginBottom: '10px',
                }}
              >
                <span>
                  {serials.length < Number(formData.quantity)
                    ? `Need ${Number(formData.quantity) - serials.length} more serial(s).`
                    : `${serials.length} serials entered for quantity ${formData.quantity}.`}
                </span>
                <button
                  type="button"
                  className="btn btn-secondary"
                  style={{ padding: '2px 8px', fontSize: '0.75rem' }}
                  onClick={() =>
                    setFormData((prev) => ({ ...prev, quantity: serials.length }))
                  }
                >
                  Set Quantity to {serials.length}
                </button>
              </div>
            )}

            {/* Serials List */}
            <div>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginBottom: '6px',
                }}
              >
                <span
                  style={{
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    color: 'var(--color-text-secondary)',
                  }}
                >
                  Scanned / Entered Panels ({serials.length})
                </span>
                {serials.length > 0 && (
                  <button
                    type="button"
                    onClick={() => setSerials([])}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--color-danger)',
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                    }}
                  >
                    Clear All
                  </button>
                )}
              </div>

              <div
                style={{
                  maxHeight: '180px',
                  overflowY: 'auto',
                  border: '1px solid var(--color-border)',
                  borderRadius: '6px',
                  background: '#fff',
                }}
              >
                {serials.length === 0 ? (
                  <div
                    style={{
                      textAlign: 'center',
                      padding: '20px',
                      color: 'var(--color-text-muted)',
                      fontSize: '0.85rem',
                    }}
                  >
                    No panels scanned or entered yet. Scan with camera, type above, or use a handheld barcode scanner.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column' }}>
                    {serials.map((sn, idx) => {
                      const isConflict = existingInventorySerials.has(sn.toUpperCase());
                      const isDuplicate =
                        serials.filter((s) => s.toUpperCase() === sn.toUpperCase()).length > 1;

                      return (
                        <div
                          key={`${sn}-${idx}`}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            padding: '6px 10px',
                            borderBottom:
                              idx < serials.length - 1 ? '1px solid var(--color-border)' : 'none',
                            background:
                              isConflict || isDuplicate
                                ? 'var(--color-danger-light)'
                                : idx % 2 === 0
                                ? '#fafafa'
                                : '#fff',
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flex: 1 }}>
                            <span
                              style={{
                                fontSize: '0.75rem',
                                fontWeight: 700,
                                color:
                                  isConflict || isDuplicate
                                    ? 'var(--color-danger)'
                                    : 'var(--color-primary)',
                                minWidth: '24px',
                              }}
                            >
                              #{idx + 1}
                            </span>
                            {editingIndex === idx ? (
                              <input
                                type="text"
                                className="form-input"
                                autoFocus
                                value={editingValue}
                                onChange={(e) => setEditingValue(e.target.value.toUpperCase())}
                                onKeyDown={(e) => {
                                  if (e.key === 'Enter') {
                                    e.preventDefault();
                                    handleSaveEditSerial(idx);
                                  } else if (e.key === 'Escape') {
                                    setEditingIndex(null);
                                  }
                                }}
                                style={{
                                  padding: '2px 6px',
                                  fontSize: '0.85rem',
                                  fontFamily: 'monospace',
                                  width: '200px',
                                }}
                              />
                            ) : (
                              <span
                                style={{
                                  fontFamily: 'monospace',
                                  fontSize: '0.85rem',
                                  fontWeight: 600,
                                  color:
                                    isConflict || isDuplicate
                                      ? 'var(--color-danger)'
                                      : 'var(--color-text)',
                                }}
                              >
                                {sn}
                                {isConflict && (
                                  <span style={{ fontSize: '0.75rem', color: 'var(--color-danger)', marginLeft: '6px' }}>
                                    (in inventory)
                                  </span>
                                )}
                                {isDuplicate && (
                                  <span style={{ fontSize: '0.75rem', color: 'var(--color-danger)', marginLeft: '6px' }}>
                                    (duplicate)
                                  </span>
                                )}
                              </span>
                            )}
                          </div>

                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                            {editingIndex === idx ? (
                              <>
                                <button
                                  type="button"
                                  onClick={() => handleSaveEditSerial(idx)}
                                  className="btn-icon"
                                  title="Save edit"
                                  style={{ color: 'var(--color-green-dark)' }}
                                >
                                  <Check size={14} />
                                </button>
                                <button
                                  type="button"
                                  onClick={() => setEditingIndex(null)}
                                  className="btn-icon"
                                  title="Cancel"
                                >
                                  <X size={14} />
                                </button>
                              </>
                            ) : (
                              <>
                                <button
                                  type="button"
                                  onClick={() => {
                                    setEditingIndex(idx);
                                    setEditingValue(sn);
                                  }}
                                  className="btn-icon"
                                  title="Edit serial"
                                >
                                  <Edit size={14} />
                                </button>
                                <button
                                  type="button"
                                  onClick={() => handleRemoveSerial(idx)}
                                  className="btn-icon"
                                  title="Remove"
                                  style={{ color: 'var(--color-danger)' }}
                                >
                                  <Trash2 size={14} />
                                </button>
                              </>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
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

      {/* Web Camera Barcode Scanner Modal */}
      <WebBarcodeScannerModal
        isOpen={isScannerModalOpen}
        onClose={() => setIsScannerModalOpen(false)}
        targetQuantity={Number(formData.quantity) || 1}
        initialSerials={serials}
        existingInventorySerials={existingInventorySerials}
        onSaveSerials={(scanned) => {
          setSerials(scanned);
          if (scanned.length > Number(formData.quantity)) {
            setFormData((prev) => ({ ...prev, quantity: scanned.length }));
          }
        }}
      />

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

            {/* Panels Management within Batch */}
            <div style={{ marginTop: '20px', marginBottom: '20px', borderTop: '1px solid var(--color-border)', paddingTop: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                <div>
                  <h4 style={{ margin: 0, fontSize: '14px', fontWeight: 700 }}>
                    Panels in Batch ({editPurchase.serialNumbers.length})
                  </h4>
                  <span style={{ fontSize: '12px', color: 'var(--color-text-secondary)' }}>
                    Total Amount: ₹{((editPurchase.serialNumbers.length) * Number(editPurchase.unitPurchasePrice)).toLocaleString('en-IN')}
                  </span>
                </div>
              </div>

              {/* Quick Add Serial Input */}
              <div style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
                <input
                  type="text"
                  placeholder="Enter serial number to add to this batch..."
                  className="form-input"
                  style={{ textTransform: 'uppercase' }}
                  value={newSerialInEdit}
                  onChange={(e) => setNewSerialInEdit(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddSerialToEdit(e);
                    }
                  }}
                />
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={handleAddSerialToEdit}
                  disabled={!newSerialInEdit.trim()}
                >
                  <Plus size={14} style={{ marginRight: '4px' }} /> Add
                </button>
              </div>

              {/* Serial List */}
              <div
                style={{
                  maxHeight: '180px',
                  overflowY: 'auto',
                  border: '1px solid var(--color-border)',
                  borderRadius: '6px',
                  padding: '8px',
                  display: 'flex',
                  flexWrap: 'wrap',
                  gap: '6px',
                  backgroundColor: 'var(--color-bg)',
                }}
              >
                {editPurchase.serialNumbers.map((sn, idx) => (
                  <div
                    key={idx}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      backgroundColor: 'var(--color-surface)',
                      border: '1px solid var(--color-border)',
                      borderRadius: '4px',
                      padding: '4px 8px',
                      fontSize: '12px',
                      fontFamily: 'monospace',
                    }}
                  >
                    <span>{sn}</span>
                    <button
                      type="button"
                      style={{
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        padding: 0,
                        color: 'var(--color-danger)',
                        display: 'flex',
                        alignItems: 'center',
                      }}
                      title="Remove panel from batch"
                      onClick={() => handleRemoveSerialFromEdit(idx)}
                    >
                      <X size={12} />
                    </button>
                  </div>
                ))}
              </div>
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

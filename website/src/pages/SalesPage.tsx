import React, { useState, useEffect, useMemo } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import {
  Search,
  Plus,
  Trash2,
  Eye,
  AlertCircle,
  CheckCircle2,
  Check,
  UserCheck,
  Scan,
  Barcode,
  ShoppingCart,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import type { SaleTransaction, Customer, PanelItem, StockByWattage, PurchaseTransaction } from '../types';
import { Modal } from '../components/Modal';
import { Badge } from '../components/Badge';
import { SaleBarcodeScannerModal } from '../components/SaleBarcodeScannerModal';

export const SalesPage: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [sales, setSales] = useState<SaleTransaction[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [wattageFilter, setWattageFilter] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const [stockByWattage, setStockByWattage] = useState<StockByWattage[]>([]);

  // Modals state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [viewSale, setViewSale] = useState<SaleTransaction | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  // Available panels for selected wattage
  const [availablePanels, setAvailablePanels] = useState<PanelItem[]>([]);
  const [allPanels, setAllPanels] = useState<PanelItem[]>([]);
  const [purchases, setPurchases] = useState<PurchaseTransaction[]>([]);
  const [loadingPanels, setLoadingPanels] = useState(false);

  // Barcode scanner & search states for sales
  const [isScannerModalOpen, setIsScannerModalOpen] = useState(false);
  const [panelSearchQuery, setPanelSearchQuery] = useState('');
  const [panelFilterTab, setPanelFilterTab] = useState<'all' | 'selected' | 'unselected'>('all');
  const [scanInputValue, setScanInputValue] = useState('');

  // Add form fields
  const [formData, setFormData] = useState({
    saleDate: new Date().toISOString().split('T')[0],
    customerId: '',
    panelWattage: 540,
    selectedSerials: [] as string[],
    unitSellingPrice: 14500,
    notes: '',
  });

  const availableWattages = useMemo(() => {
    const set = new Set<number>([540, 450, 400, 330]);
    stockByWattage.forEach((s) => set.add(s.wattage));
    sales.forEach((s) => set.add(s.panelWattage));
    return Array.from(set).sort((a, b) => b - a);
  }, [stockByWattage, sales]);

  const getWattageLabel = (wattage: number) => {
    const stock = stockByWattage.find((s) => s.wattage === wattage);
    const countInfo = stock ? ` (${stock.availableCount} available)` : '';
    switch (wattage) {
      case 540:
        return `540W Mono PERC${countInfo}`;
      case 450:
        return `450W Bifacial${countInfo}`;
      case 400:
        return `400W High Efficiency${countInfo}`;
      case 330:
        return `330W Polycrystalline${countInfo}`;
      default:
        return `${wattage}W Solar Panel${countInfo}`;
    }
  };

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [salesData, custData, stockData, invData, purchasesData] = await Promise.all([
        apiService.getSales({
          search,
          wattage: wattageFilter ? Number(wattageFilter) : undefined,
        }),
        apiService.getCustomers(),
        apiService.getStockByWattage(),
        apiService.getInventory(),
        apiService.getPurchases(),
      ]);
      setSales(salesData);
      setCustomers(custData);
      setStockByWattage(stockData);
      setAllPanels(invData);
      setPurchases(purchasesData);
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

  const filteredAvailablePanels = useMemo(() => {
    let list = availablePanels;
    if (panelFilterTab === 'selected') {
      list = list.filter((p) => formData.selectedSerials.includes(p.serialNumber));
    } else if (panelFilterTab === 'unselected') {
      list = list.filter((p) => !formData.selectedSerials.includes(p.serialNumber));
    }
    if (panelSearchQuery.trim()) {
      const q = panelSearchQuery.trim().toLowerCase();
      list = list.filter(
        (p) =>
          p.serialNumber.toLowerCase().includes(q) ||
          p.batchNumber.toLowerCase().includes(q)
      );
    }
    return list;
  }, [availablePanels, formData.selectedSerials, panelFilterTab, panelSearchQuery]);

  const handleScanOrSubmit = (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const serial = scanInputValue.trim().toUpperCase();
    if (!serial) return;

    if (formData.selectedSerials.includes(serial)) {
      setError(`Panel "${serial}" is already selected.`);
      setScanInputValue('');
      return;
    }

    const match = availablePanels.find((p) => p.serialNumber.toUpperCase() === serial);
    if (match) {
      toggleSerialSelection(match.serialNumber);
      setError(null);
      setSuccessMsg(`✓ Selected panel "${match.serialNumber}" (Batch: ${match.batchNumber})`);
      setScanInputValue('');
      setPanelSearchQuery('');
      return;
    }

    // Diagnose why it wasn't matched
    const inAll = allPanels.find((p) => p.serialNumber.toUpperCase() === serial);
    if (inAll) {
      if (inAll.wattage !== Number(formData.panelWattage)) {
        setError(
          `Wattage Mismatch: "${serial}" is ${inAll.wattage}W (current selection is ${formData.panelWattage}W).`
        );
      } else if (inAll.status === 'sold') {
        setError(`Panel "${serial}" is already SOLD and cannot be dispatched.`);
      } else {
        setError(`Panel "${serial}" is not available for selection.`);
      }
    } else {
      setError(`Serial "${serial}" not found in inventory for ${formData.panelWattage}W stock.`);
    }
    setScanInputValue('');
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

  const { totalSoldPanels, totalSalesRevenue } = useMemo(() => {
    return sales.reduce(
      (acc, s) => ({
        totalSoldPanels: acc.totalSoldPanels + (s.quantity || 0),
        totalSalesRevenue: acc.totalSalesRevenue + (s.totalSellingAmount || 0),
      }),
      { totalSoldPanels: 0, totalSalesRevenue: 0 }
    );
  }, [sales]);

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

      {/* Top Total Sales Revenue Summary Card */}
      <div
        className="card"
        style={{
          marginBottom: '20px',
          background: 'linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%)',
          borderColor: '#bfdbfe',
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
                backgroundColor: 'rgba(37, 99, 235, 0.15)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#2563eb',
              }}
            >
              <ShoppingCart size={26} />
            </div>
            <div>
              <div
                style={{
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  letterSpacing: '0.05em',
                  textTransform: 'uppercase',
                  color: '#1e40af',
                  marginBottom: '2px',
                }}
              >
                Total Sales Revenue
              </div>
              <div
                style={{
                  fontSize: '1.5rem',
                  fontWeight: 800,
                  color: '#1e293b',
                  lineHeight: 1.2,
                }}
              >
                {formatCurrency(totalSalesRevenue)}
              </div>
              <div
                style={{
                  fontSize: '0.85rem',
                  color: '#1d4ed8',
                  fontWeight: 600,
                  marginTop: '2px',
                }}
              >
                {totalSoldPanels} Panels &bull; {sales.length} Orders
              </div>
            </div>
          </div>
        </div>
      </div>

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
                {availableWattages.map((w) => (
                  <option key={w} value={w}>
                    {getWattageLabel(w)}
                  </option>
                ))}
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

          {/* Available Serial Numbers Selector with Barcode Scanner & Search */}
          <div
            className="form-group"
            style={{
              border: '1px solid var(--border-color)',
              borderRadius: '8px',
              padding: '14px',
              backgroundColor: '#f8fafc',
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
                Select Physical Panels ({availablePanels.length} available) *
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

            {availablePanels.length > 0 && (
              <>
                {/* Camera Scanner Button */}
                <div style={{ marginBottom: '10px' }}>
                  <button
                    type="button"
                    className="btn btn-primary"
                    style={{
                      width: '100%',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '8px',
                    }}
                    onClick={() => setIsScannerModalOpen(true)}
                  >
                    <Scan size={18} />
                    Scan Panel Barcodes ({formData.selectedSerials.length} of {availablePanels.length} Selected)
                  </button>
                </div>

                {/* Fast Hardware Barcode Scanner & Search Input Field */}
                <div style={{ display: 'flex', gap: '8px', marginBottom: '10px' }}>
                  <div style={{ flex: 1, position: 'relative' }}>
                    <input
                      type="text"
                      className="form-input"
                      placeholder="Scan panel barcode or search serial (Press Enter to select)..."
                      style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                      value={scanInputValue}
                      onChange={(e) => {
                        setScanInputValue(e.target.value.toUpperCase());
                        setPanelSearchQuery(e.target.value);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleScanOrSubmit();
                        }
                      }}
                    />
                  </div>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    style={{ whiteSpace: 'nowrap' }}
                    onClick={() => handleScanOrSubmit()}
                  >
                    <Plus size={16} /> Select
                  </button>
                </div>

                {/* Filter Pills for 500+ panels */}
                <div style={{ display: 'flex', gap: '6px', marginBottom: '10px' }}>
                  <button
                    type="button"
                    className={`badge ${panelFilterTab === 'all' ? 'badge-primary' : 'badge-gray'}`}
                    style={{ cursor: 'pointer', border: 'none', padding: '4px 10px' }}
                    onClick={() => setPanelFilterTab('all')}
                  >
                    All ({availablePanels.length})
                  </button>
                  <button
                    type="button"
                    className={`badge ${panelFilterTab === 'selected' ? 'badge-green' : 'badge-gray'}`}
                    style={{ cursor: 'pointer', border: 'none', padding: '4px 10px' }}
                    onClick={() => setPanelFilterTab('selected')}
                  >
                    Selected ({formData.selectedSerials.length})
                  </button>
                  <button
                    type="button"
                    className={`badge ${panelFilterTab === 'unselected' ? 'badge-orange' : 'badge-gray'}`}
                    style={{ cursor: 'pointer', border: 'none', padding: '4px 10px' }}
                    onClick={() => setPanelFilterTab('unselected')}
                  >
                    Unselected ({availablePanels.length - formData.selectedSerials.length})
                  </button>
                </div>
              </>
            )}

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
            ) : filteredAvailablePanels.length === 0 ? (
              <div
                style={{
                  padding: '16px',
                  textAlign: 'center',
                  color: 'var(--text-muted)',
                  fontSize: '0.85rem',
                  backgroundColor: '#fff',
                  borderRadius: '6px',
                  border: '1px solid var(--border-color)',
                }}
              >
                {panelSearchQuery
                  ? `No panels match "${panelSearchQuery}".`
                  : panelFilterTab === 'selected'
                  ? 'No panels selected yet. Scan barcodes or select below.'
                  : 'All available panels are currently selected.'}
              </div>
            ) : (
              <div
                className="serial-chips-grid"
                style={{
                  maxHeight: '240px',
                  overflowY: 'auto',
                  padding: '8px',
                  backgroundColor: '#fff',
                  borderRadius: '6px',
                  border: '1px solid var(--border-color)',
                }}
              >
                {filteredAvailablePanels.map((p) => {
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
                backgroundColor: '#fff',
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

      {/* Sale Camera Barcode Scanner Modal */}
      <SaleBarcodeScannerModal
        isOpen={isScannerModalOpen}
        onClose={() => setIsScannerModalOpen(false)}
        wattage={Number(formData.panelWattage)}
        availablePanels={availablePanels}
        selectedSerials={formData.selectedSerials}
        onToggleSerial={toggleSerialSelection}
        onClearAll={clearSelection}
      />

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

          {/* Associated Purchases */}
          {(() => {
            const linkedPurchases = purchases.filter((p) =>
              viewSale.serialNumbers.some((sn) => {
                const panel = allPanels.find((item) => item.serialNumber === sn);
                return (
                  p.id === panel?.purchaseId ||
                  p.batchNumber === panel?.batchNumber ||
                  p.serialNumbers.includes(sn)
                );
              })
            );

            if (linkedPurchases.length === 0) return null;

            return (
              <div style={{ marginBottom: '16px' }}>
                <span
                  style={{
                    fontSize: '0.85rem',
                    fontWeight: 600,
                    display: 'block',
                    marginBottom: '8px',
                  }}
                >
                  Source Inward Purchase ({linkedPurchases.length}{' '}
                  {linkedPurchases.length === 1 ? 'batch' : 'batches'}):
                </span>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {linkedPurchases.map((purchase) => {
                    const countInSale = viewSale.serialNumbers.filter((sn) => {
                      const panel = allPanels.find((item) => item.serialNumber === sn);
                      return (
                        purchase.id === panel?.purchaseId ||
                        purchase.batchNumber === panel?.batchNumber ||
                        purchase.serialNumbers.includes(sn)
                      );
                    }).length;

                    return (
                      <div
                        key={purchase.id}
                        style={{
                          border: '1px solid var(--border-color)',
                          borderRadius: '8px',
                          padding: '12px',
                          backgroundColor: 'var(--bg-light, #f8fafc)',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          flexWrap: 'wrap',
                          gap: '8px',
                        }}
                      >
                        <div>
                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: '8px',
                              marginBottom: '4px',
                            }}
                          >
                            <strong style={{ fontSize: '0.9rem' }}>
                              Batch: {purchase.batchNumber}
                            </strong>
                            <Badge variant="info">{purchase.wattage}W</Badge>
                          </div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                            {purchase.supplierName ? `${purchase.supplierName} • ` : ''}
                            {new Date(purchase.purchaseDate).toLocaleDateString('en-IN')} • Inward Unit Price:{' '}
                            <strong style={{ color: 'var(--text-main)' }}>
                              {formatCurrency(purchase.unitPurchasePrice)}
                            </strong>
                          </div>
                          <div
                            style={{
                              fontSize: '0.78rem',
                              color: 'var(--text-muted)',
                              marginTop: '2px',
                            }}
                          >
                            Allocated: {countInSale} of {viewSale.serialNumbers.length} dispatched
                            ({countInSale}/{purchase.quantity} in batch)
                          </div>
                        </div>
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ fontSize: '0.8rem', padding: '6px 12px' }}
                          onClick={() => {
                            setViewSale(null);
                            navigate(
                              `/purchases?search=${encodeURIComponent(purchase.batchNumber)}`
                            );
                          }}
                        >
                          View Inward Purchase ↗
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })()}

          <div style={{ marginBottom: '16px' }}>
            <span
              style={{
                fontSize: '0.85rem',
                fontWeight: 600,
                display: 'block',
                marginBottom: '8px',
              }}
            >
              Allocated Serial Numbers ({viewSale.serialNumbers.length}):
            </span>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {viewSale.serialNumbers.map((sn) => {
                const panel = allPanels.find((p) => p.serialNumber === sn);
                const purchase = purchases.find(
                  (p) =>
                    p.id === panel?.purchaseId ||
                    p.batchNumber === panel?.batchNumber ||
                    p.serialNumbers.includes(sn)
                );
                const batchNum = panel?.batchNumber || purchase?.batchNumber;
                const inwardPrice = panel?.purchasePrice ?? purchase?.unitPurchasePrice;

                return (
                  <div
                    key={sn}
                    style={{
                      border: '1px solid var(--border-color)',
                      borderRadius: '8px',
                      padding: '10px 14px',
                      backgroundColor: 'var(--bg-white, #ffffff)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      flexWrap: 'wrap',
                      gap: '8px',
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        flexWrap: 'wrap',
                      }}
                    >
                      <span
                        style={{
                          fontFamily: 'monospace',
                          fontWeight: 700,
                          fontSize: '0.88rem',
                        }}
                      >
                        {sn}
                      </span>
                      <span
                        style={{
                          fontSize: '0.75rem',
                          padding: '2px 8px',
                          borderRadius: '4px',
                          backgroundColor: '#e0f2fe',
                          color: '#0369a1',
                          fontWeight: 600,
                        }}
                      >
                        Batch: {batchNum || 'N/A'}
                      </span>
                      <span
                        style={{
                          fontSize: '0.75rem',
                          padding: '2px 8px',
                          borderRadius: '4px',
                          backgroundColor: '#f1f5f9',
                          color: '#475569',
                          fontWeight: 600,
                        }}
                      >
                        Inward: {inwardPrice != null ? formatCurrency(inwardPrice) : 'N/A'}
                      </span>
                      <span
                        style={{
                          fontSize: '0.75rem',
                          padding: '2px 8px',
                          borderRadius: '4px',
                          backgroundColor: '#dcfce7',
                          color: '#15803d',
                          fontWeight: 600,
                        }}
                      >
                        Sale: {formatCurrency(viewSale.unitSellingPrice)}
                      </span>
                    </div>
                    {purchase && (
                      <button
                        type="button"
                        style={{
                          background: 'none',
                          border: 'none',
                          color: 'var(--color-primary)',
                          fontSize: '0.8rem',
                          fontWeight: 600,
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          padding: '4px 6px',
                        }}
                        onClick={() => {
                          setViewSale(null);
                          navigate(
                            `/purchases?search=${encodeURIComponent(purchase.batchNumber)}`
                          );
                        }}
                      >
                        View Purchase ↗
                      </button>
                    )}
                  </div>
                );
              })}
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

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
  Phone,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import type { Customer, SaleTransaction } from '../types';
import { Modal } from '../components/Modal';

export const CustomersPage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Modals state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [viewCustomer, setViewCustomer] = useState<(Customer & { sales: SaleTransaction[] }) | null>(null);
  const [editCustomer, setEditCustomer] = useState<Customer | null>(null);
  const [deleteCustomerObj, setDeleteCustomerObj] = useState<Customer | null>(null);

  // Add form fields
  const [formData, setFormData] = useState({
    consumerNumber: '',
    phone: '',
    name: '',
    address: '',
  });

  const loadCustomers = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await apiService.getCustomers(search);
      setCustomers(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load customers');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCustomers();
    if (searchParams.get('action') === 'new') {
      setIsAddModalOpen(true);
      setSearchParams({});
    }
  }, [searchParams]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadCustomers();
  };

  const handleAddSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccessMsg(null);

    const consumerNumber = formData.consumerNumber.trim();
    const phone = formData.phone.trim();

    if (!consumerNumber) {
      setError('KSEB consumer number is mandatory.');
      return;
    }
    if (!phone) {
      setError('Phone number is mandatory.');
      return;
    }

    try {
      await apiService.createCustomer({
        consumerNumber,
        phone,
        name: formData.name.trim() || undefined,
        address: formData.address.trim() || undefined,
      });

      setIsAddModalOpen(false);
      setSuccessMsg('Customer account created successfully.');
      setFormData({ consumerNumber: '', phone: '', name: '', address: '' });
      loadCustomers();
    } catch (err: any) {
      setError(err.message || 'Failed to create customer');
    }
  };

  const handleEditSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editCustomer) return;
    try {
      await apiService.updateCustomer(editCustomer.id, {
        consumerNumber: editCustomer.consumerNumber.trim(),
        phone: editCustomer.phone.trim(),
        name: editCustomer.name?.trim() || undefined,
        address: editCustomer.address?.trim() || undefined,
      });
      setEditCustomer(null);
      setSuccessMsg('Customer details updated successfully.');
      loadCustomers();
    } catch (err: any) {
      setError(err.message || 'Failed to update customer');
    }
  };

  const handleView = async (customer: Customer) => {
    try {
      const full = await apiService.getCustomerById(customer.id);
      setViewCustomer(full);
    } catch (err: any) {
      setError(err.message || 'Failed to load customer details');
    }
  };

  const handleDelete = async () => {
    if (!deleteCustomerObj) return;
    try {
      await apiService.deleteCustomer(deleteCustomerObj.id);
      setDeleteCustomerObj(null);
      setSuccessMsg(`Customer ${deleteCustomerObj.name || deleteCustomerObj.consumerNumber} deleted.`);
      loadCustomers();
    } catch (err: any) {
      setError(err.message || 'Cannot delete customer');
      setDeleteCustomerObj(null);
    }
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
            <div style={{ flex: '1 1 300px' }}>
              <input
                type="text"
                className="form-input"
                placeholder="Search KSEB consumer number, phone number, or customer name..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            <button type="submit" className="btn btn-secondary">
              <Search size={16} /> Search
            </button>

            <button
              type="button"
              className="btn btn-primary"
              style={{ marginLeft: 'auto' }}
              onClick={() => setIsAddModalOpen(true)}
            >
              <Plus size={16} /> Add KSEB Customer
            </button>
          </form>
        </div>
      </div>

      {/* Customers Table */}
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">KSEB Registered Customers ({customers.length})</h2>
        </div>
        <div className="table-responsive">
          <table className="data-table">
            <thead>
              <tr>
                <th>KSEB Consumer #</th>
                <th>Customer Name</th>
                <th>Phone Number</th>
                <th>Address</th>
                <th>Registered On</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '30px' }}>
                    Loading customer directory...
                  </td>
                </tr>
              ) : customers.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '30px', color: 'var(--text-muted)' }}>
                    No customer accounts found.
                  </td>
                </tr>
              ) : (
                customers.map((c) => (
                  <tr key={c.id}>
                    <td>
                      <span
                        style={{
                          fontFamily: 'monospace',
                          fontWeight: 700,
                          color: 'var(--color-primary)',
                        }}
                      >
                        {c.consumerNumber}
                      </span>
                    </td>
                    <td>
                      <strong>{c.name || '—'}</strong>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Phone size={13} color="var(--text-muted)" />
                        <span>{c.phone}</span>
                      </div>
                    </td>
                    <td>
                      <div
                        style={{
                          maxWidth: '280px',
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          fontSize: '0.85rem',
                          color: 'var(--text-muted)',
                        }}
                      >
                        {c.address || '—'}
                      </div>
                    </td>
                    <td>{new Date(c.createdAt).toLocaleDateString('en-IN')}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => handleView(c)}
                          title="View Profile & Linked Sales"
                        >
                          <Eye size={14} />
                        </button>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          onClick={() => setEditCustomer(c)}
                          title="Edit Customer"
                        >
                          <Edit size={14} />
                        </button>
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          style={{ color: 'var(--color-danger)' }}
                          onClick={() => setDeleteCustomerObj(c)}
                          title="Delete Customer"
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

      {/* Add Customer Modal */}
      <Modal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        title="Add New KSEB Customer"
      >
        <form onSubmit={handleAddSubmit}>
          <div className="form-group">
            <label className="form-label">KSEB Consumer Number (Mandatory) *</label>
            <input
              type="text"
              required
              placeholder="e.g. 1155443322110"
              className="form-input"
              value={formData.consumerNumber}
              onChange={(e) => setFormData({ ...formData, consumerNumber: e.target.value })}
            />
            <div className="form-hint">
              Unique KSEB 13-digit consumer number assigned to solar installation site.
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Phone Number (Mandatory) *</label>
            <input
              type="text"
              required
              placeholder="e.g. +91 98470 12345"
              className="form-input"
              value={formData.phone}
              onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
            />
          </div>

          <div className="form-group">
            <label className="form-label">Full Name (Optional)</label>
            <input
              type="text"
              placeholder="e.g. Venu Gopal Nair"
              className="form-input"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            />
          </div>

          <div className="form-group">
            <label className="form-label">Site Address (Optional)</label>
            <textarea
              rows={3}
              placeholder="House name, street, post office, district..."
              className="form-textarea"
              value={formData.address}
              onChange={(e) => setFormData({ ...formData, address: e.target.value })}
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
            <button type="submit" className="btn btn-primary">
              Register Customer
            </button>
          </div>
        </form>
      </Modal>

      {/* View Customer Details + Linked Sales */}
      {viewCustomer && (
        <Modal
          isOpen={true}
          onClose={() => setViewCustomer(null)}
          title={`Customer: ${viewCustomer.name || viewCustomer.consumerNumber}`}
          maxWidth="640px"
        >
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '20px' }}>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>KSEB Consumer #:</span>
              <div style={{ fontFamily: 'monospace', fontWeight: 700, color: 'var(--color-primary)' }}>
                {viewCustomer.consumerNumber}
              </div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Phone:</span>
              <div>{viewCustomer.phone}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Name:</span>
              <div>{viewCustomer.name || 'Not provided'}</div>
            </div>
            <div>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Address:</span>
              <div>{viewCustomer.address || 'Not provided'}</div>
            </div>
          </div>

          <div>
            <h3 style={{ fontSize: '1rem', marginBottom: '10px' }}>
              Linked Solar Sales ({viewCustomer.sales?.length || 0})
            </h3>
            {viewCustomer.sales && viewCustomer.sales.length > 0 ? (
              <div className="table-responsive">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>Wattage</th>
                      <th>Panels</th>
                      <th>Amount (₹)</th>
                      <th>Serials</th>
                    </tr>
                  </thead>
                  <tbody>
                    {viewCustomer.sales.map((s) => (
                      <tr key={s.id}>
                        <td>{new Date(s.saleDate).toLocaleDateString('en-IN')}</td>
                        <td>{s.panelWattage}W</td>
                        <td>{s.quantity} pcs</td>
                        <td>₹{s.totalSellingAmount.toLocaleString('en-IN')}</td>
                        <td style={{ fontSize: '0.78rem', fontFamily: 'monospace' }}>
                          {s.serialNumbers.join(', ')}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p style={{ fontSize: '0.88rem', color: 'var(--text-muted)' }}>
                No sales recorded for this customer yet.
              </p>
            )}
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '20px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setViewCustomer(null)}
            >
              Close
            </button>
          </div>
        </Modal>
      )}

      {/* Edit Customer Modal */}
      {editCustomer && (
        <Modal
          isOpen={true}
          onClose={() => setEditCustomer(null)}
          title="Edit Customer Details"
        >
          <form onSubmit={handleEditSubmit}>
            <div className="form-group">
              <label className="form-label">KSEB Consumer Number *</label>
              <input
                type="text"
                required
                className="form-input"
                value={editCustomer.consumerNumber}
                onChange={(e) =>
                  setEditCustomer({ ...editCustomer, consumerNumber: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label className="form-label">Phone Number *</label>
              <input
                type="text"
                required
                className="form-input"
                value={editCustomer.phone}
                onChange={(e) =>
                  setEditCustomer({ ...editCustomer, phone: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label className="form-label">Full Name</label>
              <input
                type="text"
                className="form-input"
                value={editCustomer.name || ''}
                onChange={(e) =>
                  setEditCustomer({ ...editCustomer, name: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label className="form-label">Site Address</label>
              <textarea
                rows={3}
                className="form-textarea"
                value={editCustomer.address || ''}
                onChange={(e) =>
                  setEditCustomer({ ...editCustomer, address: e.target.value })
                }
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '20px' }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setEditCustomer(null)}
              >
                Cancel
              </button>
              <button type="submit" className="btn btn-primary">
                Update Customer
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Safe Delete Protection Modal */}
      {deleteCustomerObj && (
        <Modal
          isOpen={true}
          onClose={() => setDeleteCustomerObj(null)}
          title="Confirm Customer Deletion"
        >
          <p style={{ marginBottom: '14px' }}>
            Are you sure you want to delete customer{' '}
            <strong>{deleteCustomerObj.name || deleteCustomerObj.consumerNumber}</strong>?
          </p>
          <div className="alert-banner alert-warning">
            <AlertCircle size={18} />
            <span>
              If this customer has any linked solar purchase/sale records, deletion will be blocked
              to prevent breaking transaction history and warranty traceability.
            </span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setDeleteCustomerObj(null)}
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

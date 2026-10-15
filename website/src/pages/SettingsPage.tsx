import React, { useState, useEffect } from 'react';
import {
  User,
  Download,
  AlertTriangle,
  CheckCircle2,
  RefreshCw,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { Badge } from '../components/Badge';

export const SettingsPage: React.FC = () => {
  const [apiUrl, setApiUrl] = useState(apiService.getBaseUrl());
  const [healthStatus, setHealthStatus] = useState<any>(null);
  const [checkingHealth, setCheckingHealth] = useState(false);
  const [statusMsg, setStatusMsg] = useState<string | null>(null);

  const testConnection = async () => {
    try {
      setCheckingHealth(true);
      setStatusMsg(null);
      const res = await apiService.checkHealth();
      setHealthStatus(res);
      setStatusMsg('Connected to backend successfully!');
    } catch (err: any) {
      setHealthStatus(null);
      setStatusMsg(`Connection failed: ${err.message}`);
    } finally {
      setCheckingHealth(false);
    }
  };

  useEffect(() => {
    testConnection();
  }, []);

  const handleSaveApiUrl = (e: React.FormEvent) => {
    e.preventDefault();
    apiService.setBaseUrl(apiUrl);
    testConnection();
  };

  const handleExportData = async () => {
    try {
      const summary = await apiService.getDashboardSummary();
      const customers = await apiService.getCustomers();
      const purchases = await apiService.getPurchases();
      const sales = await apiService.getSales();
      const panels = await apiService.getInventory();

      const exportObj = {
        exportedAt: new Date().toISOString(),
        company: 'Horizone Energy',
        system: 'Horizone StockFlow',
        summary,
        customers,
        purchases,
        sales,
        panels,
      };

      const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(exportObj, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute('href', dataStr);
      downloadAnchor.setAttribute('download', `horizone_stockflow_export_${Date.now()}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    } catch (err: any) {
      alert(`Export failed: ${err.message}`);
    }
  };

  return (
    <div style={{ maxWidth: '800px' }}>
      {/* Profile Card */}
      <div className="card" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h2 className="card-title">User Profile & Organization</h2>
        </div>
        <div className="card-body">
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '20px' }}>
            <div
              style={{
                width: '64px',
                height: '64px',
                borderRadius: '50%',
                background: 'linear-gradient(135deg, #1b75bc, #10b981)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#ffffff',
              }}
            >
              <User size={32} />
            </div>
            <div>
              <h3 style={{ fontSize: '1.15rem', margin: 0 }}>Stock Operations Manager</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', margin: '2px 0 0' }}>
                Horizone Energy • Inventory & KSEB Customer Division
              </p>
              <Badge variant="info">Local Admin Role</Badge>
            </div>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: '12px',
              fontSize: '0.9rem',
              backgroundColor: '#f8fafc',
              padding: '16px',
              borderRadius: '8px',
              border: '1px solid var(--border-color)',
            }}
          >
            <div>
              <span style={{ color: 'var(--text-muted)' }}>Company:</span>
              <div>
                <strong>Horizone Energy</strong>
              </div>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)' }}>Application:</span>
              <div>Horizone StockFlow v1.0.0</div>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)' }}>Jurisdiction:</span>
              <div>Kerala State Electricity Board (KSEB)</div>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)' }}>Default Currency:</span>
              <div>Indian Rupee (INR ₹)</div>
            </div>
          </div>
        </div>
      </div>

      {/* Backend API Configuration & Connection Status */}
      <div className="card" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h2 className="card-title">Backend REST API Configuration</h2>
          <button
            type="button"
            className="btn btn-secondary btn-sm"
            onClick={testConnection}
            disabled={checkingHealth}
          >
            <RefreshCw size={14} className={checkingHealth ? 'animate-spin' : ''} /> Test Status
          </button>
        </div>
        <div className="card-body">
          <form onSubmit={handleSaveApiUrl}>
            <div className="form-group">
              <label className="form-label">API Base Endpoint URL</label>
              <div style={{ display: 'flex', gap: '10px' }}>
                <input
                  type="text"
                  required
                  className="form-input"
                  value={apiUrl}
                  onChange={(e) => setApiUrl(e.target.value)}
                />
                <button type="submit" className="btn btn-primary" style={{ whiteSpace: 'nowrap' }}>
                  Save Endpoint
                </button>
              </div>
              <div className="form-hint">
                Default: <code>http://localhost:5050/api/v1</code>. For production deployments,
                point this to your cloud API server URL.
              </div>
            </div>
          </form>

          {statusMsg && (
            <div
              className={`alert-banner ${
                healthStatus ? 'alert-info' : 'alert-danger'
              }`}
              style={{ marginTop: '16px', marginBottom: 0 }}
            >
              {healthStatus ? (
                <CheckCircle2 size={18} color="#10b981" />
              ) : (
                <AlertTriangle size={18} />
              )}
              <span>{statusMsg}</span>
            </div>
          )}

          {healthStatus && (
            <div
              style={{
                marginTop: '12px',
                padding: '12px',
                backgroundColor: '#f8fafc',
                borderRadius: '6px',
                fontSize: '0.82rem',
                fontFamily: 'monospace',
              }}
            >
              Service: {healthStatus.service} | Mode: {healthStatus.mode} | Version:{' '}
              {healthStatus.version} | Uptime: {healthStatus.uptimeSeconds}s
            </div>
          )}
        </div>
      </div>

      {/* Storage Architecture & Future Database Roadmap */}
      <div className="card" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h2 className="card-title">Synchronization & Persistence Strategy</h2>
        </div>
        <div className="card-body">
          <div className="alert-banner alert-warning" style={{ marginBottom: '16px' }}>
            <AlertTriangle size={20} />
            <div>
              <strong>Local Mode Notice:</strong> Data entered in this local web application or the
              mobile app (Hive storage) is not automatically shared in real time between separate
              unlinked devices until the shared database (PostgreSQL/MongoDB) is connected.
            </div>
          </div>

          <p style={{ fontSize: '0.9rem', color: 'var(--text-main)', marginBottom: '12px' }}>
            Horizone StockFlow is designed with repository abstractions to seamlessly upgrade from
            standalone offline storage to a shared multi-device cloud database.
          </p>

          <div
            style={{
              display: 'grid',
              gap: '10px',
              fontSize: '0.88rem',
              color: 'var(--text-muted)',
              marginBottom: '20px',
            }}
          >
            <div>• Phase 1 (Active): Mobile offline Hive persistence + Node.js API foundation.</div>
            <div>
              • Phase 2: PostgreSQL transactional database with atomic serial locks preventing
              concurrent sales.
            </div>
            <div>
              • Phase 3: Bi-directional synchronization protocol with offline conflict resolution.
            </div>
          </div>

          <button
            type="button"
            className="btn btn-secondary"
            onClick={handleExportData}
          >
            <Download size={16} /> Export All Stock & Customer Records (JSON)
          </button>
        </div>
      </div>
    </div>
  );
};

import React, { useState, useEffect } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  ShoppingCart,
  PackagePlus,
  Users,
  Boxes,
  Settings,
  Sun,
  LogOut,
} from 'lucide-react';
import { apiService } from '../services/apiService';
import { useAuth } from '../context/AuthContext';

export const Layout: React.FC = () => {
  const location = useLocation();
  const { logout, userEmail } = useAuth();
  const [isBackendHealthy, setIsBackendHealthy] = useState<boolean>(true);

  useEffect(() => {
    const checkStatus = async () => {
      try {
        await apiService.checkHealth();
        setIsBackendHealthy(true);
      } catch {
        setIsBackendHealthy(false);
      }
    };
    checkStatus();
    const interval = setInterval(checkStatus, 30000);
    return () => clearInterval(interval);
  }, []);

  const getPageTitle = () => {
    switch (location.pathname) {
      case '/':
        return 'StockFlow Executive Dashboard';
      case '/sales':
        return 'Sales & Dispatch Transactions';
      case '/purchases':
        return 'Panel Purchases & Inward Batches';
      case '/customers':
        return 'KSEB Customers Management';
      case '/inventory':
        return 'Physical Panel Inventory Report';
      case '/settings':
        return 'Profile & System Settings';
      default:
        return 'Horizone StockFlow';
    }
  };

  return (
    <div className="app-container">
      {/* Sidebar Navigation */}
      <aside className="sidebar">
        <div className="sidebar-header">
          <img
            src="/branding/logo.png"
            alt="Horizone Energy Logo"
            className="brand-logo-img"
            onError={(e) => {
              (e.target as HTMLElement).style.display = 'none';
            }}
          />
          <div className="sidebar-brand-text">
            <div className="sidebar-brand-title">StockFlow</div>
            <div className="sidebar-brand-subtitle">Horizone Energy</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          <NavLink
            to="/"
            end
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            <LayoutDashboard size={19} />
            <span className="nav-text">Dashboard</span>
          </NavLink>

          <NavLink
            to="/sales"
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            <ShoppingCart size={19} />
            <span className="nav-text">Sales & Outward</span>
          </NavLink>

          <NavLink
            to="/purchases"
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            <PackagePlus size={19} />
            <span className="nav-text">Purchases & Inward</span>
          </NavLink>

          <NavLink
            to="/customers"
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            <Users size={19} />
            <span className="nav-text">Customers (KSEB)</span>
          </NavLink>

          <NavLink
            to="/inventory"
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            <Boxes size={19} />
            <span className="nav-text">Panel Inventory</span>
          </NavLink>

          <NavLink
            to="/settings"
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            <Settings size={19} />
            <span className="nav-text">Profile & Settings</span>
          </NavLink>
        </nav>

        <div className="sidebar-footer">
          <div className="system-status-indicator">
            <span className={`status-dot ${isBackendHealthy ? '' : 'offline'}`} />
            <span>
              {isBackendHealthy ? 'API Connected' : 'API Standby / Reconnecting'}
            </span>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="main-wrapper">
        <header className="top-header">
          <div className="header-title-container">
            <h1>{getPageTitle()}</h1>
          </div>

          <div className="header-actions">
            <NavLink to="/settings" className="header-user-badge" title={userEmail || 'user@gmail.com'}>
              <div className="user-avatar-circle">
                <Sun size={14} />
              </div>
              <span>Stock Manager</span>
            </NavLink>
            <button
              onClick={logout}
              className="btn-danger-light"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                padding: '7px 12px',
                borderRadius: '8px',
                fontSize: '12px',
                fontWeight: 600,
                cursor: 'pointer',
                border: '1px solid #fecaca',
                backgroundColor: '#fef2f2',
                color: '#b91c1c',
              }}
              title="Sign Out"
            >
              <LogOut size={14} />
              <span>Sign Out</span>
            </button>
          </div>
        </header>

        <main className="content-body">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

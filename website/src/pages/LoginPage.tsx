import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Lock, Mail, AlertCircle, Key, ArrowRight, ShieldCheck, Sun } from 'lucide-react';

export const LoginPage: React.FC = () => {
  const navigate = useNavigate();
  const { login } = useAuth();

  const [email, setEmail] = useState('user@gmail.com');
  const [password, setPassword] = useState('user123');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      const result = await login(email, password);
      if (result.success) {
        navigate('/', { replace: true });
      } else {
        setError(result.error || 'Authentication failed');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleAutofill = () => {
    setEmail('user@gmail.com');
    setPassword('user123');
    setError(null);
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: '#f8fafc',
      padding: '24px',
      fontFamily: 'Inter, system-ui, -apple-system, sans-serif'
    }}>
      <div style={{
        width: '100%',
        maxWidth: '440px',
        backgroundColor: '#ffffff',
        borderRadius: '16px',
        boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.05)',
        border: '1px solid #e2e8f0',
        padding: '36px 32px'
      }}>
        {/* Horizone Energy Logo & Title */}
        <div style={{ textAlign: 'center', marginBottom: '28px' }}>
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '14px' }}>
            <img
              src="/branding/logo.png"
              alt="Horizone Energy"
              style={{ maxHeight: '68px', objectFit: 'contain' }}
              onError={(e) => {
                // Fallback icon
                (e.target as HTMLElement).style.display = 'none';
              }}
            />
          </div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', backgroundColor: '#e0f2fe', padding: '4px 10px', borderRadius: '9999px', marginBottom: '10px' }}>
            <Sun size={14} color="#0284c7" />
            <span style={{ fontSize: '11px', fontWeight: 700, color: '#0369a1', letterSpacing: '0.5px', textTransform: 'uppercase' }}>
              Horizone Energy StockFlow
            </span>
          </div>
          <h1 style={{ fontSize: '22px', fontWeight: 800, color: '#0f172a', margin: '0 0 6px 0' }}>
            Sign in to StockFlow
          </h1>
          <p style={{ fontSize: '13px', color: '#64748b', margin: 0 }}>
            Solar inventory dispatch and customer management portal
          </p>
        </div>

        {/* Error notification */}
        {error && (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            backgroundColor: '#fef2f2',
            border: '1px solid #fecaca',
            color: '#b91c1c',
            padding: '12px 14px',
            borderRadius: '8px',
            fontSize: '13px',
            fontWeight: 500,
            marginBottom: '20px'
          }}>
            <AlertCircle size={18} style={{ flexShrink: 0 }} />
            <span>{error}</span>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '18px' }}>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
              Stock Manager Email
            </label>
            <div style={{ position: 'relative' }}>
              <div style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}>
                <Mail size={18} />
              </div>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="user@gmail.com"
                style={{
                  width: '100%',
                  padding: '10px 14px 10px 40px',
                  borderRadius: '8px',
                  border: '1px solid #cbd5e1',
                  fontSize: '14px',
                  outline: 'none',
                  boxSizing: 'border-box'
                }}
              />
            </div>
          </div>

          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
              Password
            </label>
            <div style={{ position: 'relative' }}>
              <div style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}>
                <Lock size={18} />
              </div>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="user123"
                style={{
                  width: '100%',
                  padding: '10px 14px 10px 40px',
                  borderRadius: '8px',
                  border: '1px solid #cbd5e1',
                  fontSize: '14px',
                  outline: 'none',
                  boxSizing: 'border-box'
                }}
              />
            </div>
          </div>

          {/* Quick Credential Hint Chip */}
          <div style={{
            backgroundColor: '#f0fdf4',
            border: '1px solid #bbf7d0',
            borderRadius: '8px',
            padding: '10px 12px',
            marginBottom: '22px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '4px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Key size={14} color="#15803d" />
                <span style={{ fontSize: '11px', fontWeight: 700, color: '#166534' }}>
                  Demo Stock Manager Account
                </span>
              </div>
              <button
                type="button"
                onClick={handleAutofill}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#15803d',
                  fontSize: '11px',
                  fontWeight: 700,
                  cursor: 'pointer',
                  textDecoration: 'underline',
                  padding: 0
                }}
              >
                Autofill
              </button>
            </div>
            <div style={{ fontSize: '11px', fontFamily: 'monospace', color: '#334155' }}>
              user@gmail.com / user123
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            style={{
              width: '100%',
              backgroundColor: '#0284c7',
              color: '#ffffff',
              border: 'none',
              borderRadius: '8px',
              padding: '12px 16px',
              fontSize: '14px',
              fontWeight: 700,
              cursor: isLoading ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              transition: 'background-color 0.2s',
              opacity: isLoading ? 0.7 : 1
            }}
          >
            {isLoading ? 'Signing In...' : 'Sign In to Portal'}
            <ArrowRight size={16} />
          </button>
        </form>

        <div style={{
          marginTop: '28px',
          paddingTop: '20px',
          borderTop: '1px solid #f1f5f9',
          textAlign: 'center'
        }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#94a3b8', fontSize: '11px' }}>
            <ShieldCheck size={14} />
            <span>Horizone Energy Authorized Access Only</span>
          </div>
        </div>
      </div>
    </div>
  );
};

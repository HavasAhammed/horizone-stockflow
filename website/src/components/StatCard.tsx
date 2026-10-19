import React from 'react';

interface StatCardProps {
  label: string;
  value: string | number;
  amount?: string;
  subtext?: string;
  icon: React.ReactNode;
  iconBg?: string;
}

export const StatCard: React.FC<StatCardProps> = ({
  label,
  value,
  amount,
  subtext,
  icon,
  iconBg = '#eff6ff',
}) => {
  return (
    <div className="stat-card">
      <div className="stat-header">
        <span className="stat-label">{label}</span>
        <div className="stat-icon-wrapper" style={{ backgroundColor: iconBg }}>
          {icon}
        </div>
      </div>
      <div className="stat-value">{value}</div>
      {amount && (
        <div
          style={{
            fontSize: '0.85rem',
            fontWeight: 700,
            marginTop: '4px',
            marginBottom: '2px',
          }}
        >
          {amount}
        </div>
      )}
      {subtext && <div className="stat-subtext">{subtext}</div>}
    </div>
  );
};

import React from 'react';

interface StatCardProps {
  label: string;
  value: string | number;
  subtext?: string;
  icon: React.ReactNode;
  iconBg?: string;
}

export const StatCard: React.FC<StatCardProps> = ({
  label,
  value,
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
      {subtext && <div className="stat-subtext">{subtext}</div>}
    </div>
  );
};

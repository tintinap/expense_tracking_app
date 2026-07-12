'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';

const navItems = [
  { label: 'Dashboard', href: '/dashboard', icon: '🏠' },
  { label: 'Transactions', href: '/transactions', icon: '🧾' },
  { label: 'Wallets', href: '/wallets', icon: '👛' },
  { label: 'Reports', href: '/reports', icon: '📊' },
  { label: 'Budgets', href: '/budgets', icon: '🎯' },
  { label: 'Import', href: '/import', icon: '📥' },
  { label: 'Settings', href: '/settings', icon: '⚙️' },
];

export function Sidebar({ locale }: { locale: string }) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <aside
      className={`sidebar ${collapsed ? 'sidebar--collapsed' : ''}`}
      data-testid="main-sidebar"
    >
      <div className="sidebar__header">
        <h1 className="sidebar__logo">
          {collapsed ? 'DS' : 'DailySpend'}
        </h1>
        <button
          className="sidebar__toggle"
          onClick={() => setCollapsed(!collapsed)}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? '→' : '←'}
        </button>
      </div>

      <nav className="sidebar__nav">
        {navItems.map((item) => {
          const fullPath = `/${locale}${item.href}`;
          const isActive = pathname?.startsWith(fullPath);

          return (
            <Link
              key={item.href}
              href={fullPath}
              className={`sidebar__link ${isActive ? 'sidebar__link--active' : ''}`}
            >
              <span className="sidebar__icon">{item.icon}</span>
              {!collapsed && <span className="sidebar__label">{item.label}</span>}
            </Link>
          );
        })}
      </nav>

      <div className="sidebar__footer">
        {!collapsed && (
          <p className="sidebar__version">v1.0.0</p>
        )}
      </div>
    </aside>
  );
}

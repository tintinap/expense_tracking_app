'use client';

import { useEffect, useMemo, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { syncApi } from '@/lib/api-client';
import { useAuth } from '@/lib/auth/AuthContext';

export default function WalletsPage() {
  const { token } = useAuth();
  const [rows, setRows] = useState<Array<{ currency: string; balance: number }>>([]);

  useEffect(() => {
    if (!token) return;
    const load = async () => {
      const pull = await syncApi.pull(token, new Date(0).toISOString());
      const map = new Map<string, number>();
      for (const tx of pull.transactions || []) {
        const cur = tx.originalCurrency;
        if (!cur) continue;
        const prev = map.get(cur) ?? 0;
        const amount = Number(tx.originalAmount ?? 0);
        const delta = tx.transactionType === 'currency_income' || tx.transactionType === 'currency_exchange_in'
          ? amount
          : tx.transactionType === 'expense' || tx.transactionType === 'currency_exchange_out'
            ? -amount
            : 0;
        map.set(cur, prev + delta);
      }
      setRows(Array.from(map.entries()).map(([currency, balance]) => ({ currency, balance })));
    };
    load();
  }, [token]);

  const total = useMemo(() => rows.reduce((sum, row) => sum + row.balance, 0), [rows]);

  return (
    <ProtectedRoute>
      <div className="page">
        <header className="page__header">
          <h1 className="page__title">Currency Wallets</h1>
          <p className="page__subtitle">Track your balances across currencies</p>
        </header>
        <div className="page__content space-y-4">
          <section className="card">
            <h2 className="card__label">Total Portfolio Value</h2>
            <p className="card__value card__value--large">{total.toFixed(2)} (approx)</p>
          </section>
          {rows.length === 0 ? (
            <p className="card__empty">No currency balances yet. Add a currency income to get started.</p>
          ) : (
            rows.map((row) => (
              <section key={row.currency} className="card">
                <h3 className="card__label">{row.currency}</h3>
                <p className="card__value">{row.balance.toFixed(2)}</p>
              </section>
            ))
          )}
        </div>
      </div>
    </ProtectedRoute>
  );
}

'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useEffect, useMemo, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { transactionsApi } from '@/lib/api-client';
import { useAuth } from '@/lib/auth/AuthContext';

export default function ReportsPage() {
  const { token } = useAuth();
  const [transactions, setTransactions] = useState<any[]>([]);

  useEffect(() => {
    if (!token) return;
    transactionsApi.list(token).then((res) => setTransactions((res.data ?? []) as any[]));
  }, [token]);

  const totalExpense = useMemo(
    () =>
      transactions
        .filter((tx) => tx.transactionType === 'expense')
        .reduce((sum, tx) => sum + Number(tx.amountBase ?? 0), 0),
    [transactions],
  );

  return (
    <ProtectedRoute>
      <div className="page">
        <header className="page__header">
          <h1 className="page__title">Reports</h1>
          <p className="page__subtitle">Visualise your spending with charts and trends</p>
        </header>
        <div className="page__content space-y-3">
          {transactions.length === 0 ? (
            <p className="card__empty">Reports will appear once you have transactions.</p>
          ) : (
            <>
              <section className="card">
                <h2 className="card__label">Total Spending (base)</h2>
                <p className="card__value">{totalExpense.toFixed(2)}</p>
              </section>
              <section className="card">
                <h2 className="card__label">Transactions in period</h2>
                <p className="card__value">{transactions.length}</p>
              </section>
            </>
          )}
        </div>
      </div>
    </ProtectedRoute>
  );
}

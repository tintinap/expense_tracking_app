'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { budgetsApi } from '@/lib/api-client';
import { useAuth } from '@/lib/auth/AuthContext';

export default function BudgetsPage() {
  const { token } = useAuth();
  const [budgets, setBudgets] = useState<any[]>([]);

  useEffect(() => {
    if (!token) return;
    budgetsApi.list(token).then((data) => setBudgets(data as any[]));
  }, [token]);

  return (
    <ProtectedRoute>
      <div className="page">
        <header className="page__header">
          <h1 className="page__title">Budgets</h1>
          <p className="page__subtitle">Set spending limits and monitor progress</p>
        </header>
        <div className="page__content space-y-3">
          {budgets.length === 0 ? (
            <p className="card__empty">No budgets configured yet. Create your first budget to start tracking.</p>
          ) : (
            budgets.map((budget) => (
              <section key={budget.id} className="card">
                <h3 className="card__label">{budget.name ?? 'Budget'}</h3>
                <p className="card__value">{budget.currency} {Number(budget.amountBase ?? 0).toFixed(2)}</p>
                <p className="page__subtitle">Period: {budget.periodType}</p>
              </section>
            ))
          )}
        </div>
      </div>
    </ProtectedRoute>
  );
}

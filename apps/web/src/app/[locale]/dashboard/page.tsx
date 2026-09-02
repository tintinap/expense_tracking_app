'use client';

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { transactionsApi } from '@/lib/api-client';
import { useAuth } from '@/lib/auth/AuthContext';

type DashboardTransaction = {
  id: string;
  transactionType: string;
  amountBase: number;
  originalAmount: number;
  originalCurrency: string;
  transactionDate: string;
  note?: string | null;
  category?: { id: string; name: string } | null;
};

type DashboardSummary = {
  totalSpent: number;
  netIncome: number;
  topCategory: string;
  topCategoryAmount: number;
};

function formatMoney(value: number, currency = 'AUD') {
  return new Intl.NumberFormat('en-AU', {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(value);
}

function asNumber(value: unknown) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function buildSummary(data: DashboardTransaction[]): DashboardSummary {
  const expenseTotal = data
    .filter((tx) => tx.transactionType === 'expense')
    .reduce((sum, tx) => sum + asNumber(tx.amountBase), 0);
  const incomeTotal = data
    .filter((tx) => tx.transactionType === 'currency_income')
    .reduce((sum, tx) => sum + asNumber(tx.amountBase), 0);

  const categoryTotals = data
    .filter((tx) => tx.transactionType === 'expense')
    .reduce<Record<string, number>>((acc, tx) => {
      const category = tx.category?.name || 'Uncategorized';
      acc[category] = (acc[category] || 0) + asNumber(tx.amountBase);
      return acc;
    }, {});

  const sortedCategory = Object.entries(categoryTotals).sort((a, b) => b[1] - a[1])[0];

  return {
    totalSpent: expenseTotal,
    netIncome: incomeTotal - expenseTotal,
    topCategory: sortedCategory?.[0] || 'No expenses yet',
    topCategoryAmount: sortedCategory?.[1] || 0,
  };
}

export default function DashboardPage() {
  const { token } = useAuth();
  const [transactions, setTransactions] = useState<DashboardTransaction[]>([]);
  const [summary, setSummary] = useState<DashboardSummary>({
    totalSpent: 0,
    netIncome: 0,
    topCategory: 'No expenses yet',
    topCategoryAmount: 0,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      setTransactions([]);
      setSummary({
        totalSpent: 0,
        netIncome: 0,
        topCategory: 'No expenses yet',
        topCategoryAmount: 0,
      });
      setIsLoading(false);
      return;
    }

    const loadDashboard = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const result = await transactionsApi.list(token, { page: 1, limit: 50 });
        const nextTransactions = (result.data || []) as DashboardTransaction[];
        setTransactions(nextTransactions);
        setSummary(buildSummary(nextTransactions));
      } catch (err) {
        console.error('Failed to load dashboard transactions', err);
        setError('Unable to load dashboard data from API.');
      } finally {
        setIsLoading(false);
      }
    };

    void loadDashboard();
  }, [token]);

  return (
    <ProtectedRoute>
      <div className="mx-auto max-w-5xl space-y-5 px-4 py-6 sm:px-6 sm:py-8">
        <header className="mb-2 flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
            <p className="text-gray-500">Card-first financial snapshot from your live transactions</p>
          </div>
        </header>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <section className="rounded-2xl border border-blue-100 bg-blue-50 p-5 shadow-sm">
            <p className="text-sm font-medium text-blue-700">Total Spent</p>
            <p className="mt-2 text-2xl font-bold text-blue-950">{formatMoney(summary.totalSpent)}</p>
            <p className="mt-2 text-xs text-blue-700">{transactions.length} transactions (latest 50)</p>
          </section>

          <section className="rounded-2xl border border-emerald-100 bg-emerald-50 p-5 shadow-sm">
            <p className="text-sm font-medium text-emerald-700">Net Income</p>
            <p className="mt-2 text-2xl font-bold text-emerald-950">{formatMoney(summary.netIncome)}</p>
            <p className="mt-2 text-xs text-emerald-700">Income minus expense in base currency</p>
          </section>

          <section className="rounded-2xl border border-violet-100 bg-violet-50 p-5 shadow-sm sm:col-span-2">
            <p className="text-sm font-medium text-violet-700">Top Category</p>
            <p className="mt-2 text-2xl font-bold text-violet-950">{summary.topCategory}</p>
            <p className="mt-2 text-xs text-violet-700">{formatMoney(summary.topCategoryAmount)} spent</p>
          </section>
        </div>

        <section className="rounded-2xl border border-gray-200 bg-white shadow-sm">
          <div className="border-b border-gray-100 px-5 py-4">
            <h2 className="font-semibold text-gray-900">Recent Transactions</h2>
          </div>

          {isLoading && (
            <div className="space-y-3 px-5 py-4">
              {[0, 1, 2].map((item) => (
                <div key={item} className="h-14 animate-pulse rounded-xl bg-gray-100" />
              ))}
            </div>
          )}

          {!isLoading && error && (
            <div className="px-5 py-8 text-center text-sm text-red-600">{error}</div>
          )}

          {!isLoading && !error && transactions.length === 0 && (
            <div className="px-5 py-8 text-center text-sm text-gray-500">
              No transactions yet. Add your first expense to populate the dashboard.
            </div>
          )}

          {!isLoading && !error && transactions.length > 0 && (
            <div className="divide-y divide-gray-100">
              {transactions.slice(0, 8).map((tx) => {
                const isIncome = tx.transactionType === 'currency_income';
                const amount = asNumber(tx.originalAmount) || asNumber(tx.amountBase);

                return (
                  <div key={tx.id} className="flex items-center justify-between px-5 py-4 transition-colors hover:bg-gray-50">
                    <div className="min-w-0">
                      <p className="truncate font-medium text-gray-900">
                        {tx.category?.name || 'Uncategorized'}
                      </p>
                      <p className="text-xs text-gray-500">
                        {new Date(tx.transactionDate).toLocaleDateString('en-AU')} - {tx.note || tx.transactionType}
                      </p>
                    </div>
                    <p className={`ml-4 shrink-0 text-sm font-semibold ${isIncome ? 'text-emerald-700' : 'text-gray-900'}`}>
                      {isIncome ? '+' : '-'}
                      {formatMoney(amount, tx.originalCurrency || 'AUD')}
                    </p>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      </div>
    </ProtectedRoute>
  );
}

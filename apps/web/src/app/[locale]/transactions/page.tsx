'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import ExpenseModal from '@/components/ExpenseModal';
import { categoriesApi, transactionsApi } from '@/lib/api-client';
import { useAuth } from '@/lib/auth/AuthContext';

export default function TransactionsPage() {
  const { token } = useAuth();
  const [transactions, setTransactions] = useState([]);
  const [categories, setCategories] = useState<Array<{ id: string; name: string }>>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingTx, setEditingTx] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token) return;
    const load = async () => {
      setLoading(true);
      try {
        const [txRes, catRes] = await Promise.all([
          transactionsApi.list(token),
          categoriesApi.list(token),
        ]);
        setTransactions(txRes.data as any);
        setCategories((catRes as any[]).map((c) => ({ id: c.id, name: c.name })));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [token]);

  const handleSubmit = async (payload: any) => {
    if (!token) return;
    if (editingTx?.id) {
      await transactionsApi.update(token, editingTx.id, payload);
    } else {
      await transactionsApi.create(token, payload);
    }
    const txRes = await transactionsApi.list(token);
    setTransactions(txRes.data as any);
    setEditingTx(null);
  };

  const handleDelete = async (id: string) => {
    if (!token) return;
    await transactionsApi.delete(token, id);
    setTransactions((prev: any) => prev.filter((tx: any) => tx.id !== id));
  };

  return (
    <ProtectedRoute>
      <div className="p-8 max-w-6xl mx-auto">
        <header className="mb-8 flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Transactions</h1>
            <p className="text-gray-500">Manage your raw data and edits</p>
          </div>
          <button 
            onClick={() => { setEditingTx(null); setIsModalOpen(true); }}
            className="px-4 py-2 bg-indigo-600 text-white rounded-md font-medium shadow-sm hover:bg-indigo-700 transition"
          >
            + Add Expense
          </button>
        </header>

        <div className="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-200 text-sm">
                  <th className="p-4 font-semibold text-gray-600">Date</th>
                  <th className="p-4 font-semibold text-gray-600">Type</th>
                  <th className="p-4 font-semibold text-gray-600">Category</th>
                  <th className="p-4 font-semibold text-gray-600">Amount</th>
                  <th className="p-4 font-semibold text-gray-600">Note</th>
                  <th className="p-4 font-semibold text-gray-600 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {loading && (
                  <tr>
                    <td className="p-4 text-sm text-gray-500" colSpan={6}>Loading transactions...</td>
                  </tr>
                )}
                {transactions.map((tx: any) => (
                  <tr key={tx.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="p-4 text-sm text-gray-600">{new Date(tx.transactionDate ?? tx.date).toLocaleDateString()}</td>
                    <td className="p-4">
                      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${tx.transactionType === 'currency_income' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                        {tx.transactionType}
                      </span>
                    </td>
                    <td className="p-4 text-sm text-gray-900 font-medium">{tx.category?.name ?? '-'}</td>
                    <td className="p-4 text-sm font-semibold">
                      {Number(tx.originalAmount ?? 0).toFixed(2)} <span className="text-gray-500 font-normal">{tx.originalCurrency}</span>
                    </td>
                    <td className="p-4 text-sm text-gray-500 max-w-[200px] truncate">{tx.note || '-'}</td>
                    <td className="p-4 text-right">
                      <button 
                        onClick={() => { setEditingTx(tx); setIsModalOpen(true); }}
                        className="text-sm text-indigo-600 hover:text-indigo-800 font-medium"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(tx.id)}
                        className="ml-3 text-sm text-red-600 hover:text-red-800 font-medium"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {transactions.length === 0 && (
            <div className="p-8 text-center text-gray-500">No transactions found.</div>
          )}
        </div>
      </div>
      <ExpenseModal 
        isOpen={isModalOpen} 
        onClose={() => { setIsModalOpen(false); setEditingTx(null); }} 
        initialData={editingTx} 
        categories={categories}
        onSubmit={handleSubmit}
      />
    </ProtectedRoute>
  );
}

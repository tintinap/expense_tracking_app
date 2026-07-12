/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable react-hooks/set-state-in-effect */
import { useEffect, useState } from 'react';

type Props = {
  isOpen: boolean;
  onClose: () => void;
  initialData?: any;
  categories?: Array<{ id: string; name: string }>;
  onSubmit: (payload: {
    transactionType: string;
    originalAmount: number;
    originalCurrency: string;
    transactionDate: string;
    note?: string;
    categoryId?: string | null;
  }) => Promise<void>;
};

export default function ExpenseModal({ isOpen, onClose, initialData, categories = [], onSubmit }: Props) {
  const [formData, setFormData] = useState(initialData || {
    type: 'expense',
    amount: '',
    currency: 'AUD',
    categoryId: '',
    date: new Date().toISOString().split('T')[0],
    note: ''
  });

  useEffect(() => {
    setFormData(
      initialData || {
        type: 'expense',
        amount: '',
        currency: 'AUD',
        categoryId: '',
        date: new Date().toISOString().split('T')[0],
        note: '',
      },
    );
  }, [initialData, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: any) => {
    e.preventDefault();
    const transactionType = formData.type === 'income' ? 'currency_income' : 'expense';
    await onSubmit({
      transactionType,
      originalAmount: Number(formData.amount || 0),
      originalCurrency: formData.currency,
      transactionDate: new Date(formData.date).toISOString(),
      note: formData.note || undefined,
      categoryId: formData.type === 'exchange' ? null : formData.categoryId || null,
    });
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-md overflow-hidden flex flex-col">
        <div className="px-6 py-4 border-b border-gray-100 flex justify-between items-center">
          <h2 className="text-xl font-bold">{initialData ? 'Edit Transaction' : 'Add Transaction'}</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">✕</button>
        </div>
        
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div className="flex gap-2 p-1 bg-gray-100 rounded-lg">
            <button
              type="button"
              className={`flex-1 py-1.5 text-sm font-medium rounded-md ${formData.type === 'expense' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
              onClick={() => setFormData({ ...formData, type: 'expense' })}
            >
              Expense
            </button>
            <button
              type="button"
              className={`flex-1 py-1.5 text-sm font-medium rounded-md ${formData.type === 'income' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
              onClick={() => setFormData({ ...formData, type: 'income' })}
            >
              Income
            </button>
            <button
              type="button"
              className={`flex-1 py-1.5 text-sm font-medium rounded-md ${formData.type === 'exchange' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
              onClick={() => setFormData({ ...formData, type: 'exchange' })}
            >
              Exchange
            </button>
          </div>

          <div className="flex gap-4">
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount</label>
              <input 
                type="number" 
                step="0.01" 
                required 
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500" 
                value={formData.amount} 
                onChange={e => setFormData({ ...formData, amount: e.target.value })} 
                placeholder="0.00" 
              />
            </div>
            <div className="w-1/3">
              <label className="block text-sm font-medium text-gray-700 mb-1">Currency</label>
              <select 
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
                value={formData.currency}
                onChange={e => setFormData({ ...formData, currency: e.target.value })}
              >
                <option value="AUD">AUD</option>
                <option value="USD">USD</option>
                <option value="EUR">EUR</option>
                <option value="THB">THB</option>
              </select>
            </div>
          </div>

          {formData.type !== 'exchange' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
              <select 
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
                value={formData.categoryId}
                onChange={e => setFormData({ ...formData, categoryId: e.target.value })}
              >
                <option value="">Select a category</option>
                {categories.map((category) => (
                  <option key={category.id} value={category.id}>{category.name}</option>
                ))}
              </select>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Date</label>
            <input 
              type="date" 
              required 
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
              value={formData.date}
              onChange={e => setFormData({ ...formData, date: e.target.value })}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Note (Optional)</label>
            <input 
              type="text" 
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
              value={formData.note}
              onChange={e => setFormData({ ...formData, note: e.target.value })}
              placeholder="What was this for?"
            />
          </div>

          <div className="pt-4 flex gap-3">
            <button type="button" onClick={onClose} className="flex-1 py-2 px-4 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 font-medium">Cancel</button>
            <button type="submit" className="flex-1 py-2 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 font-medium tracking-wide">Save</button>
          </div>
        </form>
      </div>
    </div>
  );
}

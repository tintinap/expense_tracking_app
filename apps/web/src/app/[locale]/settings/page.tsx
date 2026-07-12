'use client';

import { useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/lib/auth/AuthContext';
import { request } from '@/lib/web-request';

export default function SettingsPage() {
  const { logout } = useAuth();
  const [isSheetsEnabled, setIsSheetsEnabled] = useState(false);
  const [isExporting, setIsExporting] = useState(false);
  const [baseCurrency, setBaseCurrency] = useState('AUD');

  const handleExport = async () => {
    setIsExporting(true);
    try {
      await request('/export/excel');
      setIsExporting(false);
      alert('Export request submitted.');
    } catch {
      setIsExporting(false);
      alert('Export failed.');
    }
  };

  const handleSheetsToggle = () => {
    if (!isSheetsEnabled) {
      await request('/sheets/setup', { method: 'POST' });
      setIsSheetsEnabled(true);
      return;
    }
    await request('/sheets/disconnect', { method: 'DELETE' });
    setIsSheetsEnabled(false);
  };

  return (
    <ProtectedRoute>
      <div className="p-8 max-w-4xl mx-auto space-y-8">
        <header>
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">Settings</h1>
          <p className="text-gray-500">Manage your account, integrations, and preferences.</p>
        </header>

        <section className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">Account</h2>
          </div>
          <div className="p-6">
            <p className="text-sm text-gray-600 mb-4">You are securely signed in.</p>
            <button
              onClick={logout}
              className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Sign out
            </button>
          </div>
        </section>

        <section className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">Preferences</h2>
          </div>
          <div className="p-6 space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-medium text-gray-900">Base Currency</h3>
                <p className="text-sm text-gray-500 mt-1">Default currency for aggregated balances and reports.</p>
              </div>
              <select
                className="px-3 py-2 border border-gray-300 bg-white rounded-md text-sm font-medium text-gray-700 focus:ring-indigo-500 focus:border-indigo-500"
                value={baseCurrency}
                onChange={(e) => setBaseCurrency(e.target.value)}
              >
                <option value="AUD">AUD ($)</option>
                <option value="USD">USD ($)</option>
                <option value="EUR">EUR (€)</option>
                <option value="THB">THB (฿)</option>
              </select>
            </div>
            
            <div className="flex items-center justify-between pt-6 border-t border-gray-50">
              <div>
                <h3 className="font-medium text-gray-900">Theme</h3>
                <p className="text-sm text-gray-500 mt-1">Select your preferred user interface flavor.</p>
              </div>
              <select className="px-3 py-2 border border-gray-300 bg-white rounded-md text-sm font-medium text-gray-700 focus:ring-indigo-500 focus:border-indigo-500">
                <option value="system">System Default</option>
                <option value="light">Light</option>
                <option value="dark">Dark</option>
              </select>
            </div>
          </div>
        </section>

        <section className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">Integrations</h2>
          </div>
          <div className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-medium text-gray-900">Google Sheets Sync</h3>
                <p className="text-sm text-gray-500 mt-1">Automatically push transactions to a dedicated Google Sheet.</p>
              </div>
              <button
                onClick={handleSheetsToggle}
                className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${isSheetsEnabled ? 'bg-indigo-600' : 'bg-gray-200'}`}
              >
                <span className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${isSheetsEnabled ? 'translate-x-5' : 'translate-x-0'}`} />
              </button>
            </div>
            {isSheetsEnabled && (
              <div className="mt-4 p-4 bg-green-50 border border-green-100 rounded-md">
                <a href="#" className="text-sm text-green-800 font-medium hover:underline">View your Spreadsheet →</a>
              </div>
            )}
          </div>
        </section>

        <section className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">Data & Export</h2>
          </div>
          <div className="p-6 space-y-4">
            <p className="text-sm text-gray-600">Export all your transactions and structural configurations in a neat Excel format.</p>
            <button
              onClick={handleExport}
              disabled={isExporting}
              className="px-4 py-2 bg-indigo-600 border border-transparent rounded-md shadow-sm text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50 transition-colors"
            >
              {isExporting ? 'Generating...' : 'Export as Excel (.xlsx)'}
            </button>
          </div>
        </section>
      </div>
    </ProtectedRoute>
  );
}

'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { read, utils } from 'xlsx';
import { Upload, FileSpreadsheet, AlertCircle, CheckCircle, Trash2 } from 'lucide-react';
import { v4 as uuidv4 } from 'uuid';
import ProtectedRoute from '@/components/ProtectedRoute';

export default function ImportPage() {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [success, setSuccess] = useState(false);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    setError(null);
    setSuccess(false);
    
    if (acceptedFiles.length === 0) return;
    
    const selected = acceptedFiles[0];
    if (!selected.name.endsWith('.xlsx') && !selected.name.endsWith('.csv')) {
      setError('Please upload an Excel (.xlsx) or CSV file');
      return;
    }
    
    setFile(selected);
    
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = e.target?.result;
        const workbook = read(data, { type: 'binary' });
        const sheetName = workbook.SheetNames[0];
        const sheet = workbook.Sheets[sheetName];
        const json = utils.sheet_to_json(sheet);
        
        if (json.length === 0) {
          setError('File is empty');
          return;
        }
        
        // Basic mapping for preview
        const mapped = json.map((row: any) => ({
          id: uuidv4(),
          date: row.Date || row.date || new Date().toISOString().split('T')[0],
          amount: parseFloat(row.Amount || row.amount || '0'),
          currency: row.Currency || row.currency || 'USD',
          note: row.Note || row.note || row.Description || row.description || '',
          category: row.Category || row.category || '',
          type: row.Type || row.type || (parseFloat(row.Amount || '0') < 0 ? 'expense' : 'income')
        }));
        
        setPreview(mapped);
      } catch {
        setError('Failed to parse file. Make sure it has Date, Amount, Currency, Note columns.');
      }
    };
    reader.readAsBinaryString(selected);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
      'text/csv': ['.csv']
    },
    maxFiles: 1
  });

  const handleUpload = async () => {
    if (preview.length === 0) return;
    
    setIsUploading(true);
    setError(null);
    
    try {
      // Clean up for API
      const payload = preview.map(item => {
        const isIncome = item.amount > 0 || item.type?.toLowerCase() === 'income';
        const type = isIncome ? 'currency_income' : 'expense';
        
        return {
          id: item.id,
          transactionType: type,
          originalAmount: Math.abs(item.amount),
          originalCurrency: item.currency,
          amountBase: Math.abs(item.amount), // Server should recalculate
          exchangeRate: 1.0,
          transactionDate: new Date(item.date).toISOString(),
          note: item.note,
          categoryId: null // We'd need to map string to ID, but keeping simple for now
        };
      });
      
      const token = localStorage.getItem('accessToken') || localStorage.getItem('jwt_access_token');
      if (!token) throw new Error('You must be logged in to import');

      const res = await fetch(process.env.NEXT_PUBLIC_API_URL + '/import/transactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ transactions: payload })
      });
      
      if (!res.ok) {
        throw new Error('Server returned ' + res.status);
      }
      
      setSuccess(true);
      setFile(null);
      setPreview([]);
    } catch (err: any) {
      setError(err.message || 'Failed to upload');
    } finally {
      setIsUploading(false);
    }
  };

  const removeRow = (index: number) => {
    const newPreview = [...preview];
    newPreview.splice(index, 1);
    setPreview(newPreview);
    if (newPreview.length === 0) {
      setFile(null);
    }
  };

  return (
    <ProtectedRoute>
    <div className="max-w-5xl mx-auto p-6 space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Import Data</h1>
        <p className="text-gray-500 mt-2">Upload an Excel or CSV file to import your transactions.</p>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded-lg flex items-center gap-3">
          <AlertCircle size={20} />
          <p>{error}</p>
        </div>
      )}

      {success && (
        <div className="bg-green-50 border border-green-200 text-green-700 p-4 rounded-lg flex items-center gap-3">
          <CheckCircle size={20} />
          <p>Successfully imported transactions!</p>
        </div>
      )}

      {!file ? (
        <div 
          {...getRootProps()} 
          className={`border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition-colors
            ${isDragActive ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}`}
        >
          <input {...getInputProps()} />
          <Upload className="mx-auto h-12 w-12 text-gray-400 mb-4" />
          <p className="text-lg font-medium">Drag & drop your file here</p>
          <p className="text-sm text-gray-500 mt-1">or click to select file</p>
          <p className="text-xs text-gray-400 mt-4">Supports .xlsx and .csv</p>
        </div>
      ) : (
        <div className="space-y-6">
          <div className="flex items-center justify-between bg-white p-4 rounded-lg border shadow-sm">
            <div className="flex items-center gap-3">
              <FileSpreadsheet className="text-green-600" />
              <div>
                <p className="font-medium">{file.name}</p>
                <p className="text-xs text-gray-500">{preview.length} rows found</p>
              </div>
            </div>
            <button 
              onClick={() => { setFile(null); setPreview([]); }}
              className="text-gray-500 hover:text-red-500 p-2"
            >
              <Trash2 size={20} />
            </button>
          </div>

          <div className="bg-white rounded-xl shadow-sm border overflow-hidden">
            <div className="overflow-x-auto max-h-96">
              <table className="w-full text-sm text-left">
                <thead className="text-xs text-gray-700 uppercase bg-gray-50 sticky top-0">
                  <tr>
                    <th className="px-6 py-3">Date</th>
                    <th className="px-6 py-3">Note / Description</th>
                    <th className="px-6 py-3">Category</th>
                    <th className="px-6 py-3 text-right">Amount</th>
                    <th className="px-6 py-3">Currency</th>
                    <th className="px-6 py-3 text-center">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {preview.map((row, i) => (
                    <tr key={row.id} className="border-b hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">{row.date}</td>
                      <td className="px-6 py-4">{row.note}</td>
                      <td className="px-6 py-4">{row.category}</td>
                      <td className={`px-6 py-4 text-right font-medium ${row.amount > 0 || row.type === 'income' ? 'text-green-600' : 'text-gray-900'}`}>
                        {Math.abs(row.amount).toFixed(2)}
                      </td>
                      <td className="px-6 py-4">{row.currency}</td>
                      <td className="px-6 py-4 text-center">
                        <button onClick={() => removeRow(i)} className="text-gray-400 hover:text-red-500">
                          <Trash2 size={16} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            
            <div className="p-4 bg-gray-50 border-t flex justify-between items-center">
              <p className="text-sm text-gray-600">
                Ready to import {preview.length} transactions
              </p>
              <button
                onClick={handleUpload}
                disabled={isUploading || preview.length === 0}
                className="bg-black text-white px-6 py-2 rounded-lg font-medium hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isUploading ? 'Importing...' : 'Confirm Import'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
    </ProtectedRoute>
  );
}

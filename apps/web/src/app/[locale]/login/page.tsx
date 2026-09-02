'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useLocale } from 'next-intl';
import { useAuth } from '@/lib/auth/AuthContext';

export default function LoginPage() {
  const router = useRouter();
  const locale = useLocale();
  const { login } = useAuth();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleOAuthLogin = async (provider: 'google' | 'apple') => {
    setIsLoading(true);
    setError(null);

    const tokenFromEnv =
      provider === 'google'
        ? process.env.NEXT_PUBLIC_DEV_GOOGLE_ID_TOKEN
        : process.env.NEXT_PUBLIC_DEV_APPLE_ID_TOKEN;
    const emailFromEnv = process.env.NEXT_PUBLIC_DEV_AUTH_EMAIL;
    const nameFromEnv = process.env.NEXT_PUBLIC_DEV_AUTH_NAME || 'DailySpend User';
    const providerIdFromEnv = process.env.NEXT_PUBLIC_DEV_PROVIDER_ID || `${provider}-web`;

    if (!tokenFromEnv || !emailFromEnv) {
      setError(
        `Missing dev auth env for ${provider}. Set NEXT_PUBLIC_DEV_${provider.toUpperCase()}_ID_TOKEN and NEXT_PUBLIC_DEV_AUTH_EMAIL.`,
      );
      setIsLoading(false);
      return;
    }

    try {
      if (provider === 'google') {
        await login(provider, {
          idToken: tokenFromEnv,
          email: emailFromEnv,
          displayName: nameFromEnv,
          providerId: providerIdFromEnv,
        });
      } else {
        await login(provider, {
          identityToken: tokenFromEnv,
          email: emailFromEnv,
          displayName: nameFromEnv,
          providerId: providerIdFromEnv,
        });
      }

      router.push(`/${locale}/dashboard`);
    } catch (error) {
      console.error('Login failed', error);
      setError('Authentication failed. Check API and OAuth env configuration.');
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-24 bg-gray-50">
      <div className="w-full max-w-md bg-white rounded-xl shadow-md p-8 border border-gray-100">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold mb-2">Project PET</h1>
          <p className="text-gray-500">Sign in to sync your expenses</p>
        </div>

        <div className="space-y-4">
          <button
            onClick={() => handleOAuthLogin('google')}
            disabled={isLoading}
            className="w-full flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg shadow-sm bg-white text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            <span className="mr-2">Google</span>
            Continue with Google
          </button>
          
          <button
            onClick={() => handleOAuthLogin('apple')}
            disabled={isLoading}
            className="w-full flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg shadow-sm bg-black text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
          >
            <span className="mr-2">Apple</span>
            Continue with Apple
          </button>
        </div>
        {error && (
          <p className="mt-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {error}
          </p>
        )}
      </div>
    </div>
  );
}

'use client';

import React, { createContext, useCallback, useContext, useState, ReactNode } from 'react';
import { authApi } from '@/lib/api-client';

const ACCESS_TOKEN_KEY = 'accessToken';
const LEGACY_ACCESS_TOKEN_KEY = 'jwt_access_token';
const REFRESH_TOKEN_KEY = 'refreshToken';

function getStoredAccessToken() {
  if (typeof window === 'undefined') {
    return null;
  }

  return (
    localStorage.getItem(ACCESS_TOKEN_KEY) ||
    localStorage.getItem(LEGACY_ACCESS_TOKEN_KEY)
  );
}

type GoogleLoginPayload = {
  idToken: string;
  email: string;
  displayName: string;
  avatarUrl?: string;
  providerId: string;
  refreshToken?: string;
};

type AppleLoginPayload = {
  identityToken: string;
  email: string;
  displayName: string;
  providerId: string;
};

type LoginPayload = GoogleLoginPayload | AppleLoginPayload;

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (provider: 'google' | 'apple', payload?: LoginPayload) => Promise<void>;
  logout: () => void;
  refreshSession: () => Promise<void>;
  token: string | null;
}

const AuthContext = createContext<AuthContextType>({
  isAuthenticated: false,
  isLoading: true,
  login: async () => {},
  logout: () => {},
  refreshSession: async () => {},
  token: null,
});

export function AuthProvider({ children }: Readonly<{ children: ReactNode }>) {
  const [token, setToken] = useState<string | null>(() => getStoredAccessToken());
  const [isAuthenticated, setIsAuthenticated] = useState(() => Boolean(getStoredAccessToken()));
  const [isLoading] = useState(false);

  const persistSession = useCallback((accessToken: string, refreshToken?: string) => {
    localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
    localStorage.setItem(LEGACY_ACCESS_TOKEN_KEY, accessToken);
    if (refreshToken) {
      localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
    }
    setToken(accessToken);
    setIsAuthenticated(true);
  }, []);

  const login = useCallback(async (provider: 'google' | 'apple', payload?: LoginPayload) => {
    if (!payload) {
      throw new Error(`${provider} login payload is required`);
    }

    const response =
      provider === 'google'
        ? await authApi.google(payload as GoogleLoginPayload)
        : await authApi.apple(payload as AppleLoginPayload);

    persistSession(response.accessToken, response.refreshToken);
  }, [persistSession]);

  const refreshSession = useCallback(async () => {
    const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);
    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    const refreshed = await authApi.refresh(refreshToken);
    persistSession(refreshed.accessToken, refreshed.refreshToken);
  }, [persistSession]);

  const logout = useCallback(() => {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(LEGACY_ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    setToken(null);
    setIsAuthenticated(false);
  }, []);

  const contextValue = React.useMemo(
    () => ({ isAuthenticated, isLoading, login, logout, refreshSession, token }),
    [isAuthenticated, isLoading, login, logout, refreshSession, token],
  );

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);

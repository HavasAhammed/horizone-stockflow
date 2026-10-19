import React, { createContext, useContext, useState } from 'react';

interface AuthContextType {
  isLoggedIn: boolean;
  userEmail: string | null;
  userName: string | null;
  login: (email: string, pass: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const AUTH_STORAGE_KEY = 'stockflow_auth_session';

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(() => {
    return localStorage.getItem(AUTH_STORAGE_KEY) === 'true';
  });
  const [userEmail, setUserEmail] = useState<string | null>(() => {
    return localStorage.getItem('stockflow_user_email') || (isLoggedIn ? 'user@horizone.com' : null);
  });
  const [userName, setUserName] = useState<string | null>(() => {
    return localStorage.getItem('stockflow_user_name') || (isLoggedIn ? 'Stock Manager' : null);
  });

  const login = async (email: string, pass: string): Promise<{ success: boolean; error?: string }> => {
    const cleanEmail = email.trim().toLowerCase();
    const cleanPass = pass.trim();

    if (!cleanEmail || !cleanPass) {
      return { success: false, error: 'Please enter both email and password' };
    }

    if (cleanEmail === 'user@horizone.com' && cleanPass === 'user123') {
      setIsLoggedIn(true);
      setUserEmail('user@horizone.com');
      setUserName('Stock Manager');
      localStorage.setItem(AUTH_STORAGE_KEY, 'true');
      localStorage.setItem('stockflow_user_email', 'user@horizone.com');
      localStorage.setItem('stockflow_user_name', 'Stock Manager');
      return { success: true };
    } else {
      return { success: false, error: 'Invalid email or password. Please try again.' };
    }
  };

  const logout = () => {
    setIsLoggedIn(false);
    setUserEmail(null);
    setUserName(null);
    localStorage.removeItem(AUTH_STORAGE_KEY);
    localStorage.removeItem('stockflow_user_email');
    localStorage.removeItem('stockflow_user_name');
  };

  return (
    <AuthContext.Provider value={{ isLoggedIn, userEmail, userName, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

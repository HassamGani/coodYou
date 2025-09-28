'use client';

import { SWRConfig } from 'swr';
import { AuthProvider } from '@/hooks/useAuth';

export const Providers = ({ children }: { children: React.ReactNode }) => {
  return (
    <AuthProvider>
      <SWRConfig value={{ provider: () => new Map(), revalidateOnFocus: false }}>{children}</SWRConfig>
    </AuthProvider>
  );
};

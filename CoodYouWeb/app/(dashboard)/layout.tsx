'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { SidebarNav } from '@/components/SidebarNav';
import { TopBar } from '@/components/TopBar';
import { useAuth } from '@/hooks/useAuth';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !user) {
      router.replace('/auth/sign-in');
    }
  }, [loading, router, user]);

  if (!user) {
    return <div className="flex min-h-screen items-center justify-center bg-transparent text-white/50">Checking session…</div>;
  }

  return (
    <div className="flex min-h-screen bg-transparent text-[color:var(--text-primary)]">
      <SidebarNav />
      <div className="flex flex-1 flex-col">
        <TopBar />
        <main className="flex-1 overflow-y-auto px-6 py-8 lg:px-10">
          <div className="mx-auto w-full max-w-7xl space-y-10 pb-10">{children}</div>
        </main>
      </div>
    </div>
  );
}

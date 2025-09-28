'use client';

import { useEffect, useState } from 'react';
import { AdminConsole } from '@/components/AdminConsole';
import { fetchDiningHalls } from '@/services/diningHallService';
import type { DiningHall } from '@/models/types';
import { useAuth } from '@/hooks/useAuth';

export default function AdminPage() {
  const { profile } = useAuth();
  const [halls, setHalls] = useState<DiningHall[]>([]);

  useEffect(() => {
    fetchDiningHalls().then(setHalls);
  }, []);

  if (profile?.activeRole !== 'admin') {
    return (
      <div className="rounded-3xl border border-white/10 bg-red-500/10 p-6 text-sm text-red-200">
        You need the admin role to access this console.
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-white">Admin controls</h2>
        <p className="text-sm text-slate-400">Manage dining halls, adjust windows, and monitor marketplace health.</p>
      </div>
      <AdminConsole halls={halls} />
    </div>
  );
}

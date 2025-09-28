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
      <div className="surface-card--muted border border-red-500/30 p-6 text-sm text-red-200">
        You need the admin role to access this console.
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <section className="surface-card p-6">
        <p className="text-xs uppercase tracking-[0.32em] text-white/40">Admin controls</p>
        <h2 className="mt-1 text-2xl font-semibold text-white">Live marketplace adjustments</h2>
        <p className="text-xs text-white/55">Manage dining halls, adjust windows, and monitor marketplace health in real time.</p>
      </section>
      <AdminConsole halls={halls} />
    </div>
  );
}

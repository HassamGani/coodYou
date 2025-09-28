'use client';

import { useState } from 'react';
import { createOrder } from '@/services/orderService';
import type { DiningHall, ServiceWindowCode } from '@/models/types';
import { useAuth } from '@/hooks/useAuth';

interface OrderComposerProps {
  hall?: DiningHall;
}

const windowOptions: { value: ServiceWindowCode; label: string }[] = [
  { value: 'breakfast', label: 'Breakfast' },
  { value: 'lunch', label: 'Lunch' },
  { value: 'dinner', label: 'Dinner' }
];

export const OrderComposer = ({ hall }: OrderComposerProps) => {
  const { user } = useAuth();
  const [windowCode, setWindowCode] = useState<ServiceWindowCode>('lunch');
  const [meetingPoint, setMeetingPoint] = useState('Butler Library steps');
  const [pickupNotes, setPickupNotes] = useState('Text me when you arrive.');
  const [status, setStatus] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (!user || !hall) {
    return (
      <div className="rounded-3xl border border-white/10 bg-white/[0.03] p-6 text-sm text-slate-400">
        Select a dining hall to create a pooled order.
      </div>
    );
  }

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      setLoading(true);
      await createOrder({ userId: user.uid, hallId: hall.id, windowCode, meetingPoint, pickupNotes });
      setStatus('Order placed and entered the pool. We will pair you with another buyer shortly.');
    } catch (err) {
      setStatus(`Error: ${(err as Error).message}`);
    } finally {
      setLoading(false);
    }
  };

  const basePriceField = `price_${windowCode}` as keyof DiningHall;
  const basePriceDollars = Number((hall as any)[basePriceField] ?? 0);
  const perBuyerPrice = basePriceDollars / 2 + 0.5;

  return (
    <form onSubmit={handleSubmit} className="space-y-4 rounded-3xl border border-white/10 bg-white/[0.04] p-6">
      <div>
        <h3 className="text-lg font-semibold text-white">Place pooled order</h3>
        <p className="text-xs text-slate-400">You will be matched with another student inside {hall.name}.</p>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        {windowOptions.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => setWindowCode(option.value)}
            className={`rounded-2xl border px-4 py-3 text-sm font-semibold transition ${
              windowCode === option.value
                ? 'border-brand.accent bg-brand.accent/10 text-brand.accent'
                : 'border-white/10 bg-white/5 text-slate-200 hover:border-white/30'
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-300">Meeting point</label>
          <input
            value={meetingPoint}
            onChange={(event) => setMeetingPoint(event.target.value)}
            className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus:border-brand.accent focus:outline-none"
          />
        </div>
        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-300">Notes for dasher</label>
          <input
            value={pickupNotes}
            onChange={(event) => setPickupNotes(event.target.value)}
            className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus:border-brand.accent focus:outline-none"
          />
        </div>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-wide text-slate-400">You will pay</p>
          <p className="text-2xl font-semibold text-white">${perBuyerPrice.toFixed(2)}</p>
          <p className="text-xs text-slate-500">Half of ${basePriceDollars.toFixed(2)} swipe + $0.50 fee</p>
        </div>
        <button
          type="submit"
          disabled={loading}
          className="rounded-2xl bg-brand.accent px-6 py-3 text-sm font-semibold text-slate-900 shadow-lg shadow-emerald-500/40 disabled:opacity-60"
        >
          {loading ? 'Queueing…' : 'Enter pool'}
        </button>
      </div>
      {status && <p className="text-xs text-slate-300">{status}</p>}
    </form>
  );
};

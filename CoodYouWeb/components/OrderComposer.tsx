'use client';

import { useState } from 'react';
import { clsx } from 'clsx';
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
    return <div className="surface-card--muted p-6 text-sm text-white/60">Select a dining hall to create a pooled order.</div>;
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
    <form onSubmit={handleSubmit} className="surface-card space-y-6 p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">Pool a swipe</p>
          <h3 className="mt-1 text-xl font-semibold text-white">Order from {hall.name}</h3>
          <p className="text-xs text-white/50">We will pair you with someone already inside the hall.</p>
        </div>
        <span className="pill-control px-3 py-1 text-white/60">{hall.campus === 'barnard' ? 'Barnard' : 'Columbia'}</span>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        {windowOptions.map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => setWindowCode(option.value)}
            className={clsx(
              'rounded-2xl border px-4 py-3 text-sm font-semibold transition-colors',
              windowCode === option.value
                ? 'border-white bg-white text-black shadow-[0_18px_40px_rgba(5,5,7,0.35)]'
                : 'border-white/10 bg-white/[0.02] text-white/70 hover:border-white/25 hover:text-white'
            )}
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
            className="w-full rounded-2xl border border-white/10 bg-[rgba(255,255,255,0.03)] px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-white focus:outline-none"
          />
        </div>
        <div className="space-y-2">
          <label className="text-xs font-semibold uppercase tracking-wide text-slate-300">Notes for dasher</label>
          <input
            value={pickupNotes}
            onChange={(event) => setPickupNotes(event.target.value)}
            className="w-full rounded-2xl border border-white/10 bg-[rgba(255,255,255,0.03)] px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-white focus:outline-none"
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
          className="rounded-full bg-white px-6 py-3 text-sm font-semibold text-black shadow-[0_20px_45px_rgba(255,255,255,0.15)] transition disabled:opacity-60"
        >
          {loading ? 'Queueing…' : 'Enter pool'}
        </button>
      </div>
      {status && <p className="text-xs text-white/60">{status}</p>}
    </form>
  );
};

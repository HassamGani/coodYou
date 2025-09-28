'use client';

import type { PaymentMethod, UserProfile } from '@/models/types';
import { createPaymentMethod, linkStripeAccount } from '@/services/paymentService';
import { useState } from 'react';

interface WalletOverviewProps {
  profile?: UserProfile | null;
  paymentMethods: (PaymentMethod & { id: string })[];
}

export const WalletOverview = ({ profile, paymentMethods }: WalletOverviewProps) => {
  const [status, setStatus] = useState<string | null>(null);

  const handleAddMockMethod = async () => {
    if (!profile) return;
    await createPaymentMethod({
      id: Math.random().toString(36).slice(2),
      type: 'card',
      displayName: 'Visa ending 4242',
      lastFour: '4242',
      isDefault: paymentMethods.length === 0,
      userId: profile.id
    });
    setStatus('Mock card saved. Replace with Stripe Elements for production.');
  };

  const handleLinkStripe = async () => {
    if (!profile) return;
    await linkStripeAccount(profile.id);
    setStatus('Stripe onboarding link requested. Check your email to finish account setup.');
  };

  return (
    <div className="space-y-6">
      <section className="surface-card p-6">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Wallet balance</p>
            <p className="mt-2 text-4xl font-semibold text-white">${((profile?.walletBalanceCents ?? 0) / 100).toFixed(2)}</p>
            <p className="mt-1 text-xs text-white/50">Funds transfer to Stripe Express after delivery confirmation.</p>
          </div>
          <button
            onClick={handleLinkStripe}
            className="rounded-full border border-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-white/80 transition hover:border-white hover:bg-white hover:text-black"
          >
            Link Stripe
          </button>
        </div>
      </section>

      <section className="surface-card p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Payment methods</p>
            <h3 className="text-lg font-semibold text-white">Linked instruments</h3>
          </div>
          <button
            onClick={handleAddMockMethod}
            className="rounded-full border border-white/12 px-4 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-white/80 transition hover:border-white hover:bg-white hover:text-black"
          >
            Add card
          </button>
        </div>
        <div className="mt-4 space-y-3">
          {paymentMethods.length === 0 && <p className="text-sm text-white/60">No saved cards yet.</p>}
          {paymentMethods.map((method) => (
            <div key={method.id} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/80">
              <div>
                <p className="text-sm font-semibold text-white">{method.displayName}</p>
                <p className="text-xs text-white/45">{method.type.toUpperCase()} {method.lastFour && `• ${method.lastFour}`}</p>
              </div>
              {method.isDefault && <span className="rounded-full bg-white px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.24em] text-black">Default</span>}
            </div>
          ))}
        </div>
      </section>

      {status && <p className="text-xs text-white/60">{status}</p>}
    </div>
  );
};

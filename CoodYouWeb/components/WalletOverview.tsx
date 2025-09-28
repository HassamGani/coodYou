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
      <section className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
        <h3 className="text-lg font-semibold text-white">Wallet balance</h3>
        <p className="text-4xl font-semibold text-brand.accent">${((profile?.walletBalanceCents ?? 0) / 100).toFixed(2)}</p>
        <p className="text-xs text-slate-400">Funds transfer to Stripe Express after delivery confirmation.</p>
        <button
          onClick={handleLinkStripe}
          className="mt-4 rounded-full bg-brand.accent px-5 py-2 text-xs font-semibold uppercase tracking-wide text-slate-900 shadow-lg shadow-emerald-500/40"
        >
          Link Stripe account
        </button>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-white">Payment methods</h3>
          <button
            onClick={handleAddMockMethod}
            className="rounded-full border border-white/15 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-slate-200 hover:border-brand.accent hover:text-brand.accent"
          >
            Add card
          </button>
        </div>
        <div className="mt-4 space-y-3">
          {paymentMethods.length === 0 && <p className="text-sm text-slate-400">No saved cards yet.</p>}
          {paymentMethods.map((method) => (
            <div key={method.id} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
              <div>
                <p className="text-sm font-semibold text-white">{method.displayName}</p>
                <p className="text-xs text-slate-400">{method.type.toUpperCase()} {method.lastFour && `• ${method.lastFour}`}</p>
              </div>
              {method.isDefault && <span className="text-xs text-brand.accent">Default</span>}
            </div>
          ))}
        </div>
      </section>

      {status && <p className="text-xs text-slate-300">{status}</p>}
    </div>
  );
};

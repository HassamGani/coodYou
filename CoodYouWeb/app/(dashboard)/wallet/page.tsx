'use client';

import { useMemo } from 'react';
import { WalletOverview } from '@/components/WalletOverview';
import { paymentMethodsQuery, paymentsForUserQuery, payoutsForDasherQuery } from '@/services/paymentService';
import { useCollection } from '@/hooks/useCollection';
import type { PaymentMethod } from '@/models/types';
import { useAuth } from '@/hooks/useAuth';

export default function WalletPage() {
  const { user, profile } = useAuth();

  const methodsQuery = useMemo(() => (user ? paymentMethodsQuery(user.uid) : null), [user]);
  const buyerPaymentsQuery = useMemo(() => (user ? paymentsForUserQuery(user.uid) : null), [user]);
  const dasherPayoutsQuery = useMemo(() => (user ? payoutsForDasherQuery(user.uid) : null), [user]);

  const { data: paymentMethods } = useCollection<PaymentMethod & { id: string }>(methodsQuery);
  const { data: buyerPayments } = useCollection<any>(buyerPaymentsQuery);
  const { data: dasherPayouts } = useCollection<any>(dasherPayoutsQuery);

  return (
    <div className="grid gap-10 lg:grid-cols-[1.2fr_1fr]">
      <WalletOverview profile={profile} paymentMethods={paymentMethods ?? []} />
      <section className="space-y-6">
        <div className="surface-card p-6">
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">Recent charges</p>
          <ul className="mt-4 space-y-3 text-sm text-white/70">
            {(buyerPayments ?? []).map((payment: any) => (
              <li key={payment.id} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
                <span className="font-semibold text-white">${((payment.amountCents ?? 0) / 100).toFixed(2)}</span>
                <span className="text-xs text-white/45">{new Date(payment.createdAt?.toMillis?.() ?? Date.now()).toLocaleString()}</span>
              </li>
            ))}
            {(buyerPayments ?? []).length === 0 && <p className="text-xs text-white/50">No payments yet.</p>}
          </ul>
        </div>
        <div className="surface-card p-6">
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">Recent payouts</p>
          <ul className="mt-4 space-y-3 text-sm text-white/70">
            {(dasherPayouts ?? []).map((payout: any) => (
              <li key={payout.id} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
                <span className="font-semibold text-white">${((payout.payoutCents ?? 0) / 100).toFixed(2)}</span>
                <span className="text-xs text-white/45">{new Date(payout.createdAt?.toMillis?.() ?? Date.now()).toLocaleString()}</span>
              </li>
            ))}
            {(dasherPayouts ?? []).length === 0 && <p className="text-xs text-white/50">No payouts yet.</p>}
          </ul>
        </div>
      </section>
    </div>
  );
}

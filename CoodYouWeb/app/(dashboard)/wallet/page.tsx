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
    <div className="grid gap-8 lg:grid-cols-[1.2fr_1fr]">
      <WalletOverview profile={profile} paymentMethods={paymentMethods ?? []} />
      <section className="space-y-6">
        <div className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
          <h3 className="text-lg font-semibold text-white">Recent charges</h3>
          <ul className="mt-4 space-y-3 text-sm text-slate-300">
            {(buyerPayments ?? []).map((payment: any) => (
              <li key={payment.id} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
                <span>${((payment.amountCents ?? 0) / 100).toFixed(2)}</span>
                <span className="text-xs text-slate-500">{new Date(payment.createdAt?.toMillis?.() ?? Date.now()).toLocaleString()}</span>
              </li>
            ))}
            {(buyerPayments ?? []).length === 0 && <p className="text-xs text-slate-400">No payments yet.</p>}
          </ul>
        </div>
        <div className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
          <h3 className="text-lg font-semibold text-white">Recent payouts</h3>
          <ul className="mt-4 space-y-3 text-sm text-slate-300">
            {(dasherPayouts ?? []).map((payout: any) => (
              <li key={payout.id} className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3">
                <span>${((payout.payoutCents ?? 0) / 100).toFixed(2)}</span>
                <span className="text-xs text-slate-500">{new Date(payout.createdAt?.toMillis?.() ?? Date.now()).toLocaleString()}</span>
              </li>
            ))}
            {(dasherPayouts ?? []).length === 0 && <p className="text-xs text-slate-400">No payouts yet.</p>}
          </ul>
        </div>
      </section>
    </div>
  );
}

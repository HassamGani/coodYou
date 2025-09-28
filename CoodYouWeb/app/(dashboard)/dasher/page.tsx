'use client';

import { useEffect, useMemo, useState } from 'react';
import { RunFeed } from '@/components/RunFeed';
import { availableRunsQuery, runsForDasherQuery } from '@/services/runService';
import { useCollection } from '@/hooks/useCollection';
import type { Run } from '@/models/types';
import { fetchDiningHalls } from '@/services/diningHallService';
import type { DiningHall } from '@/models/types';
import { useAuth } from '@/hooks/useAuth';

export default function DasherPage() {
  const { user, profile } = useAuth();
  const [hallFilter, setHallFilter] = useState<string | undefined>();
  const [halls, setHalls] = useState<DiningHall[]>([]);

  useEffect(() => {
    fetchDiningHalls().then(setHalls);
  }, []);

  const availableQuery = useMemo(() => availableRunsQuery(hallFilter), [hallFilter]);
  const myRunsQuery = useMemo(() => (user ? runsForDasherQuery(user.uid) : null), [user]);

  const { data: availableRuns } = useCollection<Run>(availableQuery);
  const { data: myRuns } = useCollection<Run>(myRunsQuery);

  return (
    <div className="space-y-8">
      <section className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-semibold text-white">Claimable runs</h2>
          <p className="text-sm text-slate-400">Walk into a hall and accept a pooled order. Payouts hit your wallet instantly.</p>
        </div>
        <select
          value={hallFilter ?? ''}
          onChange={(event) => setHallFilter(event.target.value || undefined)}
          className="rounded-full border border-white/15 bg-white/5 px-4 py-2 text-sm text-white"
        >
          <option value="">All halls</option>
          {halls.map((hall) => (
            <option key={hall.id} value={hall.id}>
              {hall.name}
            </option>
          ))}
        </select>
      </section>

      <RunFeed runs={availableRuns ?? []} mode="available" />

      <section className="space-y-4">
        <h2 className="text-2xl font-semibold text-white">My active runs</h2>
        <RunFeed runs={myRuns ?? []} mode="my" />
      </section>

      <section className="rounded-3xl border border-white/10 bg-brand.accent/10 p-6 text-sm text-brand.accent">
        Stripe status: {profile?.stripeAccountStatus ?? 'pending verification'}. Complete onboarding to unlock instant payouts.
      </section>
    </div>
  );
}

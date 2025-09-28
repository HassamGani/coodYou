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
      <section className="surface-card p-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Claimable runs</p>
            <h2 className="mt-1 text-2xl font-semibold text-white">Walk-in jobs ready to assign</h2>
            <p className="text-xs text-white/55">Enter a hall and tap claim to pair with waiting buyers.</p>
          </div>
          <select
            value={hallFilter ?? ''}
            onChange={(event) => setHallFilter(event.target.value || undefined)}
            className="rounded-full border border-white/12 bg-transparent px-4 py-2 text-sm text-white/80 transition focus:border-white focus:outline-none"
          >
            <option value="">All halls</option>
            {halls.map((hall) => (
              <option key={hall.id} value={hall.id}>
                {hall.name}
              </option>
            ))}
          </select>
        </div>
        <div className="mt-6">
          <RunFeed runs={availableRuns ?? []} mode="available" />
        </div>
      </section>

      <section className="surface-card p-6 space-y-4">
        <div>
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">My active runs</p>
          <h2 className="mt-1 text-2xl font-semibold text-white">Track your deliveries</h2>
        </div>
        <RunFeed runs={myRuns ?? []} mode="my" />
      </section>

      <section className="surface-card--muted border border-white/12 p-6 text-sm text-white/70">
        Stripe status: {profile?.stripeAccountStatus ?? 'pending verification'}. Complete onboarding to unlock instant payouts.
      </section>
    </div>
  );
}

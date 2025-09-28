'use client';

import { useMemo } from 'react';
import { clsx } from 'clsx';
import type { Run } from '@/models/types';
import { claimRun, markDelivered, markPickedUp } from '@/services/runService';

interface RunFeedProps {
  runs: Run[];
  mode: 'available' | 'my';
}

const statusBadge: Record<Run['status'], string> = {
  readyToAssign: 'Ready to assign',
  claimed: 'Claimed',
  inProgress: 'In progress',
  delivered: 'Delivered',
  paid: 'Paid',
  closed: 'Closed'
};

export const RunFeed = ({ runs, mode }: RunFeedProps) => {
  const normalizedRuns = useMemo(
    () =>
      runs.map((run) => ({
        ...run,
        claimedAt:
          typeof (run as any).claimedAt === 'object' && (run as any).claimedAt?.toMillis
            ? (run as any).claimedAt.toMillis()
            : (run as any).claimedAt ?? Date.now(),
        payoutCents: Number((run as any).payoutCents ?? (run as any).estimatedPayoutCents ?? 0)
      })),
    [runs]
  );

  const sortedRuns = useMemo(
    () => normalizedRuns.slice().sort((a, b) => (b.claimedAt ?? 0) - (a.claimedAt ?? 0)),
    [normalizedRuns]
  );

  if (sortedRuns.length === 0) {
    return (
      <div className="surface-card--muted p-6 text-sm text-white/60">
        {mode === 'available' ? 'No runs waiting to be claimed.' : 'You have no active runs right now.'}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {sortedRuns.map((run) => {
        const payout = (run.payoutCents ?? 0) / 100;
        const estimatedRaw = (run as any).estimatedPayoutCents ?? run.payoutCents ?? 0;
        const estimated = Number(estimatedRaw) / 100;
        const ordersCount = run.buyerOrderIds.length;
        const statusLabel = statusBadge[run.status];
        return (
          <div key={run.id} className="surface-card--muted border border-white/12 p-5">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-white">{run.hallId}</p>
                <p className="text-xs text-white/45">{ordersCount} orders in pool</p>
              </div>
              <span className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-white/70">
                {mode === 'available' ? 'Ready to claim' : statusLabel}
              </span>
            </div>
            <div className="mt-4 flex flex-wrap items-center justify-between gap-3 text-xs text-white/55">
              <p>Estimated payout: ${estimated.toFixed(2)}</p>
              {run.deliveryPin && <p>Delivery PIN: {run.deliveryPin}</p>}
            </div>
            <div className="mt-4 flex flex-wrap items-center gap-3">
              {mode === 'available' ? (
                <button
                  onClick={() => claimRun(run.id)}
                  className="rounded-full border border-white/12 px-5 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:border-white hover:bg-white hover:text-black"
                >
                  Claim run
                </button>
              ) : (
                <>
                  {run.status === 'claimed' && (
                    <button
                      onClick={() => markPickedUp(run.id)}
                      className="rounded-full border border-white/12 px-5 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white/80 transition hover:border-white hover:bg-white hover:text-black"
                    >
                      Mark picked up
                    </button>
                  )}
                  {run.status === 'inProgress' && (
                    <button
                      onClick={() => {
                        const pin = prompt('Enter delivery PIN');
                        if (pin) markDelivered(run.id, pin);
                      }}
                      className="rounded-full border border-white/12 px-5 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white transition hover:border-white hover:bg-white hover:text-black"
                    >
                      Mark delivered
                    </button>
                  )}
                  {run.status === 'delivered' && (
                    <span className="rounded-full border border-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white/50">
                      Awaiting payout
                    </span>
                  )}
                </>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
};

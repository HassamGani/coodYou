'use client';

import { useMemo } from 'react';
import { clsx } from 'clsx';
import type { DiningHall, Order } from '@/models/types';
import { cancelOrder } from '@/services/orderService';

interface ActiveOrdersProps {
  orders: Order[];
  halls?: DiningHall[];
}

const statusLabels: Record<Order['status'], string> = {
  requested: 'Requested',
  pooled: 'Pooled',
  readyToAssign: 'Ready to assign',
  claimed: 'Claimed',
  inProgress: 'In progress',
  delivered: 'Delivered',
  paid: 'Paid',
  closed: 'Closed',
  expired: 'Expired',
  cancelledBuyer: 'Cancelled',
  cancelledDasher: 'Dasher cancelled',
  disputed: 'Disputed'
};

const canCancelStatuses: Order['status'][] = ['requested', 'pooled'];

export const ActiveOrders = ({ orders, halls }: ActiveOrdersProps) => {
  const hallMap = new Map(halls?.map((hall) => [hall.id, hall.name] as const) ?? []);
  const sortedOrders = useMemo(
    () => orders.slice().sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0)),
    [orders]
  );

  if (sortedOrders.length === 0) {
    return <div className="surface-card--muted p-6 text-sm text-white/60">No active orders — queue a pool to get started.</div>;
  }

  return (
    <div className="space-y-3">
      {sortedOrders.map((order) => {
        const created = new Date(order.createdAt ?? Date.now());
        const canCancel = canCancelStatuses.includes(order.status);
        return (
          <div key={order.id} className="surface-card--muted border border-white/12 p-5">
            <div className="flex items-center justify-between text-sm">
              <div>
                <p className="text-base font-semibold text-white">{hallMap.get(order.hallId) ?? order.hallId}</p>
                <p className="text-xs text-white/45">Placed {created.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
              </div>
              <span
                className={clsx(
                  'rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em]',
                  order.status === 'claimed' || order.status === 'inProgress'
                    ? 'bg-white text-black'
                    : 'bg-white/8 text-white/70'
                )}
              >
                {statusLabels[order.status]}
              </span>
            </div>
            <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs text-white/50">
              <p>Price: ${(order.priceCents / 100).toFixed(2)}</p>
              {order.meetingPoint && <p>Meet at: {order.meetingPoint}</p>}
              {order.pinCode && <p>PIN: {order.pinCode}</p>}
            </div>
            {canCancel && (
              <div className="mt-3 text-right">
                <button
                  onClick={() => cancelOrder(order.id)}
                  className="rounded-full border border-white/15 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-white/70 transition hover:border-[#f97066] hover:text-[#f97066]"
                >
                  Cancel order
                </button>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};

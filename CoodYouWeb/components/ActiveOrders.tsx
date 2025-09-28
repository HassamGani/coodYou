'use client';

import { useMemo } from 'react';
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
    return (
      <div className="rounded-3xl border border-white/10 bg-white/[0.03] p-6 text-sm text-slate-400">
        You have no active orders right now.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {sortedOrders.map((order) => {
        const created = new Date(order.createdAt ?? Date.now());
        const canCancel = canCancelStatuses.includes(order.status);
        return (
          <div key={order.id} className="rounded-3xl border border-white/10 bg-white/[0.04] p-5">
            <div className="flex items-center justify-between text-sm text-slate-300">
              <div>
                <p className="text-base font-semibold text-white">{hallMap.get(order.hallId) ?? order.hallId}</p>
                <p className="text-xs text-slate-500">Placed {created.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
              </div>
              <span className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-white/80">
                {statusLabels[order.status]}
              </span>
            </div>
            <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs text-slate-400">
              <p>Price: ${(order.priceCents / 100).toFixed(2)}</p>
              {order.meetingPoint && <p>Meet at: {order.meetingPoint}</p>}
              {order.pinCode && <p>PIN: {order.pinCode}</p>}
            </div>
            {canCancel && (
              <div className="mt-3 text-right">
                <button
                  onClick={() => cancelOrder(order.id)}
                  className="rounded-full border border-white/15 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-slate-200 hover:border-brand.danger hover:text-brand.danger"
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

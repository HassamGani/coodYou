'use client';

import { useEffect, useState } from 'react';
import { MapPanel } from '@/components/MapPanel';
import { HallList } from '@/components/HallList';
import { OrderComposer } from '@/components/OrderComposer';
import { ActiveOrders } from '@/components/ActiveOrders';
import { fetchDiningHalls, fetchLivePoolStats } from '@/services/diningHallService';
import { ordersForUserQuery } from '@/services/orderService';
import { useCollection } from '@/hooks/useCollection';
import type { DiningHall, LivePoolStat, Order } from '@/models/types';
import { useAuth } from '@/hooks/useAuth';

export default function DispatchPage() {
  const { user } = useAuth();
  const [halls, setHalls] = useState<DiningHall[]>([]);
  const [stats, setStats] = useState<LivePoolStat[]>([]);
  const [selectedHallId, setSelectedHallId] = useState<string | undefined>();

  useEffect(() => {
    let mounted = true;
    fetchDiningHalls().then((items) => {
      if (!mounted) return;
      setHalls(items);
      setSelectedHallId((current) => current ?? items[0]?.id);
    });
    fetchLivePoolStats().then((incoming) => {
      if (mounted) setStats(incoming);
    });
    const interval = setInterval(() => {
      fetchLivePoolStats().then((incoming) => {
        if (mounted) setStats(incoming);
      });
    }, 15000);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, []);

  const orderQuery = user ? ordersForUserQuery(user.uid) : null;
  const { data: orders } = useCollection<Order>(orderQuery);

  const safeOrders = user
    ? orders.map((order) => ({
        ...order,
        priceCents: Number((order as any).priceCents ?? 0),
        createdAt:
          typeof (order as any).createdAt === 'object' && (order as any).createdAt?.toMillis
            ? (order as any).createdAt.toMillis()
            : (order as any).createdAt ?? Date.now()
      }))
    : [];
  const selectedHall = halls.find((hall) => hall.id === selectedHallId);
  const openHallCount = halls.filter((hall) => hall.isOpen).length;
  const totalWaiting = stats.reduce((sum, stat) => sum + (stat.waitingCount ?? 0), 0);
  const averageWait = stats.length ? stats.reduce((sum, stat) => sum + (stat.avgWaitMinutes ?? 0), 0) / stats.length : 0;
  const activeOrderCount = safeOrders.length;

  return (
    <div className="space-y-8">
      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="surface-card--muted border border-white/10 p-5">
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">Open halls</p>
          <p className="mt-2 text-3xl font-semibold text-white">{openHallCount}</p>
          <p className="text-xs text-white/50">Out of {halls.length} mapped halls.</p>
        </div>
        <div className="surface-card--muted border border-white/10 p-5">
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">Waiting buyers</p>
          <p className="mt-2 text-3xl font-semibold text-white">{totalWaiting}</p>
          <p className="text-xs text-white/50">Live pairs queued across the network.</p>
        </div>
        <div className="surface-card--muted border border-white/10 p-5">
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">Avg wait</p>
          <p className="mt-2 text-3xl font-semibold text-white">{averageWait.toFixed(1)}m</p>
          <p className="text-xs text-white/50">Refreshes every 15 seconds from Firestore.</p>
        </div>
        <div className="surface-card--muted border border-white/10 p-5">
          <p className="text-xs uppercase tracking-[0.32em] text-white/40">My orders</p>
          <p className="mt-2 text-3xl font-semibold text-white">{activeOrderCount}</p>
          <p className="text-xs text-white/50">Track live buyer status here.</p>
        </div>
      </section>

      <div className="grid gap-6 xl:grid-cols-[1.6fr_1fr]">
        <section className="space-y-4">
          <div className="surface-card overflow-hidden">
            <div className="h-[420px]">
              <MapPanel halls={halls} selectedHallId={selectedHallId} onSelectHall={setSelectedHallId} />
            </div>
            <div className="border-t border-white/5 bg-[rgba(5,5,7,0.55)] px-6 py-4">
              <div className="mb-3 flex items-center justify-between text-xs text-white/50">
                <span>Select a hall to focus the map</span>
                <span>{selectedHall ? selectedHall.name : 'Showing all halls'}</span>
              </div>
              <div className="max-h-56 space-y-3 overflow-y-auto pr-2">
                <HallList halls={halls} stats={stats} selectedHallId={selectedHallId} onSelectHall={setSelectedHallId} />
              </div>
            </div>
          </div>
        </section>
        <section className="space-y-4">
          <OrderComposer hall={selectedHall} />
          <ActiveOrders orders={safeOrders} halls={halls} />
        </section>
      </div>
    </div>
  );
}

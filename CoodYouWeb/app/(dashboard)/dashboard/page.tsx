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

  return (
    <div className="grid gap-8 lg:grid-cols-[1.2fr_1fr]">
      <section className="space-y-4">
        <div className="h-[400px] overflow-hidden rounded-3xl">
          <MapPanel halls={halls} selectedHallId={selectedHallId} onSelectHall={setSelectedHallId} />
        </div>
        <HallList halls={halls} stats={stats} selectedHallId={selectedHallId} onSelectHall={setSelectedHallId} />
      </section>
      <section className="space-y-4">
        <OrderComposer hall={selectedHall} />
        <ActiveOrders orders={safeOrders} halls={halls} />
      </section>
    </div>
  );
}

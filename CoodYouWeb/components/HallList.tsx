'use client';

import type { DiningHall, LivePoolStat, ServiceWindowCode } from '@/models/types';
import { clsx } from 'clsx';

interface HallListProps {
  halls: DiningHall[];
  stats?: LivePoolStat[];
  selectedHallId?: string;
  onSelectHall?: (hallId: string) => void;
}

const windowLabels: Record<ServiceWindowCode, string> = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner'
};

const formatWait = (value: number) => {
  if (!value) return 'No wait';
  if (value < 60) return `${Math.max(value, 1)}s avg wait`;
  const minutes = Math.round(value / 60);
  return `${minutes}m avg wait`;
};

export const HallList = ({ halls, stats, selectedHallId, onSelectHall }: HallListProps) => {
  const statsMap = new Map(stats?.map((item) => [`${item.hallId}_${item.windowCode}`, item]) ?? []);

  return (
    <div className="space-y-3">
      {halls.map((hall) => {
        const windowCode = hall.activeWindowId as ServiceWindowCode | undefined;
        const statKey = windowCode ? `${hall.id}_${windowCode}` : undefined;
        const liveStat = statKey ? statsMap.get(statKey) : undefined;
        return (
          <button
            key={hall.id}
            onClick={() => onSelectHall?.(hall.id)}
            className={clsx(
              'w-full rounded-3xl border px-5 py-4 text-left transition',
              selectedHallId === hall.id ? 'border-brand.accent bg-brand.accent/10' : 'border-white/10 bg-white/[0.03] hover:border-white/25'
            )}
          >
            <div className="flex items-start justify-between gap-4">
              <div className="space-y-1">
                <p className="text-base font-semibold text-white">{hall.name}</p>
                <p className="text-xs text-slate-400">{hall.address}</p>
                {windowCode && (
                  <p className="text-xs text-slate-300">
                    {windowLabels[windowCode]} window • {hall.isOpen ? 'Open' : 'Closed'}
                  </p>
                )}
              </div>
              <div className="flex flex-col items-end gap-2 text-xs text-slate-300">
                <span className={clsx('inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-semibold', hall.isOpen ? 'bg-brand.accent/20 text-brand.accent' : 'bg-slate-800 text-slate-300')}>
                  <span className={clsx('h-2 w-2 rounded-full', hall.isOpen ? 'bg-brand.accent' : 'bg-slate-500')} />
                  {hall.isOpen ? 'Accepting orders' : 'Closed'}
                </span>
                {liveStat && <span>{formatWait(liveStat.avgWaitMinutes)}</span>}
              </div>
            </div>
          </button>
        );
      })}
    </div>
  );
};

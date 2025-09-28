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
    <div className="space-y-2">
      {halls.map((hall) => {
        const windowCode = hall.activeWindowId as ServiceWindowCode | undefined;
        const statKey = windowCode ? `${hall.id}_${windowCode}` : undefined;
        const liveStat = statKey ? statsMap.get(statKey) : undefined;
        const isActive = selectedHallId === hall.id;
        return (
          <button
            key={hall.id}
            onClick={() => onSelectHall?.(hall.id)}
            className={clsx(
              'group relative w-full overflow-hidden rounded-3xl border px-5 py-4 text-left transition-all duration-200',
              isActive
                ? 'border-white bg-white text-black shadow-[0_28px_70px_rgba(5,5,7,0.45)]'
                : 'border-white/10 bg-[rgba(10,10,14,0.75)] text-white/80 hover:border-white/25 hover:text-white'
            )}
          >
            <div className="flex items-start justify-between gap-4">
              <div className="space-y-1">
                <p className={clsx('text-base font-semibold', isActive ? 'text-black' : 'text-white')}>{hall.name}</p>
                <p className={clsx('text-xs', isActive ? 'text-black/60' : 'text-white/50')}>{hall.address}</p>
                {windowCode && (
                  <p className={clsx('text-xs', isActive ? 'text-black/60' : 'text-white/60')}>
                    {windowLabels[windowCode]} window · {hall.isOpen ? 'Open' : 'Closed'}
                  </p>
                )}
              </div>
              <div className="flex flex-col items-end gap-2 text-xs">
                <span
                  className={clsx(
                    'inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-semibold',
                    hall.isOpen
                      ? isActive
                        ? 'bg-black/10 text-black'
                        : 'bg-[rgba(50,213,131,0.12)] text-[#32d583]'
                      : isActive
                        ? 'bg-black/10 text-black/70'
                        : 'bg-white/5 text-white/60'
                  )}
                >
                  <span className={clsx('h-2 w-2 rounded-full', hall.isOpen ? 'bg-[#32d583]' : 'bg-white/30')} />
                  {hall.isOpen ? 'Accepting orders' : 'Closed'}
                </span>
                {liveStat && <span className={clsx(isActive ? 'text-black/60' : 'text-white/60')}>{formatWait(liveStat.avgWaitMinutes)}</span>}
              </div>
            </div>
            <div
              className={clsx(
                'pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-200',
                isActive ? 'opacity-20 bg-[radial-gradient(circle_at_top,_rgba(0,0,0,0.2),_transparent)]' : 'group-hover:opacity-30 group-hover:bg-[radial-gradient(circle_at_top,_rgba(50,213,131,0.15),_transparent)]'
              )}
            />
          </button>
        );
      })}
    </div>
  );
};

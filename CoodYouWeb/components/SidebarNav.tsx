'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  MapPinIcon,
  QueueListIcon,
  WalletIcon,
  UserCircleIcon,
  AdjustmentsHorizontalIcon
} from '@heroicons/react/24/outline';
import { clsx } from 'clsx';

const navItems = [
  { href: '/dashboard', label: 'Dispatch', icon: MapPinIcon },
  { href: '/dasher', label: 'Dasher', icon: QueueListIcon },
  { href: '/wallet', label: 'Wallet', icon: WalletIcon },
  { href: '/profile', label: 'Profile', icon: UserCircleIcon },
  { href: '/admin', label: 'Admin', icon: AdjustmentsHorizontalIcon }
];

export const SidebarNav = () => {
  const pathname = usePathname();

  return (
    <aside className="surface-card--muted hidden w-[17rem] flex-shrink-0 flex-col justify-between border-r border-white/5 bg-[rgba(8,8,12,0.85)] px-7 py-8 lg:flex">
      <div className="space-y-8">
        <div className="flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-sm font-semibold text-black">CY</span>
          <div>
            <p className="text-xs uppercase tracking-[0.32em] text-white/60">CoodYou</p>
            <p className="text-lg font-semibold text-white">Campus Dispatch</p>
          </div>
        </div>
        <nav className="space-y-1.5">
          {navItems.map((item) => {
            const isActive = pathname === item.href || pathname?.startsWith(`${item.href}/`);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={clsx(
                  'group flex items-center justify-between rounded-2xl border px-4 py-3 text-sm transition-colors',
                  isActive
                    ? 'border-white text-black shadow-[0_12px_30px_rgba(5,5,7,0.25)] bg-white'
                    : 'border-white/5 bg-transparent text-white/70 hover:border-white/15 hover:text-white'
                )}
              >
                <span className="flex items-center gap-3">
                  <span
                    className={clsx(
                      'flex h-8 w-8 items-center justify-center rounded-xl border text-xs font-semibold transition-colors',
                      isActive ? 'border-black bg-black/10 text-black' : 'border-white/10 bg-white/5 text-white/70 group-hover:border-white/20'
                    )}
                  >
                    <Icon className={clsx('h-4 w-4', isActive ? 'text-black' : 'text-white/70 group-hover:text-white')} />
                  </span>
                  {item.label}
                </span>
                {isActive && <span className="h-2 w-2 rounded-full bg-black" />}
              </Link>
            );
          })}
        </nav>
      </div>
      <div className="space-y-4">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-5 text-xs text-white/70">
          Live for Columbia &amp; Barnard. Request early access for your campus and we will prioritise onboarding.
        </div>
        <p className="text-[10px] uppercase tracking-[0.28em] text-white/40">Built on Firebase • Powered by shared runs</p>
      </div>
    </aside>
  );
};

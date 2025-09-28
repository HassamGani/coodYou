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
    <aside className="hidden w-64 flex-shrink-0 flex-col gap-6 border-r border-white/10 bg-white/[0.02] p-6 lg:flex">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-brand.accent">CampusDash</p>
        <p className="mt-1 text-sm text-slate-400">DoorDash for Columbia &amp; Barnard dining halls.</p>
      </div>
      <nav className="space-y-2">
        {navItems.map((item) => {
          const isActive = pathname === item.href || pathname?.startsWith(`${item.href}/`);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={clsx(
                'flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-semibold transition',
                isActive
                  ? 'bg-brand.accent/15 text-brand.accent'
                  : 'text-slate-300 hover:bg-white/5 hover:text-white'
              )}
            >
              <Icon className="h-5 w-5" />
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="mt-auto rounded-2xl border border-brand.accent/30 bg-brand.accent/10 p-4 text-xs text-brand.accent">
        Live now for Columbia and Barnard. More campuses coming soon.
      </div>
    </aside>
  );
};

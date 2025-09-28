'use client';

import Image from 'next/image';
import { useAuth } from '@/hooks/useAuth';
import { clsx } from 'clsx';

export const TopBar = () => {
  const { profile, user, signOut } = useAuth();
  const role = profile?.activeRole ?? 'buyer';
  const campus = profile?.campus === 'barnard' ? 'Barnard College' : 'Columbia University';

  return (
    <header className="sticky top-0 z-20 flex items-center justify-between border-b border-white/5 bg-[rgba(8,8,12,0.8)] px-8 py-5 backdrop-blur-xl">
      <div className="space-y-1">
        <div className="flex items-center gap-3 text-xs font-semibold uppercase tracking-[0.32em] text-white/50">
          <span className="pill-control px-3 py-1">{campus}</span>
          <span className="flex items-center gap-2 text-[10px] tracking-[0.32em] text-white/40">
            Live network · {role === 'dasher' ? 'Dasher Control' : role === 'admin' ? 'Admin Console' : 'Dispatch Board'}
          </span>
        </div>
        <h1 className="text-3xl font-semibold text-white">{role === 'dasher' ? 'Claim, run, deliver.' : 'Coordinate campus runs effortlessly.'}</h1>
      </div>
      <div className="flex items-center gap-5">
        <div className="hidden text-right sm:block">
          <p className="text-sm font-semibold text-white">{profile?.displayName ?? user?.email}</p>
          <p className="text-xs text-white/50">{role[0].toUpperCase() + role.slice(1)} · {campus}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="h-11 w-11 overflow-hidden rounded-full border border-white/10 bg-white/5">
            {profile?.photoURL ? (
              <Image src={profile.photoURL} alt={profile.displayName} width={44} height={44} className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-sm font-semibold text-white/70">
                {profile?.displayName?.[0]?.toUpperCase() ?? user?.email?.[0]?.toUpperCase() ?? 'U'}
              </div>
            )}
          </div>
          <button
            onClick={() => signOut()}
            className={clsx(
              'rounded-full border border-white/10 px-5 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-white/80 transition',
              'hover:border-white hover:text-white'
            )}
          >
            Sign out
          </button>
        </div>
      </div>
    </header>
  );
};

'use client';

import Image from 'next/image';
import { useAuth } from '@/hooks/useAuth';
import { clsx } from 'clsx';

export const TopBar = () => {
  const { profile, user, signOut } = useAuth();

  return (
    <header className="sticky top-0 z-20 flex items-center justify-between border-b border-white/10 bg-slate-950/70 px-6 py-4 backdrop-blur">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.3em] text-slate-400">Live now</p>
        <h1 className="text-2xl font-semibold text-white">{profile?.activeRole === 'dasher' ? 'Dasher control tower' : 'Campus dispatch'}</h1>
      </div>
      <div className="flex items-center gap-4">
        <div className="hidden text-right text-xs text-slate-400 sm:block">
          <p className="text-sm font-semibold text-white">{profile?.displayName ?? user?.email}</p>
          <p>{profile?.campus === 'barnard' ? 'Barnard College' : 'Columbia University'}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 overflow-hidden rounded-full border border-white/20">
            {profile?.photoURL ? (
              <Image src={profile.photoURL} alt={profile.displayName} width={40} height={40} className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center bg-brand.accent/20 text-sm font-semibold text-brand.accent">
                {profile?.displayName?.[0]?.toUpperCase() ?? 'U'}
              </div>
            )}
          </div>
          <button
            onClick={() => signOut()}
            className={clsx(
              'rounded-full border border-white/15 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-slate-200 transition',
              'hover:border-brand.accent hover:text-brand.accent'
            )}
          >
            Sign out
          </button>
        </div>
      </div>
    </header>
  );
};

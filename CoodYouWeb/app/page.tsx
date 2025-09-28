'use client';

import Link from 'next/link';
import { ArrowRightIcon } from '@heroicons/react/24/outline';
import { useAuth } from '@/hooks/useAuth';

const features = [
  {
    title: 'Live hall heatmaps',
    description: 'See which Columbia or Barnard dining halls have active pools, pickup ETAs, and dasher supply in real time.'
  },
  {
    title: 'Pair-based savings',
    description: 'Split the dining swipe with another student automatically and pay just half the posted price plus 50¢.'
  },
  {
    title: 'Dash instantly',
    description: 'Enter a hall geofence and claim queued orders with one tap. Confirm pickup, share a PIN, and cash out.'
  }
];

export default function LandingPage() {
  const { user, loading } = useAuth();

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(50,213,131,0.18),_transparent_60%)]" />
      <div className="relative z-10 mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-10">
        <header className="flex items-center justify-between">
          <Link href="/" className="text-xl font-semibold tracking-tight text-white">
            CampusDash
          </Link>
          <nav className="flex items-center gap-3 text-sm text-slate-300">
            <Link href="#features" className="hover:text-white">
              Features
            </Link>
            <Link href="#pricing" className="hover:text-white">
              Pricing
            </Link>
            <Link href="#faq" className="hover:text-white">
              FAQ
            </Link>
            {!loading && user ? (
              <Link
                href="/dashboard"
                className="inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 text-sm font-semibold text-slate-900 shadow-lg shadow-slate-900/20"
              >
                Enter app
                <ArrowRightIcon className="h-4 w-4" />
              </Link>
            ) : (
              <Link
                href="/auth/sign-in"
                className="inline-flex items-center gap-2 rounded-full bg-brand.accent px-4 py-2 text-sm font-semibold text-slate-900 shadow-lg shadow-emerald-500/30"
              >
                Sign in
                <ArrowRightIcon className="h-4 w-4" />
              </Link>
            )}
          </nav>
        </header>

        <main className="grid flex-1 items-center gap-16 py-12 lg:grid-cols-2">
          <section className="space-y-8">
            <p className="inline-flex rounded-full border border-white/20 px-3 py-1 text-xs uppercase tracking-[0.28em] text-slate-300">
              Columbia &amp; Barnard exclusive
            </p>
            <h1 className="text-5xl font-semibold leading-tight text-white md:text-6xl">
              The fastest way to share a dining hall run.
            </h1>
            <p className="max-w-xl text-lg text-slate-300">
              CampusDash links students already inside the hall with nearby requests. Pay half, dash instantly, and manage runs
              like a pro delivery marketplace — built entirely on Firebase.
            </p>
            <div className="flex flex-wrap gap-3">
              <Link
                href={user ? '/dashboard' : '/auth/sign-up'}
                className="inline-flex items-center gap-2 rounded-full bg-brand.accent px-6 py-3 text-sm font-semibold text-slate-900 shadow-lg shadow-emerald-500/40"
              >
                {user ? 'Open dashboard' : 'Create campus account'}
                <ArrowRightIcon className="h-4 w-4" />
              </Link>
              <Link
                href="#features"
                className="inline-flex items-center gap-2 rounded-full border border-white/10 px-6 py-3 text-sm font-semibold text-white/80 hover:border-white/40 hover:text-white"
              >
                Explore features
              </Link>
            </div>
          </section>

          <section className="relative">
            <div className="absolute -inset-6 rounded-3xl bg-brand.accent/10 blur-3xl" />
            <div className="relative flex h-full w-full flex-col overflow-hidden rounded-3xl bg-white/5 shadow-panel backdrop-blur">
              <div className="flex items-center justify-between border-b border-white/10 px-6 py-4">
                <div>
                  <p className="text-xs uppercase tracking-[0.3em] text-white/60">Live hall pulse</p>
                  <p className="text-lg font-semibold text-white">Morningside network</p>
                </div>
                <span className="rounded-full bg-brand.accent/20 px-3 py-1 text-xs font-semibold text-brand.accent">
                  Online
                </span>
              </div>
              <div className="grid flex-1 grid-cols-2 gap-0 divide-x divide-white/5">
                <div className="space-y-5 px-6 py-6">
                  {['John Jay', 'Ferris Booth', 'JJ’s Place'].map((hall, idx) => (
                    <div key={hall} className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
                      <p className="text-sm font-medium text-white/90">{hall}</p>
                      <p className="text-xs text-slate-400">{idx === 0 ? '4 buyers waiting • 6m avg' : 'Pool forming'}</p>
                    </div>
                  ))}
                </div>
                <div className="flex flex-col justify-between px-6 py-6">
                  <div className="rounded-2xl border border-white/10 bg-slate-900/50 p-4 text-sm text-slate-300">
                    Tap into the dasher feed when you enter a hall. Claim a pooled run and follow turn-by-turn drop-off cards.
                  </div>
                  <div className="space-y-3 text-xs text-slate-400">
                    <p>• Stripe Express payouts hit minutes after delivery.</p>
                    <p>• PIN-based handoffs keep every run auditable.</p>
                    <p>• Admins can override pricing windows in real time.</p>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </main>

        <section id="features" className="grid gap-6 pb-16 sm:grid-cols-3">
          {features.map((feature) => (
            <div key={feature.title} className="rounded-3xl border border-white/10 bg-white/[0.03] p-6 shadow-panel">
              <h3 className="text-lg font-semibold text-white">{feature.title}</h3>
              <p className="mt-3 text-sm text-slate-300">{feature.description}</p>
            </div>
          ))}
        </section>
      </div>
    </div>
  );
}

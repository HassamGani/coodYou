'use client';

import Link from 'next/link';
import { ArrowRightIcon, PlayIcon } from '@heroicons/react/24/outline';
import { useAuth } from '@/hooks/useAuth';

const featureCards = [
  {
    title: 'Realtime marketplace map',
    description: 'Monitor hall saturation, dasher supply, and buyer wait times on an Uber-style control map.'
  },
  {
    title: 'Swipe pooling economics',
    description: 'Auto-match buyers already in queue so both students split a swipe and service fee instantly.'
  },
  {
    title: 'Dasher-grade tooling',
    description: 'Runs flow through claim, pickup, and PIN-based drop-off states with Stripe Express payouts.'
  },
  {
    title: 'Admin overrides',
    description: 'Adjust windows, push boosts, or pause halls in seconds without touching the codebase.'
  }
];

const howItWorks = [
  'Buyers request a pooled swipe and drop a meeting pin.',
  'Dashers walking into the hall claim runs from the live queue.',
  'Pickup is confirmed in-app, drop-off uses a one-time PIN, and payouts hit wallets instantly.'
];

export default function LandingPage() {
  const { user, loading } = useAuth();
  const primaryCtaHref = user ? '/dashboard' : '/auth/sign-up';
  const primaryCtaLabel = user ? 'Open dispatch' : 'Start pooling';

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="absolute inset-x-0 top-0 h-[520px] bg-[radial-gradient(120%_140%_at_20%_-20%,rgba(50,213,131,0.25),rgba(5,5,7,0))]" />
      <div className="relative z-10 mx-auto flex min-h-screen w-full max-w-6xl flex-col px-6 py-10 lg:px-10">
        <header className="flex items-center justify-between text-sm text-white/70">
          <Link href="/" className="flex items-center gap-2 text-white">
            <span className="flex h-9 w-9 items-center justify-center rounded-full bg-white text-sm font-semibold text-black">CY</span>
            <div className="leading-tight">
              <span className="text-xs uppercase tracking-[0.32em] text-white/60">CampusDash</span>
              <p className="text-base font-semibold text-white">CoodYou</p>
            </div>
          </Link>
          <nav className="hidden items-center gap-6 text-xs uppercase tracking-[0.32em] text-white/50 md:flex">
            <Link href="#product" className="hover:text-white">
              Product
            </Link>
            <Link href="#marketplace" className="hover:text-white">
              Marketplace
            </Link>
            <Link href="#build" className="hover:text-white">
              Build
            </Link>
            <Link href="#faq" className="hover:text-white">
              FAQ
            </Link>
          </nav>
          <div className="flex items-center gap-3">
            <Link href="/auth/sign-in" className="hidden text-xs uppercase tracking-[0.32em] text-white/60 hover:text-white md:block">
              Sign in
            </Link>
            <Link
              href={user ? '/dashboard' : '/auth/sign-in'}
              className="inline-flex items-center gap-2 rounded-full border border-white/12 px-4 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-white/80 transition hover:border-white hover:bg-white hover:text-black"
            >
              {user ? 'Dashboard' : 'Log in'}
            </Link>
          </div>
        </header>

        <main className="mt-16 grid flex-1 items-center gap-16 lg:grid-cols-[1.25fr_1fr]">
          <section className="space-y-8">
            <span className="pill-control inline-flex items-center gap-2 px-4 py-2 text-white/60">
              Columbia · Barnard · Powered by Firebase
            </span>
            <h1 className="text-4xl font-semibold leading-tight text-white md:text-[54px] md:leading-[1.05]">
              Uber-level dispatch for campus dining runs.
            </h1>
            <p className="max-w-xl text-lg text-white/60">
              CoodYou brings pooled-swipe logistics, dasher routing, and instant payouts into a single, Firebase-backed
              marketplace. Buyers split the swipe, dashers earn in minutes, and admins have full operational visibility.
            </p>
            <div className="flex flex-wrap items-center gap-4">
              <Link
                href={primaryCtaHref}
                className="inline-flex items-center gap-2 rounded-full bg-white px-6 py-3 text-sm font-semibold text-black shadow-[0_24px_55px_rgba(255,255,255,0.18)]"
              >
                {primaryCtaLabel}
                <ArrowRightIcon className="h-4 w-4" />
              </Link>
              <Link
                href={user ? '/dasher' : '/auth/sign-in'}
                className="inline-flex items-center gap-2 rounded-full border border-white/12 px-6 py-3 text-sm font-semibold text-white/80 transition hover:border-white hover:text-white"
              >
                View dasher console
              </Link>
              <button
                type="button"
                className="inline-flex items-center gap-2 rounded-full border border-white/12 px-5 py-3 text-sm font-semibold text-white/70 transition hover:border-white hover:text-white"
              >
                <PlayIcon className="h-4 w-4" /> Watch product flow
              </button>
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              {[
                ['3.4x', 'Faster pooled pickups'],
                ['<6m', 'Avg wait time'],
                ['45%', 'Swipe cost saved']
              ].map(([stat, label]) => (
                <div key={stat} className="surface-card--muted border border-white/10 p-4 text-sm text-white/60">
                  <p className="text-3xl font-semibold text-white">{stat}</p>
                  <p>{label}</p>
                </div>
              ))}
            </div>
          </section>

          <section className="relative">
            <div className="absolute -inset-6 rounded-[32px] bg-[radial-gradient(circle_at_top,_rgba(50,213,131,0.25),_transparent_60%)] blur-3xl" />
            <div className="surface-card relative flex h-full w-full flex-col overflow-hidden p-0">
              <div className="flex items-center justify-between border-b border-white/5 px-6 py-5">
                <div>
                  <p className="text-xs uppercase tracking-[0.32em] text-white/40">Dispatch snapshot</p>
                  <p className="text-lg font-semibold text-white">Morningside network</p>
                </div>
                <span className="rounded-full bg-white px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.28em] text-black">Live</span>
              </div>
              <div className="grid flex-1 grid-cols-2 divide-x divide-white/5">
                <div className="space-y-4 px-6 py-6">
                  {[
                    { name: 'John Jay Dining', wait: '5m wait', status: '4 buyers queued' },
                    { name: 'Ferris Booth', wait: '3m wait', status: 'Boost active' },
                    { name: 'JJ’s Place', wait: 'Pool forming', status: 'Dasher needed' }
                  ].map((hall) => (
                    <div key={hall.name} className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-white/80">
                      <p className="text-base font-semibold text-white">{hall.name}</p>
                      <p className="text-xs text-white/50">{hall.status}</p>
                      <p className="text-xs text-white/40">{hall.wait}</p>
                    </div>
                  ))}
                </div>
                <div className="flex flex-col justify-between px-6 py-6">
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-white/70">
                    Dashers check-in when entering the geofence. Claim runs, confirm pickup, drop with a one-time PIN, and
                    cash out through Stripe Express.
                  </div>
                  <div className="space-y-3 text-xs text-white/50">
                    <p>• Admins tweak service windows mid-rush.</p>
                    <p>• Buyer comms route through Firebase Messaging.</p>
                    <p>• Wallet balance updates in under a second.</p>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </main>

        <section id="product" className="mt-20 space-y-8">
          <div className="space-y-3">
            <span className="pill-control inline-flex px-4 py-2 text-white/60">Built like a modern mobility platform</span>
            <h2 className="text-3xl font-semibold text-white">Everything you expect from Uber, tuned for campus dining.</h2>
            <p className="text-lg text-white/60">A sleek dispatcher for buyers, a tight dasher workflow, and admin controls backed by Firebase.</p>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            {featureCards.map((feature) => (
              <div key={feature.title} className="surface-card--muted border border-white/8 p-6">
                <h3 className="text-lg font-semibold text-white">{feature.title}</h3>
                <p className="mt-3 text-sm text-white/50">{feature.description}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="marketplace" className="mt-20 grid gap-10 lg:grid-cols-[1.3fr_1fr]">
          <div className="space-y-6">
            <span className="pill-control inline-flex px-4 py-2 text-white/60">Marketplace loop</span>
            <h2 className="text-3xl font-semibold text-white">How the loop completes in minutes.</h2>
            <ul className="space-y-4 text-sm text-white/60">
              {howItWorks.map((item, index) => (
                <li key={item} className="flex items-start gap-4">
                  <span className="mt-0.5 inline-flex h-8 w-8 items-center justify-center rounded-full border border-white/15 text-xs font-semibold text-white/70">
                    {index + 1}
                  </span>
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
          <div className="surface-card p-6">
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Tech stack</p>
            <div className="mt-4 space-y-3 text-sm text-white/70">
              <p>• Next.js 14 app router with Tailwind styling.</p>
              <p>• Firebase Auth, Firestore, Functions, and Messaging for realtime operations.</p>
              <p>• Mapbox GL overlays tuned for campus usage.</p>
              <p>• Stripe Connect for dasher payouts.</p>
            </div>
            <Link
              href="/dashboard"
              className="mt-6 inline-flex items-center gap-2 rounded-full border border-white/12 px-5 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-white/70 transition hover:border-white hover:bg-white hover:text-black"
            >
              Explore dashboard
              <ArrowRightIcon className="h-4 w-4" />
            </Link>
          </div>
        </section>

        <section id="build" className="mt-20 grid gap-8 lg:grid-cols-2">
          <div className="surface-card p-6">
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Ready to build</p>
            <h3 className="mt-2 text-2xl font-semibold text-white">Same backend as the iOS app</h3>
            <p className="mt-2 text-sm text-white/60">
              The web client rides on the identical Cloud Functions, Firestore rules, and Stripe integration as the SwiftUI app.
              Clone the repo, drop in your Firebase config, and you are live.
            </p>
            <code className="mt-5 block rounded-2xl border border-white/10 bg-black/40 px-4 py-3 text-xs text-white/70">
              npm install && npm run dev
            </code>
          </div>
          <div className="surface-card p-6">
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Higher education focus</p>
            <h3 className="mt-2 text-2xl font-semibold text-white">Launching new campuses?</h3>
            <p className="mt-2 text-sm text-white/60">
              Swap in new hall data, update branding, and invite your dashers. The marketplace logic, run flow, and payments are
              already wired.
            </p>
            <Link
              href="mailto:hello@coodyou.app"
              className="mt-5 inline-flex items-center gap-2 rounded-full bg-white px-5 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-black shadow-[0_18px_45px_rgba(255,255,255,0.2)]"
            >
              Request launch kit
              <ArrowRightIcon className="h-4 w-4" />
            </Link>
          </div>
        </section>

        <section id="faq" className="mt-24 grid gap-6 border-t border-white/5 pt-12 text-sm text-white/60 lg:grid-cols-2">
          <div>
            <h3 className="text-2xl font-semibold text-white">FAQ</h3>
            <p className="mt-2 text-white/50">Everything you need to know before piloting on campus.</p>
          </div>
          <div className="space-y-5">
            <div>
              <h4 className="font-semibold text-white">Can I reuse my iOS Firebase project?</h4>
              <p className="mt-1">Yes. Drop the same public keys into `.env.local` and both clients stay in sync.</p>
            </div>
            <div>
              <h4 className="font-semibold text-white">Does dasher onboarding require Stripe?</h4>
              <p className="mt-1">Stripe Connect is optional for prototype runs—you can mock payouts while testing.</p>
            </div>
            <div>
              <h4 className="font-semibold text-white">Can we add another campus?</h4>
              <p className="mt-1">Absolutely. Seed new halls in Firestore and update the campus selector.</p>
            </div>
          </div>
        </section>

        <footer className="mt-16 flex flex-col items-center gap-3 border-t border-white/5 pt-10 text-xs text-white/40 sm:flex-row sm:justify-between">
          <p>© {new Date().getFullYear()} CoodYou. Built by students, for students.</p>
          <div className="flex items-center gap-4">
            <Link href="mailto:hello@coodyou.app" className="hover:text-white">
              Contact
            </Link>
            <Link href="/dashboard" className="hover:text-white">
              Launch dispatcher
            </Link>
          </div>
        </footer>
      </div>
    </div>
  );
}

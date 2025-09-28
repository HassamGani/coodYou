'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth';
import type { Campus } from '@/models/types';

const campuses: { value: Campus; label: string }[] = [
  { value: 'columbia', label: 'Columbia University' },
  { value: 'barnard', label: 'Barnard College' }
];

export default function SignUpPage() {
  const router = useRouter();
  const { signUpWithEmail } = useAuth();
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [campus, setCampus] = useState<Campus>('columbia');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      setIsLoading(true);
      await signUpWithEmail({ email, password, displayName, campus });
      router.replace('/dashboard');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <Link href="/" className="inline-flex items-center gap-2 text-sm text-slate-400 hover:text-white">
        <ArrowLeftIcon className="h-4 w-4" /> Back to site
      </Link>
      <div>
        <h1 className="text-2xl font-semibold text-white">Create your CampusDash account</h1>
        <p className="mt-1 text-sm text-slate-400">Only @columbia.edu and @barnard.edu emails are accepted for access.</p>
      </div>
      {error && <p className="rounded-xl border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-200">{error}</p>}
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-2">
          <label htmlFor="displayName" className="text-xs font-semibold uppercase tracking-wide text-slate-300">
            Full name
          </label>
          <input
            id="displayName"
            value={displayName}
            onChange={(event) => setDisplayName(event.target.value)}
            required
            className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus:border-brand.accent focus:outline-none"
          />
        </div>
        <div className="space-y-2">
          <label htmlFor="email" className="text-xs font-semibold uppercase tracking-wide text-slate-300">
            Email
          </label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
            className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus:border-brand.accent focus:outline-none"
          />
        </div>
        <div className="space-y-2">
          <label htmlFor="password" className="text-xs font-semibold uppercase tracking-wide text-slate-300">
            Password
          </label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
            className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus:border-brand.accent focus:outline-none"
          />
        </div>
        <div className="space-y-2">
          <span className="text-xs font-semibold uppercase tracking-wide text-slate-300">Campus</span>
          <div className="grid grid-cols-2 gap-2">
            {campuses.map((campusOption) => (
              <button
                key={campusOption.value}
                type="button"
                onClick={() => setCampus(campusOption.value)}
                className={`rounded-2xl border px-4 py-3 text-sm font-semibold transition ${
                  campus === campusOption.value
                    ? 'border-brand.accent bg-brand.accent/10 text-brand.accent'
                    : 'border-white/10 bg-white/5 text-slate-200 hover:border-white/30'
                }`}
              >
                {campusOption.label}
              </button>
            ))}
          </div>
        </div>
        <button
          type="submit"
          disabled={isLoading}
          className="w-full rounded-2xl bg-brand.accent px-4 py-3 text-sm font-semibold text-slate-900 shadow-lg shadow-emerald-500/40 disabled:cursor-not-allowed disabled:opacity-70"
        >
          {isLoading ? 'Creating account…' : 'Continue'}
        </button>
      </form>
      <p className="text-sm text-slate-400">
        Already have an account?{' '}
        <Link href="/auth/sign-in" className="font-semibold text-white hover:text-brand.accent">
          Sign in
        </Link>
      </p>
    </div>
  );
}

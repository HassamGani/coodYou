'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth';

export default function SignInPage() {
  const router = useRouter();
  const { signInWithEmail, signInWithGoogle, signInWithApple } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleEmailSignIn = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      setIsLoading(true);
      await signInWithEmail(email, password);
      router.replace('/dashboard');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleProvider = async (provider: 'google' | 'apple') => {
    try {
      setIsLoading(true);
      if (provider === 'google') {
        await signInWithGoogle();
      } else {
        await signInWithApple();
      }
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
        <h1 className="text-2xl font-semibold text-white">Welcome back</h1>
        <p className="mt-1 text-sm text-slate-400">Sign in with your @columbia.edu or @barnard.edu email address.</p>
      </div>
      {error && <p className="rounded-xl border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-200">{error}</p>}
      <form onSubmit={handleEmailSignIn} className="space-y-4">
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
        <button
          type="submit"
          disabled={isLoading}
          className="w-full rounded-2xl bg-brand.accent px-4 py-3 text-sm font-semibold text-slate-900 shadow-lg shadow-emerald-500/40 disabled:cursor-not-allowed disabled:opacity-70"
        >
          {isLoading ? 'Signing in…' : 'Continue'}
        </button>
      </form>
      <div className="space-y-3">
        <button
          onClick={() => handleProvider('google')}
          className="w-full rounded-2xl border border-white/15 px-4 py-3 text-sm font-semibold text-white hover:border-brand.accent/50"
        >
          Sign in with Google
        </button>
        <button
          onClick={() => handleProvider('apple')}
          className="w-full rounded-2xl border border-white/15 px-4 py-3 text-sm font-semibold text-white hover:border-brand.accent/50"
        >
          Sign in with Apple
        </button>
      </div>
      <p className="text-sm text-slate-400">
        New to CampusDash?{' '}
        <Link href="/auth/sign-up" className="font-semibold text-white hover:text-brand.accent">
          Create an account
        </Link>
      </p>
    </div>
  );
}

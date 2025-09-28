'use client';

import { useState } from 'react';
import type { UserProfile } from '@/models/types';
import { updateProfile } from '@/services/profileService';
import { useAuth } from '@/hooks/useAuth';

interface ProfileSettingsProps {
  profile?: UserProfile | null;
}

export const ProfileSettings = ({ profile }: ProfileSettingsProps) => {
  const { updateNotificationPrefs, setActiveRole } = useAuth();
  const [status, setStatus] = useState<string | null>(null);

  if (!profile) {
    return <p className="text-sm text-slate-400">Sign in to manage your profile.</p>;
  }

  const notifications = profile.notificationPreferences ?? {
    inHall: true,
    nearHall: true,
    marketing: false
  };

  const handleRoleChange = async (role: UserProfile['activeRole']) => {
    await setActiveRole(role);
    setStatus(`Role updated to ${role}.`);
  };

  const handleNotificationToggle = async (key: keyof typeof notifications) => {
    const updated = { ...notifications, [key]: !notifications[key] };
    await updateNotificationPrefs(updated);
    setStatus('Notification preferences saved.');
  };

  const handlePhoneUpdate = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const phone = formData.get('phone')?.toString();
    await updateProfile(profile.id, { phoneNumber: phone ?? undefined });
    setStatus('Phone number saved.');
  };

  return (
    <div className="space-y-6">
      <section className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
        <h3 className="text-lg font-semibold text-white">Active role</h3>
        <div className="mt-4 flex gap-3">
          {['buyer', 'dasher', 'admin'].map((role) => (
            <button
              key={role}
              onClick={() => handleRoleChange(role as UserProfile['activeRole'])}
              className={`rounded-2xl border px-4 py-2 text-xs font-semibold uppercase tracking-wide transition ${
                profile.activeRole === role
                  ? 'border-brand.accent bg-brand.accent/10 text-brand.accent'
                  : 'border-white/15 text-slate-200 hover:border-white/30'
              }`}
            >
              {role}
            </button>
          ))}
        </div>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
        <h3 className="text-lg font-semibold text-white">Notification settings</h3>
        <div className="mt-4 space-y-3">
          <label className="flex items-center justify-between text-sm text-slate-300">
            Notify me when I enter a hall with open runs
            <input type="checkbox" checked={notifications.inHall} onChange={() => handleNotificationToggle('inHall')} />
          </label>
          <label className="flex items-center justify-between text-sm text-slate-300">
            Alert me when I am within 150m of a hall
            <input type="checkbox" checked={notifications.nearHall} onChange={() => handleNotificationToggle('nearHall')} />
          </label>
          <label className="flex items-center justify-between text-sm text-slate-300">
            Send me platform updates
            <input type="checkbox" checked={notifications.marketing} onChange={() => handleNotificationToggle('marketing')} />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
        <h3 className="text-lg font-semibold text-white">Contact info</h3>
        <form onSubmit={handlePhoneUpdate} className="mt-4 space-y-3">
          <div className="space-y-2">
            <label htmlFor="phone" className="text-xs font-semibold uppercase tracking-wide text-slate-300">
              Phone number
            </label>
            <input
              id="phone"
              name="phone"
              defaultValue={profile.phoneNumber}
              className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus:border-brand.accent focus:outline-none"
            />
          </div>
          <button type="submit" className="rounded-full bg-brand.accent px-5 py-2 text-xs font-semibold uppercase tracking-wide text-slate-900 shadow-lg shadow-emerald-500/40">
            Save
          </button>
        </form>
      </section>

      {status && <p className="text-xs text-slate-300">{status}</p>}
    </div>
  );
};

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
      <section className="surface-card p-6">
        <p className="text-xs uppercase tracking-[0.32em] text-white/40">Active role</p>
        <div className="mt-4 flex gap-3">
          {['buyer', 'dasher', 'admin'].map((role) => (
            <button
              key={role}
              onClick={() => handleRoleChange(role as UserProfile['activeRole'])}
              className={`rounded-full border px-4 py-2 text-xs font-semibold uppercase tracking-[0.24em] transition ${
                profile.activeRole === role
                  ? 'border-white bg-white text-black shadow-[0_16px_40px_rgba(5,5,7,0.4)]'
                  : 'border-white/12 text-white/70 hover:border-white hover:text-white'
              }`}
            >
              {role}
            </button>
          ))}
        </div>
      </section>

      <section className="surface-card p-6">
        <p className="text-xs uppercase tracking-[0.32em] text-white/40">Notification settings</p>
        <div className="mt-4 space-y-4 text-sm text-white/70">
          {(
            [
              ['Notify me when I enter a hall with open runs', 'inHall'],
              ['Alert me when I am within 150m of a hall', 'nearHall'],
              ['Send me platform updates', 'marketing']
            ] as Array<[string, keyof typeof notifications]>
          ).map(([label, key]) => (
            <label key={key} className="flex items-center justify-between gap-6">
              <span>{label}</span>
              <input
                type="checkbox"
                checked={Boolean(notifications[key])}
                onChange={() => handleNotificationToggle(key)}
                className="h-5 w-5 rounded border-white/15 bg-transparent text-[#32d583] focus:ring-[#32d583]"
              />
            </label>
          ))}
        </div>
      </section>

      <section className="surface-card p-6">
        <p className="text-xs uppercase tracking-[0.32em] text-white/40">Contact info</p>
        <form onSubmit={handlePhoneUpdate} className="mt-4 space-y-3">
          <div className="space-y-2">
            <label htmlFor="phone" className="text-xs font-semibold uppercase tracking-[0.28em] text-white/50">
              Phone number
            </label>
            <input
              id="phone"
              name="phone"
              defaultValue={profile.phoneNumber}
              className="w-full rounded-2xl border border-white/10 bg-[rgba(255,255,255,0.03)] px-4 py-3 text-sm text-white placeholder:text-white/30 focus:border-white focus:outline-none"
            />
          </div>
          <button
            type="submit"
            className="rounded-full border border-white/12 px-5 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-white/80 transition hover:border-white hover:bg-white hover:text-black"
          >
            Save
          </button>
        </form>
      </section>

      {status && <p className="text-xs text-white/60">{status}</p>}
    </div>
  );
};

'use client';

import { ProfileSettings } from '@/components/ProfileSettings';
import { useAuth } from '@/hooks/useAuth';

export default function ProfilePage() {
  const { profile } = useAuth();

  return (
    <div className="space-y-6">
      <section className="surface-card p-6">
        <p className="text-xs uppercase tracking-[0.32em] text-white/40">Profile &amp; settings</p>
        <h2 className="mt-1 text-2xl font-semibold text-white">Curate your CampusDash experience</h2>
        <p className="text-xs text-white/55">Update preferences, switch roles, and keep your contact details current.</p>
      </section>
      <ProfileSettings profile={profile} />
    </div>
  );
}

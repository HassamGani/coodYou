'use client';

import { ProfileSettings } from '@/components/ProfileSettings';
import { useAuth } from '@/hooks/useAuth';

export default function ProfilePage() {
  const { profile } = useAuth();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-semibold text-white">Profile &amp; settings</h2>
        <p className="text-sm text-slate-400">Control notification preferences, update your contact info, and switch roles.</p>
      </div>
      <ProfileSettings profile={profile} />
    </div>
  );
}

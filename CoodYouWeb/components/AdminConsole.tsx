'use client';

import { useState } from 'react';
import type { DiningHall, ServiceWindowCode } from '@/models/types';
import { doc, serverTimestamp, updateDoc, setDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';

interface AdminConsoleProps {
  halls: DiningHall[];
}

const windowLabels: Record<ServiceWindowCode, string> = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner'
};

export const AdminConsole = ({ halls }: AdminConsoleProps) => {
  const [status, setStatus] = useState<string | null>(null);

  const handleOverride = async (hallId: string, windowCode: ServiceWindowCode) => {
    const newStart = prompt(`New start time for ${windowLabels[windowCode]} at ${hallId} (HH:MM)`);
    const newEnd = prompt(`New end time for ${windowLabels[windowCode]} at ${hallId} (HH:MM)`);
    if (!newStart || !newEnd) return;
    const ref = doc(db, 'dining_halls', hallId, 'overrides', windowCode);
    await updateDoc(doc(db, 'dining_halls', hallId), { updatedAt: serverTimestamp() });
    await setDoc(ref, { start: newStart, end: newEnd, updatedAt: serverTimestamp() }, { merge: true });
    setStatus('Override saved. Clients will respect the updated window.');
  };

  return (
    <div className="space-y-6">
      <section className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
        <h3 className="text-lg font-semibold text-white">Dining halls</h3>
        <p className="text-xs text-slate-400">Toggle service windows or adjust pricing on the fly.</p>
        <div className="mt-4 space-y-3">
          {halls.map((hall) => (
            <div key={hall.id} className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-white">{hall.name}</p>
                  <p className="text-xs text-slate-400">{hall.isOpen ? 'Open' : 'Closed'}</p>
                </div>
                <div className="flex gap-2">
                  {(Object.keys(windowLabels) as ServiceWindowCode[]).map((code) => (
                    <button
                      key={code}
                      onClick={() => handleOverride(hall.id, code)}
                      className="rounded-full border border-white/15 px-3 py-1 text-xs uppercase tracking-wide text-slate-200 hover:border-brand.accent hover:text-brand.accent"
                    >
                      {windowLabels[code]}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>
      {status && <p className="text-xs text-slate-300">{status}</p>}
    </div>
  );
};

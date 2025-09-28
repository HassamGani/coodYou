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
      <section className="surface-card p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.32em] text-white/40">Dining halls</p>
            <h3 className="text-lg font-semibold text-white">Override service windows</h3>
            <p className="text-xs text-white/50">Update active windows mid-service to rebalance pools.</p>
          </div>
        </div>
        <div className="mt-5 space-y-3">
          {halls.map((hall) => (
            <div key={hall.id} className="rounded-2xl border border-white/12 bg-white/5 p-4 text-sm text-white/80">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-white">{hall.name}</p>
                  <p className="text-xs text-white/45">{hall.isOpen ? 'Open' : 'Closed'}</p>
                </div>
                <div className="flex gap-2">
                  {(Object.keys(windowLabels) as ServiceWindowCode[]).map((code) => (
                    <button
                      key={code}
                      onClick={() => handleOverride(hall.id, code)}
                      className="rounded-full border border-white/12 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.24em] text-white/70 transition hover:border-white hover:bg-white hover:text-black"
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
      {status && <p className="text-xs text-white/60">{status}</p>}
    </div>
  );
};

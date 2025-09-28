import { collection, limit, orderBy, query, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '@/lib/firebase';
import type { Run } from '@/models/types';

const runsRef = collection(db, 'runs');

export const runsForDasherQuery = (dasherId: string) =>
  query(runsRef, where('dasherId', '==', dasherId), orderBy('createdAt', 'desc'), limit(10));

export const availableRunsQuery = (hallId?: string) => {
  if (hallId) {
    return query(
      runsRef,
      where('hallId', '==', hallId),
      where('status', '==', 'readyToAssign'),
      orderBy('createdAt', 'desc'),
      limit(10)
    );
  }
  return query(runsRef, where('status', '==', 'readyToAssign'), orderBy('createdAt', 'desc'), limit(10));
};

export const claimRun = async (runId: string) => {
  const callable = httpsCallable(functions, 'claimRun');
  await callable({ runId });
};

export const markPickedUp = async (runId: string) => {
  const callable = httpsCallable(functions, 'markPickedUp');
  await callable({ runId });
};

export const markDelivered = async (runId: string, pin: string) => {
  const callable = httpsCallable(functions, 'markDelivered');
  await callable({ runId, pin });
};

export const formatRun = (run: Run) => run;

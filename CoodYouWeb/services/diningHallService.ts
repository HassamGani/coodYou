import { collection, doc, getDoc, getDocs, orderBy, query } from 'firebase/firestore';
import type { DiningHall, LivePoolStat } from '@/models/types';
import { db } from '@/lib/firebase';

const hallsCollection = collection(db, 'dining_halls');

export const fetchDiningHalls = async (): Promise<DiningHall[]> => {
  const snapshot = await getDocs(query(hallsCollection, orderBy('name')));
  return snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() })) as DiningHall[];
};

export const fetchDiningHall = async (id: string): Promise<DiningHall | null> => {
  const ref = doc(hallsCollection, id);
  const snapshot = await getDoc(ref);
  if (!snapshot.exists()) return null;
  return { id: snapshot.id, ...snapshot.data() } as DiningHall;
};

export const fetchLivePoolStats = async (): Promise<LivePoolStat[]> => {
  const statsRef = collection(db, 'analytics', 'matching', 'pools');
  const snapshot = await getDocs(statsRef);
  return snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() })) as LivePoolStat[];
};

'use client';

import { doc, serverTimestamp, updateDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import type { UserProfile } from '@/models/types';

export const updateProfile = async (profileId: string, data: Partial<UserProfile>) => {
  const ref = doc(db, 'users', profileId);
  await updateDoc(ref, { ...data, updatedAt: serverTimestamp() });
};

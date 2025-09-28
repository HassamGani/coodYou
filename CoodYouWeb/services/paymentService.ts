'use client';

import { addDoc, collection, limit, orderBy, query, serverTimestamp, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '@/lib/firebase';
import type { PaymentMethod } from '@/models/types';

const paymentMethodsRef = collection(db, 'payment_methods');
const paymentsRef = collection(db, 'payments');

export const paymentMethodsQuery = (userId: string) =>
  query(paymentMethodsRef, where('userId', '==', userId), orderBy('isDefault', 'desc'));

export const paymentsForUserQuery = (userId: string) =>
  query(paymentsRef, where('buyerIds', 'array-contains', userId), orderBy('createdAt', 'desc'), limit(20));

export const payoutsForDasherQuery = (userId: string) =>
  query(paymentsRef, where('dasherId', '==', userId), orderBy('createdAt', 'desc'), limit(20));

export const linkStripeAccount = async (userId: string) => {
  const callable = httpsCallable(functions, 'requestStripeOnboarding');
  return callable({ uid: userId });
};

export const createPaymentMethod = async (method: PaymentMethod & { userId: string }) => {
  await addDoc(paymentMethodsRef, {
    ...method,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  });
};

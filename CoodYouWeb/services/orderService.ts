'use client';

import {
  Timestamp,
  addDoc,
  collection,
  doc,
  getDoc,
  limit,
  orderBy,
  query,
  serverTimestamp,
  where
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '@/lib/firebase';
import type { Order, ServiceWindowCode } from '@/models/types';

const ordersRef = collection(db, 'orders');

const windowPriceField: Record<ServiceWindowCode, string> = {
  breakfast: 'price_breakfast',
  lunch: 'price_lunch',
  dinner: 'price_dinner'
};

const computeBuyerPriceCents = (basePriceDollars: number) => {
  return Math.round((basePriceDollars / 2 + 0.5) * 100);
};

export interface CreateOrderParams {
  userId: string;
  hallId: string;
  windowCode: ServiceWindowCode;
  pickupNotes?: string;
  meetingPoint?: string;
}

export const createOrder = async ({ userId, hallId, windowCode, pickupNotes, meetingPoint }: CreateOrderParams) => {
  const hallDoc = await getDoc(doc(db, 'dining_halls', hallId));
  if (!hallDoc.exists()) {
    throw new Error('Dining hall not found');
  }
  const basePrice = hallDoc.get(windowPriceField[windowCode]);
  const priceCents = computeBuyerPriceCents(Number(basePrice));

  const newOrder = await addDoc(ordersRef, {
    userId,
    hallId,
    windowType: windowCode,
    status: 'requested',
    priceCents,
    meetingPoint: meetingPoint ?? null,
    pickupNotes: pickupNotes ?? null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  });

  const queueOrder = httpsCallable(functions, 'queueOrder');
  await queueOrder({ orderId: newOrder.id });

  return newOrder.id;
};

export const cancelOrder = async (orderId: string) => {
  const callable = httpsCallable(functions, 'cancelOrder');
  await callable({ orderId });
};

export const ordersForUserQuery = (userId: string) =>
  query(ordersRef, where('userId', '==', userId), orderBy('createdAt', 'desc'), limit(10));

export const activeOrdersQuery = () =>
  query(ordersRef, where('status', 'in', ['requested', 'pooled', 'readyToAssign', 'claimed', 'inProgress']));

export const historicalOrdersQuery = (userId: string) =>
  query(ordersRef, where('userId', '==', userId), orderBy('createdAt', 'desc'), limit(50));

export const formatOrder = (data: Order) => {
  const createdAt = 'createdAt' in data ? (data as unknown as { createdAt: Timestamp }).createdAt : undefined;
  return {
    ...data,
    createdAt: createdAt ? createdAt.toMillis() : Date.now()
  } as Order;
};

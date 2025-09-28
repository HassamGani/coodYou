export type Campus = 'columbia' | 'barnard';

export interface DiningHall {
  id: string;
  name: string;
  campus: Campus;
  address: string;
  latitude: number;
  longitude: number;
  isOpen: boolean;
  nextWindow?: string;
  activeWindowId?: string;
  serviceWindows: Record<ServiceWindowCode, ServiceWindow>;
  price_breakfast?: number;
  price_lunch?: number;
  price_dinner?: number;
}

export type ServiceWindowCode = 'breakfast' | 'lunch' | 'dinner';

export interface ServiceWindow {
  id: string;
  code: ServiceWindowCode;
  label: string;
  startTimeMinutes: number;
  endTimeMinutes: number;
  overrideDates?: Record<string, { start: string; end: string }>;
}

export type OrderStatus =
  | 'requested'
  | 'pooled'
  | 'readyToAssign'
  | 'claimed'
  | 'inProgress'
  | 'delivered'
  | 'paid'
  | 'closed'
  | 'expired'
  | 'cancelledBuyer'
  | 'cancelledDasher'
  | 'disputed';

export interface Order {
  id: string;
  userId: string;
  hallId: string;
  windowCode: ServiceWindowCode;
  status: OrderStatus;
  priceCents: number;
  createdAt: number;
  updatedAt: number;
  pickupNotes?: string;
  meetingPoint?: string;
  pairGroupId?: string;
  pinCode?: string;
}

export interface Run {
  id: string;
  hallId: string;
  pairGroupId: string;
  dasherId: string;
  status: 'readyToAssign' | 'claimed' | 'inProgress' | 'delivered' | 'paid' | 'closed';
  claimedAt: number;
  pickedUpAt?: number;
  deliveredAt?: number;
  payoutCents?: number;
  buyerOrderIds: string[];
  deliveryPin?: string;
}

export interface PaymentMethod {
  id: string;
  type: 'apple_pay' | 'card' | 'paypal' | 'cashapp' | 'stripe';
  displayName: string;
  lastFour?: string;
  isDefault: boolean;
  userId?: string;
}

export interface UserProfile {
  id: string;
  email: string;
  displayName: string;
  campus: Campus;
  phoneNumber?: string;
  photoURL?: string;
  rating?: number;
  totalRuns?: number;
  totalOrders?: number;
  stripeAccountStatus?: 'pending' | 'verified' | 'restricted';
  notificationPreferences?: {
    inHall: boolean;
    nearHall: boolean;
    marketing: boolean;
  };
  walletBalanceCents?: number;
  defaultPaymentMethodId?: string;
  activeRole?: 'buyer' | 'dasher' | 'admin';
}

export interface LivePoolStat {
  hallId: string;
  windowCode: ServiceWindowCode;
  waitingCount: number;
  avgWaitMinutes: number;
}

export interface MeetPoint {
  label: string;
  latitude: number;
  longitude: number;
}

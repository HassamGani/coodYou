'use client';

import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import {
  GoogleAuthProvider,
  OAuthProvider,
  User,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendEmailVerification,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut as firebaseSignOut,
  updateProfile
} from 'firebase/auth';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';
import type { Campus, UserProfile } from '@/models/types';

interface AuthContextValue {
  user: User | null;
  profile: UserProfile | null;
  loading: boolean;
  signInWithEmail: (email: string, password: string) => Promise<void>;
  signUpWithEmail: (params: { email: string; password: string; displayName: string; campus: Campus }) => Promise<void>;
  signInWithGoogle: () => Promise<void>;
  signInWithApple: () => Promise<void>;
  signOut: () => Promise<void>;
  updateNotificationPrefs: (prefs: UserProfile['notificationPreferences']) => Promise<void>;
  setActiveRole: (role: UserProfile['activeRole']) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const ALLOWED_DOMAINS = ['columbia.edu', 'barnard.edu'];

const isEduEmail = (email: string) => {
  const domain = email.split('@')[1]?.toLowerCase();
  return domain ? ALLOWED_DOMAINS.includes(domain) : false;
};

async function ensureProfile(user: User, campusHint?: Campus) {
  const ref = doc(db, 'users', user.uid);
  const snapshot = await getDoc(ref);
  const email = user.email ?? '';
  if (!isEduEmail(email)) {
    throw new Error('A Columbia or Barnard email is required.');
  }

  if (!snapshot.exists()) {
    const campus: Campus = campusHint ?? (email.endsWith('@barnard.edu') ? 'barnard' : 'columbia');
    const profile: UserProfile = {
      id: user.uid,
      email,
      displayName: user.displayName ?? email.split('@')[0],
      campus,
      notificationPreferences: {
        inHall: true,
        nearHall: true,
        marketing: false
      },
      walletBalanceCents: 0,
      totalOrders: 0,
      totalRuns: 0,
      activeRole: 'buyer'
    };

    await setDoc(ref, { ...profile, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
    return profile;
  }

  return snapshot.data() as UserProfile;
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (!firebaseUser) {
        setUser(null);
        setProfile(null);
        setLoading(false);
        return;
      }

      try {
        const ensuredProfile = await ensureProfile(firebaseUser);
        setUser(firebaseUser);
        setProfile(ensuredProfile);
      } catch (err) {
        console.error(err);
        await firebaseSignOut(auth);
        setUser(null);
        setProfile(null);
      } finally {
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const signInWithEmail = async (email: string, password: string) => {
    if (!isEduEmail(email)) throw new Error('Use your @columbia.edu or @barnard.edu email.');
    await signInWithEmailAndPassword(auth, email, password);
  };

  const signUpWithEmail = async ({ email, password, displayName, campus }: { email: string; password: string; displayName: string; campus: Campus }) => {
    if (!isEduEmail(email)) throw new Error('Use your @columbia.edu or @barnard.edu email.');
    const credentials = await createUserWithEmailAndPassword(auth, email, password);
    if (credentials.user && displayName) {
      await updateProfile(credentials.user, { displayName });
    }
    await ensureProfile(credentials.user, campus);
    await sendEmailVerification(credentials.user);
  };

  const signInWithGoogle = async () => {
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ hd: 'columbia.edu' });
    const { user: googleUser } = await signInWithPopup(auth, provider);
    const email = googleUser.email ?? '';
    if (!isEduEmail(email)) {
      await firebaseSignOut(auth);
      throw new Error('Google account must be a Columbia or Barnard email.');
    }
    await ensureProfile(googleUser);
  };

  const signInWithApple = async () => {
    const provider = new OAuthProvider('apple.com');
    provider.addScope('email');
    provider.addScope('name');
    const { user: appleUser } = await signInWithPopup(auth, provider);
    const email = appleUser.email ?? profile?.email ?? '';
    if (!isEduEmail(email)) {
      await firebaseSignOut(auth);
      throw new Error('Apple ID must share a Columbia or Barnard email.');
    }
    await ensureProfile(appleUser);
  };

  const signOut = async () => {
    await firebaseSignOut(auth);
    setProfile(null);
  };

  const updateNotificationPrefs = async (prefs: UserProfile['notificationPreferences']) => {
    if (!user) return;
    const ref = doc(db, 'users', user.uid);
    await updateDoc(ref, { notificationPreferences: prefs, updatedAt: serverTimestamp() });
    setProfile((prev) => (prev ? { ...prev, notificationPreferences: prefs } : prev));
  };

  const setActiveRole = async (role: UserProfile['activeRole']) => {
    if (!user) return;
    const ref = doc(db, 'users', user.uid);
    await updateDoc(ref, { activeRole: role, updatedAt: serverTimestamp() });
    setProfile((prev) => (prev ? { ...prev, activeRole: role } : prev));
  };

  const value = useMemo(
    () => ({
      user,
      profile,
      loading,
      signInWithEmail,
      signUpWithEmail,
      signInWithGoogle,
      signInWithApple,
      signOut,
      updateNotificationPrefs,
      setActiveRole
    }),
    [loading, profile, user]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
};

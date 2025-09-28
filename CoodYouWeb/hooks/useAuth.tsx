'use client';

import React, { createContext, useContext, useEffect, useMemo, useState, useCallback } from 'react';
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
  // If a profile already exists, return it.
  if (snapshot.exists()) {
    return snapshot.data() as UserProfile;
  }

  // For edu emails, determine campus (or use campusHint). For non-edu emails, omit campus entirely.
  const isEdu = isEduEmail(email);
  const campus: Campus | undefined = isEdu ? (campusHint ?? (email.endsWith('@barnard.edu') ? 'barnard' : 'columbia')) : undefined;

  const profile: UserProfile = {
    id: user.uid,
    email,
    displayName: user.displayName ?? email.split('@')[0],
    // campus is optional in the type; include only when known
    ...(campus ? { campus } : {}),
    notificationPreferences: {
      inHall: true,
      nearHall: true,
      marketing: false
    },
    walletBalanceCents: 0,
    totalOrders: 0,
    totalRuns: 0,
    activeRole: 'buyer'
  } as UserProfile;

  await setDoc(ref, { ...profile, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
  return profile;
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

  const signInWithEmail = useCallback(async (email: string, password: string) => {
    // Allow non-edu emails; profiles for those accounts will not have a campus.
    await signInWithEmailAndPassword(auth, email, password);
  }, []);

  const signUpWithEmail = useCallback(async ({ email, password, displayName, campus }: { email: string; password: string; displayName: string; campus: Campus }) => {
    // Allow non-edu emails to register; for non-edu accounts the provided campus will be ignored and the stored profile will omit campus.
    const credentials = await createUserWithEmailAndPassword(auth, email, password);
    if (credentials.user && displayName) {
      await updateProfile(credentials.user, { displayName });
    }
    // Only pass campus hint to ensureProfile for edu emails
    await ensureProfile(credentials.user, isEduEmail(email) ? campus : undefined);
    await sendEmailVerification(credentials.user);
  }, []);

  const signInWithGoogle = useCallback(async () => {
    const provider = new GoogleAuthProvider();
    // Don't force the hosted domain param here; allow any Google account.
    const { user: googleUser } = await signInWithPopup(auth, provider);
    const email = googleUser.email ?? '';
    // For edu emails, we'll pass no campus hint since backend will resolve authority; non-edu accounts will just get a profile without campus.
    await ensureProfile(googleUser, isEduEmail(email) ? undefined : undefined);
  }, []);

  const signInWithApple = useCallback(async () => {
    const provider = new OAuthProvider('apple.com');
    provider.addScope('email');
    provider.addScope('name');
    const { user: appleUser } = await signInWithPopup(auth, provider);
    const email = appleUser.email ?? profile?.email ?? '';
    // Allow Apple IDs without edu emails; ensureProfile will omit campus for those accounts.
    await ensureProfile(appleUser, isEduEmail(email) ? undefined : undefined);
  }, [profile]);

  const signOut = useCallback(async () => {
    await firebaseSignOut(auth);
    setProfile(null);
  }, []);

  const updateNotificationPrefs = useCallback(async (prefs: UserProfile['notificationPreferences']) => {
    if (!user) return;
    const ref = doc(db, 'users', user.uid);
    await updateDoc(ref, { notificationPreferences: prefs, updatedAt: serverTimestamp() });
    setProfile((prev) => (prev ? { ...prev, notificationPreferences: prefs } : prev));
  }, [user]);

  const setActiveRole = useCallback(async (role: UserProfile['activeRole']) => {
    if (!user) return;
    const ref = doc(db, 'users', user.uid);
    await updateDoc(ref, { activeRole: role, updatedAt: serverTimestamp() });
    setProfile((prev) => (prev ? { ...prev, activeRole: role } : prev));
  }, [user]);

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
    [loading, profile, user, signInWithEmail, signUpWithEmail, signInWithGoogle, signInWithApple, signOut, updateNotificationPrefs, setActiveRole]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
};

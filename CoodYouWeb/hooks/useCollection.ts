'use client';

import { Query, onSnapshot } from 'firebase/firestore';
import { useEffect, useState } from 'react';

type FirestoreQuery<T> = Query<T>;

export const useCollection = <T,>(query: FirestoreQuery<T> | null | undefined) => {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!query) {
      setData([]);
      setLoading(false);
      return () => undefined;
    }
    setLoading(true);
    const unsubscribe = onSnapshot(
      query,
      (snapshot) => {
        const result = snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() }) as T);
        setData(result);
        setLoading(false);
      },
      (err) => {
        console.error(err);
        setError(err as Error);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [query]);

  return { data, loading, error };
};

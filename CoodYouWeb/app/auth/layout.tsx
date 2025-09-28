import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'CampusDash — Sign in',
  description: 'Authenticate with your Columbia or Barnard email.'
};

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-950 px-4 py-16">
      <div className="w-full max-w-md rounded-3xl border border-white/10 bg-white/[0.03] p-8 shadow-panel backdrop-blur">
        {children}
      </div>
    </div>
  );
}

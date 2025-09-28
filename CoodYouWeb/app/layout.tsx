import type { Metadata } from 'next';
import '../styles/globals.css';
import { Providers } from './providers';

export const metadata: Metadata = {
  title: 'CoodYou CampusDash',
  description: 'Uber-style marketplace for Columbia and Barnard dining halls.',
  icons: {
    icon: '/favicon.svg'
  }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-transparent text-[color:var(--text-primary)] antialiased">
        <div className="relative min-h-screen">
          <div className="pointer-events-none absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-black/75 to-transparent" />
          <Providers>{children}</Providers>
        </div>
      </body>
    </html>
  );
}

import { Outlet } from 'react-router';
import { Header } from './Header';
import { NotificationToasts } from '../NotificationToasts';
import ErrorBoundary from '../ErrorBoundary';

export function RootLayout() {
  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-gray-50">
        <Header />
        <NotificationToasts />
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Outlet />
        </main>
      </div>
    </ErrorBoundary>
  );
}


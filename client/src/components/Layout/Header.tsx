import { Link, useLocation } from 'react-router';
import { ShoppingBag, ShoppingCart, Package, Bell } from 'lucide-react';
import { useCartStore } from '@/stores/cart-store';
import { useNotificationStore } from '@/stores/notification-store';
import { SearchBar } from '../SearchBar';
import { useUIStore } from '@/stores/ui-store';

export function Header() {
  const location = useLocation();
  const totalItems = useCartStore((state) => state.getTotalItems());
  const notifications = useNotificationStore((state) => state.notifications);
  const { searchQuery, setSearchQuery } = useUIStore();

  const isActive = (path: string) => location.pathname === path;

  return (
    <header className="bg-white shadow-lg border-b sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center py-4">
          <div className="flex items-center space-x-4">
            <Link to="/" className="flex items-center space-x-2">
              <ShoppingBag className="h-8 w-8 text-blue-600" />
              <h1 className="text-3xl font-bold text-gray-900">ShopHub</h1>
            </Link>
            
            <div className="hidden md:block ml-8">
              <SearchBar
                value={searchQuery}
                onChange={setSearchQuery}
                placeholder="Search products..."
              />
            </div>
          </div>

          <nav className="flex items-center space-x-2">
            <Link
              to="/notifications"
              className="relative p-2 text-gray-600 hover:text-gray-900 transition-colors rounded-lg hover:bg-gray-100"
            >
              <Bell className="h-6 w-6" />
              {notifications.length > 0 && (
                <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
                  {notifications.length}
                </span>
              )}
            </Link>

            <Link
              to="/"
              className={`px-4 py-2 rounded-lg font-medium transition-all flex items-center gap-2 ${
                isActive('/')
                  ? 'bg-blue-600 text-white shadow-md'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              <ShoppingBag className="h-5 w-5" />
              <span className="hidden sm:inline">Products</span>
            </Link>

            <Link
              to="/cart"
              className={`px-4 py-2 rounded-lg font-medium transition-all relative flex items-center gap-2 ${
                isActive('/cart')
                  ? 'bg-blue-600 text-white shadow-md'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              <ShoppingCart className="h-5 w-5" />
              <span className="hidden sm:inline">Cart</span>
              {totalItems > 0 && (
                <span className="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center animate-pulse">
                  {totalItems}
                </span>
              )}
            </Link>

            <Link
              to="/orders"
              className={`px-4 py-2 rounded-lg font-medium transition-all flex items-center gap-2 ${
                isActive('/orders')
                  ? 'bg-blue-600 text-white shadow-md'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              <Package className="h-5 w-5" />
              <span className="hidden sm:inline">Orders</span>
            </Link>
          </nav>
        </div>

        {/* Mobile Search */}
        <div className="md:hidden pb-4">
          <SearchBar
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder="Search products..."
          />
        </div>
      </div>
    </header>
  );
}


import { useState, useEffect } from 'react';
import ProductCard from './components/ProductCard';
import Cart from './components/Cart';
import OrderHistory from './components/OrderHistory';
import ProductDetails from './components/ProductDetails';
import SearchBar from './components/SearchBar';
import CategoryFilter from './components/CategoryFilter';
import LoadingSpinner from './components/LoadingSpinner';
import ErrorBoundary from './components/ErrorBoundary';
import { apiService, type Product, type Order } from './services/api';
import './App.css';

interface CartItem {
  id: number;
  name: string;
  price: number;
  quantity: number;
  image_url?: string;
  category?: string;
}

interface Notification {
  id: number;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  timestamp: string;
}

function App() {
  const [activeTab, setActiveTab] = useState<'products' | 'cart' | 'orders' | 'notifications'>('products');
  const [products, setProducts] = useState<Product[]>([]);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [categories, setCategories] = useState<string[]>([]);
  const [showCheckout, setShowCheckout] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    filterProducts();
  }, [products, searchQuery, selectedCategory]);

  const loadData = async () => {
    try {
      setLoading(true);
      console.log('Loading data...');
      const [productsData, ordersData, notificationsData] = await Promise.all([
        apiService.getProducts(),
        apiService.getOrders(),
        apiService.getCustomerNotifications(1) // Default customer ID
      ]);
      console.log('Data loaded:', { products: productsData?.length, orders: ordersData?.length, notifications: notificationsData?.length });
      setProducts(productsData || []);
      setOrders(ordersData || []);
      setNotifications(notificationsData || []);
      
      // Extract unique categories
      const uniqueCategories = [...new Set(productsData.map(p => p.category).filter(Boolean))] as string[];
      setCategories(['all', ...uniqueCategories]);
      
      addNotification('Data loaded successfully!', 'success');
    } catch (err) {
      const errorMessage = 'Failed to load data. Please check if the backend services are running.';
      setError(errorMessage);
      addNotification(errorMessage, 'error');
      console.error('Error loading data:', err);
    } finally {
      console.log('Setting loading to false');
      setLoading(false);
    }
  };

  const filterProducts = () => {
    let filtered = products;
    
    if (searchQuery) {
      filtered = filtered.filter(product =>
        product.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        product.description.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }
    
    if (selectedCategory !== 'all') {
      filtered = filtered.filter(product => product.category === selectedCategory);
    }
    
    setFilteredProducts(filtered);
  };

  const addNotification = (message: string, type: Notification['type'] = 'info') => {
    const notification: Notification = {
      id: Date.now(),
      message,
      type,
      timestamp: new Date().toISOString()
    };
    setNotifications(prev => [notification, ...(prev || []).slice(0, 4)]); // Keep only last 5
  };

  const addToCart = (product: Product) => {
    // Check stock quantity directly from product
    if (!product.stock_quantity || product.stock_quantity <= 0) {
      addNotification('Product is out of stock!', 'warning');
      return;
    }

    // Check if adding this item would exceed available stock
    const existingItem = cartItems.find(item => item.id === product.id);
    const currentQuantity = existingItem ? existingItem.quantity : 0;
    if (currentQuantity >= product.stock_quantity) {
      addNotification('Not enough stock available!', 'warning');
      return;
    }

    setCartItems(prev => {
      const existingItem = prev.find(item => item.id === product.id);
      if (existingItem) {
        return prev.map(item =>
          item.id === product.id
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }
      return [...prev, {
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: 1,
        image_url: product.image_url,
        category: product.category
      }];
    });
    addNotification(`${product.name} added to cart!`, 'success');
  };

  const updateCartQuantity = (productId: number, quantity: number) => {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    
    setCartItems(prev =>
      prev.map(item =>
        item.id === productId ? { ...item, quantity } : item
      )
    );
  };

  const removeFromCart = (productId: number) => {
    setCartItems(prev => prev.filter(item => item.id !== productId));
  };

  const checkout = async () => {
    console.log('Checkout function called!', { cartItems: cartItems.length, loading });
    
    if (cartItems.length === 0) {
      addNotification('Your cart is empty!', 'warning');
      return;
    }

    try {
      console.log('Starting checkout process...');
      setLoading(true);
      
      // Create a single order with all cart items
      
      // Try to create order with payment first
      try {
        console.log('Attempting payment order creation...');
        const result = await apiService.createOrderWithPayment({
          customer_id: 1,
          product_id: cartItems[0].id, // Use first item as primary
          quantity: cartItems.reduce((sum, item) => sum + item.quantity, 0),
          currency: 'USD'
        });
        
        addNotification('Order created with payment intent!', 'success');
        console.log('Payment intent:', result.payment);
      } catch (paymentError) {
        // Fallback to regular order creation
        console.warn('Payment integration failed, creating regular orders:', paymentError);
        
        // Create orders one by one to avoid race conditions
        for (let i = 0; i < cartItems.length; i++) {
          const item = cartItems[i];
          try {
            console.log(`Creating order ${i + 1}/${cartItems.length} for product ${item.id}`);
            await apiService.createOrder({
              customer_id: 1,
              product_id: item.id,
              quantity: item.quantity
            });
            console.log(`✓ Order created for product ${item.id}`);
          } catch (orderError) {
            console.error(`✗ Failed to create order for product ${item.id}:`, orderError);
            addNotification(`Failed to create order for ${item.name}`, 'error');
            throw orderError; // Stop the process if any order fails
          }
        }
        
        addNotification('Orders placed successfully!', 'success');
      }
      
      setCartItems([]);
      setShowCheckout(false);
      await loadData(); // Refresh orders
      setActiveTab('orders');
    } catch (err) {
      addNotification('Failed to place order. Please try again.', 'error');
      console.error('Checkout error:', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading && products.length === 0) {
    return <LoadingSpinner message="Loading your shopping experience..." />;
  }

  return (
    <ErrorBoundary>
      <div className="min-h-screen bg-gray-50">
        {/* Header */}
        <header className="bg-white shadow-lg border-b sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-4">
              <div className="flex items-center space-x-4">
                <h1 className="text-3xl font-bold text-gray-900">🛍️ ShopHub</h1>
                <div className="hidden md:block">
                  <SearchBar 
                    value={searchQuery} 
                    onChange={setSearchQuery}
                    placeholder="Search products..."
                  />
                </div>
              </div>
              
              <div className="flex items-center space-x-4">
                {/* Notifications */}
                <button
                  onClick={() => setActiveTab('notifications')}
                  className="relative p-2 text-gray-600 hover:text-gray-900 transition-colors"
                >
                  🔔
                  {notifications.length > 0 && (
                    <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
                      {notifications.length}
                    </span>
                  )}
                </button>
                
                {/* Navigation */}
                <div className="flex space-x-2">
                  <button
                    onClick={() => setActiveTab('products')}
                    className={`px-4 py-2 rounded-lg font-medium transition-all ${
                      activeTab === 'products'
                        ? 'bg-blue-600 text-white shadow-md'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                  >
                    Products
                  </button>
                  <button
                    onClick={() => setActiveTab('cart')}
                    className={`px-4 py-2 rounded-lg font-medium transition-all relative ${
                      activeTab === 'cart'
                        ? 'bg-blue-600 text-white shadow-md'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                  >
                    Cart
                    {cartItems.length > 0 && (
                      <span className="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center animate-pulse">
                        {cartItems.reduce((sum, item) => sum + item.quantity, 0)}
                      </span>
                    )}
                  </button>
                  <button
                    onClick={() => setActiveTab('orders')}
                    className={`px-4 py-2 rounded-lg font-medium transition-all ${
                      activeTab === 'orders'
                        ? 'bg-blue-600 text-white shadow-md'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                  >
                    Orders
                  </button>
                </div>
              </div>
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

        {/* Notifications */}
        {notifications && notifications.length > 0 && (
          <div className="fixed top-20 right-4 z-50 space-y-2">
            {notifications.slice(0, 3).map((notification) => (
              <div
                key={notification.id}
                className={`p-4 rounded-lg shadow-lg max-w-sm animate-slide-in ${
                  notification.type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' :
                  notification.type === 'error' ? 'bg-red-100 text-red-800 border border-red-200' :
                  notification.type === 'warning' ? 'bg-yellow-100 text-yellow-800 border border-yellow-200' :
                  'bg-blue-100 text-blue-800 border border-blue-200'
                }`}
              >
                <div className="flex justify-between items-start">
                  <p className="text-sm font-medium">{notification.message}</p>
                  <button
                    onClick={() => setNotifications(prev => prev.filter(n => n.id !== notification.id))}
                    className="ml-2 text-lg leading-none"
                  >
                    ×
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Main Content */}
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg mb-6 flex items-center justify-between">
              <span>{error}</span>
              <button
                onClick={loadData}
                className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
              >
                Retry
              </button>
            </div>
          )}

          {activeTab === 'products' && (
            <div>
              <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-8">
                <h2 className="text-3xl font-bold text-gray-900 mb-4 md:mb-0">Products</h2>
                <CategoryFilter
                  categories={categories}
                  selectedCategory={selectedCategory}
                  onCategoryChange={setSelectedCategory}
                />
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                {filteredProducts.map((product) => (
                  <ProductCard
                    key={product.id}
                    product={product}
                    onAddToCart={addToCart}
                    onViewDetails={(product) => setSelectedProduct(product)}
                  />
                ))}
              </div>
              
              {filteredProducts.length === 0 && (
                <div className="text-center py-12">
                  <div className="text-6xl mb-4">🔍</div>
                  <p className="text-gray-500 text-lg">
                    {searchQuery || selectedCategory !== 'all' 
                      ? 'No products match your search criteria' 
                      : 'No products available'
                    }
                  </p>
                  {(searchQuery || selectedCategory !== 'all') && (
                    <button
                      onClick={() => {
                        setSearchQuery('');
                        setSelectedCategory('all');
                      }}
                      className="mt-4 text-blue-600 hover:text-blue-800 font-medium"
                    >
                      Clear filters
                    </button>
                  )}
                </div>
              )}
            </div>
          )}

          {activeTab === 'cart' && (
            <div className="max-w-4xl mx-auto">
              <Cart
                items={cartItems}
                onUpdateQuantity={updateCartQuantity}
                onRemoveItem={removeFromCart}
                onCheckout={() => setShowCheckout(true)}
                showCheckout={showCheckout}
                onCloseCheckout={() => setShowCheckout(false)}
                onConfirmCheckout={checkout}
                loading={loading}
              />
            </div>
          )}

          {activeTab === 'orders' && (
            <div className="max-w-6xl mx-auto">
              <OrderHistory orders={orders} />
            </div>
          )}

          {activeTab === 'notifications' && (
            <div className="max-w-4xl mx-auto">
              <div className="bg-white rounded-lg shadow-md p-6">
                <h2 className="text-2xl font-bold mb-4">Notifications</h2>
                {notifications.length === 0 ? (
                  <p className="text-gray-500 text-center py-8">No notifications</p>
                ) : (
                  <div className="space-y-4">
                    {notifications.map((notification) => (
                      <div
                        key={notification.id}
                        className={`p-4 rounded-lg border-l-4 ${
                          notification.type === 'success' ? 'bg-green-50 border-green-400' :
                          notification.type === 'error' ? 'bg-red-50 border-red-400' :
                          notification.type === 'warning' ? 'bg-yellow-50 border-yellow-400' :
                          'bg-blue-50 border-blue-400'
                        }`}
                      >
                        <p className="font-medium">{notification.message}</p>
                        <p className="text-sm text-gray-500 mt-1">
                          {new Date(notification.timestamp).toLocaleString()}
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </main>

        {/* Product Details Modal */}
        {selectedProduct && (
          <ProductDetails
            product={selectedProduct}
            onClose={() => setSelectedProduct(null)}
            onAddToCart={addToCart}
          />
        )}
      </div>
    </ErrorBoundary>
  );
}

export default App;

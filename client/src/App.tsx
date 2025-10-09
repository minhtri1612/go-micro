import { useState, useEffect } from 'react';
import ProductCard from './components/ProductCard';
import Cart from './components/Cart';
import OrderHistory from './components/OrderHistory';
import { apiService, type Product, type Order } from './services/api';
import './App.css';

interface CartItem {
  id: number;
  name: string;
  price: number;
  quantity: number;
  image_url?: string;
}

function App() {
  const [activeTab, setActiveTab] = useState<'products' | 'cart' | 'orders'>('products');
  const [products, setProducts] = useState<Product[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [productsData, ordersData] = await Promise.all([
        apiService.getProducts(),
        apiService.getOrders()
      ]);
      setProducts(productsData);
      setOrders(ordersData);
    } catch (err) {
      setError('Failed to load data. Please check if the backend services are running.');
      console.error('Error loading data:', err);
    } finally {
      setLoading(false);
    }
  };

  const addToCart = (product: Product) => {
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
        image_url: product.image_url
      }];
    });
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
    try {
      for (const item of cartItems) {
        await apiService.createOrder({
          customer_id: 1, // Default customer for demo
          product_id: item.id,
          quantity: item.quantity
        });
      }
      
      setCartItems([]);
      await loadData(); // Refresh orders
      setActiveTab('orders');
      alert('Order placed successfully!');
    } catch (err) {
      alert('Failed to place order. Please try again.');
      console.error('Checkout error:', err);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <h1 className="text-2xl font-bold text-gray-900">E-Commerce Store</h1>
            <div className="flex space-x-1">
              <button
                onClick={() => setActiveTab('products')}
                className={`px-4 py-2 rounded-md font-medium transition-colors ${
                  activeTab === 'products'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                Products
              </button>
              <button
                onClick={() => setActiveTab('cart')}
                className={`px-4 py-2 rounded-md font-medium transition-colors relative ${
                  activeTab === 'cart'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                Cart
                {cartItems.length > 0 && (
                  <span className="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
                    {cartItems.reduce((sum, item) => sum + item.quantity, 0)}
                  </span>
                )}
              </button>
              <button
                onClick={() => setActiveTab('orders')}
                className={`px-4 py-2 rounded-md font-medium transition-colors ${
                  activeTab === 'orders'
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                Orders
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6 flex items-center justify-between">
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
            <h2 className="text-3xl font-bold text-gray-900 mb-6">Products</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {products.map((product) => (
                <ProductCard
                  key={product.id}
                  product={product}
                  onAddToCart={addToCart}
                />
              ))}
            </div>
            {products.length === 0 && (
              <div className="text-center py-12">
                <p className="text-gray-500 text-lg">No products available</p>
              </div>
            )}
          </div>
        )}

        {activeTab === 'cart' && (
          <div className="max-w-2xl mx-auto">
            <Cart
              items={cartItems}
              onUpdateQuantity={updateCartQuantity}
              onRemoveItem={removeFromCart}
              onCheckout={checkout}
            />
          </div>
        )}

        {activeTab === 'orders' && (
          <div className="max-w-4xl mx-auto">
            <OrderHistory orders={orders} />
          </div>
        )}
      </main>
    </div>
  );
}

export default App;

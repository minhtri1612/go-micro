interface CartItem {
  id: number;
  name: string;
  price: number;
  quantity: number;
  image_url?: string;
  category?: string;
}

interface CartProps {
  items: CartItem[];
  onUpdateQuantity: (productId: number, quantity: number) => void;
  onRemoveItem: (productId: number) => void;
  onCheckout: () => void;
  showCheckout?: boolean;
  onCloseCheckout?: () => void;
  onConfirmCheckout?: () => void;
  loading?: boolean;
}

const Cart = ({ 
  items, 
  onUpdateQuantity, 
  onRemoveItem, 
  onCheckout,
  showCheckout = false,
  onCloseCheckout,
  onConfirmCheckout,
  loading = false
}: CartProps) => {
  const total = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  const itemCount = items.reduce((sum, item) => sum + item.quantity, 0);

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">Shopping Cart</h2>
        <span className="bg-blue-100 text-blue-800 text-sm font-medium px-3 py-1 rounded-full">
          {itemCount} {itemCount === 1 ? 'item' : 'items'}
        </span>
      </div>
      
      {items.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-6xl mb-4">🛒</div>
          <p className="text-gray-500 text-lg mb-4">Your cart is empty</p>
          <p className="text-gray-400">Add some products to get started!</p>
        </div>
      ) : (
        <>
          <div className="space-y-4 mb-6 max-h-96 overflow-y-auto">
            {items.map((item) => (
              <div key={item.id} className="flex items-center space-x-4 p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
                <div className="w-20 h-20 bg-gray-200 rounded-lg flex items-center justify-center flex-shrink-0">
                  {item.image_url ? (
                    <img 
                      src={item.image_url} 
                      alt={item.name}
                      className="w-full h-full object-cover rounded-lg"
                    />
                  ) : (
                    <div className="text-gray-400 text-2xl">📦</div>
                  )}
                </div>
                
                <div className="flex-1 min-w-0">
                  <h3 className="font-medium text-lg truncate">{item.name}</h3>
                  {item.category && (
                    <span className="text-xs text-blue-600 bg-blue-100 px-2 py-1 rounded-full">
                      {item.category}
                    </span>
                  )}
                  <p className="text-gray-600 font-semibold">${item.price.toFixed(2)} each</p>
                </div>
                
                <div className="flex items-center space-x-3">
                  <div className="flex items-center space-x-2 bg-gray-100 rounded-lg">
                    <button
                      onClick={() => onUpdateQuantity(item.id, item.quantity - 1)}
                      className="w-8 h-8 rounded-l-lg bg-gray-200 hover:bg-gray-300 flex items-center justify-center transition-colors"
                    >
                      −
                    </button>
                    <span className="w-8 text-center font-medium">{item.quantity}</span>
                    <button
                      onClick={() => onUpdateQuantity(item.id, item.quantity + 1)}
                      className="w-8 h-8 rounded-r-lg bg-gray-200 hover:bg-gray-300 flex items-center justify-center transition-colors"
                    >
                      +
                    </button>
                  </div>
                  
                  <div className="text-right">
                    <p className="font-bold text-lg">${(item.price * item.quantity).toFixed(2)}</p>
                  </div>
                  
                  <button
                    onClick={() => onRemoveItem(item.id)}
                    className="text-red-500 hover:text-red-700 p-2 hover:bg-red-50 rounded-lg transition-colors"
                    title="Remove item"
                  >
                    🗑️
                  </button>
                </div>
              </div>
            ))}
          </div>
          
          <div className="border-t pt-6">
            <div className="space-y-4">
              <div className="flex justify-between items-center text-lg">
                <span className="font-semibold">Subtotal:</span>
                <span className="font-bold">${total.toFixed(2)}</span>
              </div>
              <div className="flex justify-between items-center text-lg">
                <span className="font-semibold">Shipping:</span>
                <span className="font-bold text-green-600">FREE</span>
              </div>
              <div className="flex justify-between items-center text-xl border-t pt-2">
                <span className="font-bold">Total:</span>
                <span className="font-bold text-green-600">${total.toFixed(2)}</span>
              </div>
            </div>
            
            <button
              onClick={onCheckout}
              disabled={loading}
              className={`w-full mt-6 py-4 px-6 rounded-lg font-bold text-lg transition-all ${
                loading
                  ? 'bg-gray-400 text-gray-600 cursor-not-allowed'
                  : 'bg-green-600 text-white hover:bg-green-700 shadow-lg hover:shadow-xl'
              }`}
            >
              {loading ? 'Processing...' : 'Proceed to Checkout'}
            </button>
            <div className="mt-2 text-xs text-gray-500">
              Debug: loading={loading.toString()}, disabled={loading.toString()}
            </div>
          </div>
        </>
      )}

      {/* Checkout Modal */}
      {showCheckout && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-6">
            <h3 className="text-xl font-bold mb-4">Confirm Checkout</h3>
            <p className="text-gray-600 mb-6">
              Are you ready to place your order for <strong>${total.toFixed(2)}</strong>?
            </p>
            <div className="flex space-x-4">
              <button
                onClick={onCloseCheckout}
                className="flex-1 py-2 px-4 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  console.log('Confirm Order clicked!', { loading, onConfirmCheckout: !!onConfirmCheckout });
                  // Add detailed state logging
                  const cartState = {
                    itemCount: items.length,
                    total: total,
                    loading: loading,
                    showCheckout: showCheckout,
                  };
                  console.log('Current cart state:', cartState);
                  
                  if (onConfirmCheckout) {
                    console.log('Executing checkout...');
                    onConfirmCheckout();
                  } else {
                    console.error('No checkout handler provided!');
                  }
                }}
                disabled={loading}
                className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
                  loading
                    ? 'bg-gray-400 text-gray-600 cursor-not-allowed'
                    : 'bg-green-600 text-white hover:bg-green-700'
                }`}
              >
                {loading ? 'Processing...' : 'Confirm Order'}
              </button>
              <div className="text-xs text-gray-500 mt-2">
                Debug: loading={loading.toString()}, hasHandler={!!onConfirmCheckout}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Cart;

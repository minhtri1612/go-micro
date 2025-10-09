import type { Product } from '../services/api';

interface ProductDetailsProps {
  product: Product;
  onClose: () => void;
  onAddToCart: (product: Product) => void;
}

const ProductDetails = ({ product, onClose, onAddToCart }: ProductDetailsProps) => {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex flex-col lg:flex-row">
          {/* Product Image */}
          <div className="lg:w-1/2 p-6">
            <div className="aspect-square bg-gray-200 rounded-lg flex items-center justify-center">
              {product.image_url ? (
                <img 
                  src={product.image_url} 
                  alt={product.name}
                  className="w-full h-full object-cover rounded-lg"
                />
              ) : (
                <div className="text-gray-400 text-6xl">📦</div>
              )}
            </div>
          </div>
          
          {/* Product Info */}
          <div className="lg:w-1/2 p-6">
            <div className="flex justify-between items-start mb-4">
              <h1 className="text-3xl font-bold text-gray-900">{product.name}</h1>
              <button
                onClick={onClose}
                className="text-gray-400 hover:text-gray-600 text-2xl"
              >
                ×
              </button>
            </div>
            
            {product.category && (
              <span className="inline-block bg-blue-100 text-blue-800 text-sm font-medium px-3 py-1 rounded-full mb-4">
                {product.category}
              </span>
            )}
            
            <p className="text-gray-600 text-lg mb-6">{product.description}</p>
            
            <div className="space-y-4 mb-6">
              <div className="flex items-center justify-between">
                <span className="text-2xl font-bold text-green-600">${product.price.toFixed(2)}</span>
                {product.stock_quantity !== undefined && (
                  <span className={`text-sm font-medium ${
                    product.stock_quantity > 0 ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {product.stock_quantity > 0 ? `${product.stock_quantity} in stock` : 'Out of stock'}
                  </span>
                )}
              </div>
            </div>
            
            <div className="flex space-x-4">
              <button
                onClick={() => onAddToCart(product)}
                disabled={product.stock_quantity === 0}
                className={`flex-1 py-3 px-6 rounded-lg font-medium transition-colors ${
                  product.stock_quantity === 0
                    ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                    : 'bg-blue-600 text-white hover:bg-blue-700'
                }`}
              >
                {product.stock_quantity === 0 ? 'Out of Stock' : 'Add to Cart'}
              </button>
              <button
                onClick={onClose}
                className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ProductDetails;


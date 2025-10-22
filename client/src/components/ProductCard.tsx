import type { Product } from '@/lib/api-client';

interface ProductCardProps {
  product: Product;
  onAddToCart: (product: Product) => void;
  onViewDetails: (product: Product) => void;
}

const ProductCard = ({ product, onAddToCart, onViewDetails }: ProductCardProps) => {
  const isOutOfStock = product.stock_quantity === 0;

  return (
    <div className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-xl transition-all duration-300 group">
      <div className="relative h-48 bg-gray-200 flex items-center justify-center overflow-hidden">
        {product.image_url ? (
          <img 
            src={product.image_url} 
            alt={product.name}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          />
        ) : (
          <div className="text-gray-400 text-4xl">📦</div>
        )}
        
        {/* Quick View Button */}
        <button
          onClick={() => onViewDetails(product)}
          className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-300 flex items-center justify-center opacity-0 group-hover:opacity-100"
        >
          <span className="bg-white text-gray-900 px-4 py-2 rounded-lg font-medium shadow-lg">
            Quick View
          </span>
        </button>
        
        {/* Category Badge */}
        {product.category && (
          <div className="absolute top-2 left-2">
            <span className="bg-blue-600 text-white text-xs font-medium px-2 py-1 rounded-full">
              {product.category}
            </span>
          </div>
        )}
        
        {/* Stock Badge */}
        {isOutOfStock && (
          <div className="absolute top-2 right-2">
            <span className="bg-red-500 text-white text-xs font-medium px-2 py-1 rounded-full">
              Out of Stock
            </span>
          </div>
        )}
      </div>
      
      <div className="p-4">
        <h3 className="font-semibold text-lg mb-2 line-clamp-2">{product.name}</h3>
        <p className="text-gray-600 text-sm mb-3 line-clamp-2">{product.description}</p>
        
        <div className="flex justify-between items-center mb-4">
          <span className="text-green-600 font-bold text-xl">${product.price.toFixed(2)}</span>
          {product.stock_quantity !== undefined && (
            <span className={`text-sm font-medium ${
              product.stock_quantity > 0 ? 'text-green-600' : 'text-red-600'
            }`}>
              {product.stock_quantity > 0 ? `${product.stock_quantity} left` : 'Out of stock'}
            </span>
          )}
        </div>
        
        <div className="flex space-x-2">
          <button
            onClick={() => onViewDetails(product)}
            className="flex-1 py-2 px-3 border border-gray-300 text-gray-700 rounded-md font-medium hover:bg-gray-50 transition-colors text-sm"
          >
            View Details
          </button>
          <button
            onClick={() => onAddToCart(product)}
            disabled={isOutOfStock}
            className={`flex-1 py-2 px-3 rounded-md font-medium transition-colors text-sm ${
              isOutOfStock
                ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                : 'bg-blue-600 text-white hover:bg-blue-700'
            }`}
          >
            {isOutOfStock ? 'Out of Stock' : 'Add to Cart'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ProductCard;

import { useState } from 'react';
import { motion } from 'framer-motion';
import ProductCard from '@/components/ProductCard';
import ProductDetails from '@/components/ProductDetails';
import CategoryFilter from '@/components/CategoryFilter';
import LoadingSpinner from '@/components/LoadingSpinner';
import { useProducts, useFilteredProducts, useProductCategories } from '@/hooks/use-products';
import { useUIStore } from '@/stores/ui-store';
import { useCartStore } from '@/stores/cart-store';
import { useNotificationStore } from '@/stores/notification-store';
import type { Product } from '@/lib/api-client';

export function ProductsPage() {
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const { data: products, isLoading, error } = useProducts();
  const { searchQuery, selectedCategory, setSelectedCategory } = useUIStore();
  const addItem = useCartStore((state) => state.addItem);
  const addNotification = useNotificationStore((state) => state.addNotification);

  const filteredProducts = useFilteredProducts(products, searchQuery, selectedCategory);
  const categories = useProductCategories(products);

  const handleAddToCart = (product: Product) => {
    const success = addItem(product);
    if (success) {
      addNotification(`${product.name} added to cart!`, 'success');
    } else {
      addNotification('Not enough stock available!', 'warning');
    }
  };

  if (isLoading) {
    return <LoadingSpinner message="Loading products..." />;
  }

  if (error) {
    return (
      <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg">
        <p>Failed to load products. Please try again later.</p>
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-8">
        <h2 className="text-3xl font-bold text-gray-900 mb-4 md:mb-0">Products</h2>
        <CategoryFilter
          categories={categories}
          selectedCategory={selectedCategory}
          onCategoryChange={setSelectedCategory}
        />
      </div>

      <motion.div
        className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.3 }}
      >
        {filteredProducts.map((product, index) => (
          <motion.div
            key={product.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: index * 0.05 }}
          >
            <ProductCard
              product={product}
              onAddToCart={handleAddToCart}
              onViewDetails={setSelectedProduct}
            />
          </motion.div>
        ))}
      </motion.div>

      {filteredProducts.length === 0 && (
        <div className="text-center py-12">
          <div className="text-6xl mb-4">🔍</div>
          <p className="text-gray-500 text-lg">
            {searchQuery || selectedCategory !== 'all'
              ? 'No products match your search criteria'
              : 'No products available'}
          </p>
          {(searchQuery || selectedCategory !== 'all') && (
            <button
              onClick={() => {
                useUIStore.setState({ searchQuery: '', selectedCategory: 'all' });
              }}
              className="mt-4 text-blue-600 hover:text-blue-800 font-medium"
            >
              Clear filters
            </button>
          )}
        </div>
      )}

      {selectedProduct && (
        <ProductDetails
          product={selectedProduct}
          onClose={() => setSelectedProduct(null)}
          onAddToCart={handleAddToCart}
        />
      )}
    </>
  );
}


import { motion } from 'framer-motion';
import OrderHistory from '@/components/OrderHistory';
import LoadingSpinner from '@/components/LoadingSpinner';
import { useOrders } from '@/hooks/use-orders';

export function OrdersPage() {
  const { data: orders, isLoading, error } = useOrders();

  if (isLoading) {
    return <LoadingSpinner message="Loading orders..." />;
  }

  if (error) {
    return (
      <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded-lg">
        <p>Failed to load orders. Please try again later.</p>
      </div>
    );
  }

  return (
    <motion.div
      className="max-w-6xl mx-auto"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <OrderHistory orders={orders || []} />
    </motion.div>
  );
}


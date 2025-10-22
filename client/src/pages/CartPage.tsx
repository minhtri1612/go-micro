import { useState } from 'react';
import { useNavigate } from 'react-router';
import { motion } from 'framer-motion';
import Cart from '@/components/Cart';
import { useCartStore } from '@/stores/cart-store';
import { useCheckout } from '@/hooks/use-orders';

export function CartPage() {
  const navigate = useNavigate();
  const [showCheckout, setShowCheckout] = useState(false);
  const { items, updateQuantity, removeItem } = useCartStore();
  const checkout = useCheckout();

  const handleCheckout = async () => {
    try {
      console.log('CartPage: Starting checkout...');
      await checkout.mutateAsync();
      console.log('CartPage: Checkout successful, navigating to orders...');
      setShowCheckout(false);
      navigate('/orders');
    } catch (error) {
      console.error('CartPage: Checkout failed:', error);
      // Error handled by mutation, but we still close the modal
      setShowCheckout(false);
    }
  };

  return (
    <motion.div
      className="max-w-4xl mx-auto"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <Cart
        items={items}
        onUpdateQuantity={updateQuantity}
        onRemoveItem={removeItem}
        onCheckout={() => setShowCheckout(true)}
        showCheckout={showCheckout}
        onCloseCheckout={() => setShowCheckout(false)}
        onConfirmCheckout={handleCheckout}
        loading={checkout.isPending}
      />
    </motion.div>
  );
}


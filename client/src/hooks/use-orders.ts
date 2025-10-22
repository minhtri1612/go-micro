import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/lib/api-client';
import { useNotificationStore } from '@/stores/notification-store';
import { useCartStore } from '@/stores/cart-store';

export const orderKeys = {
  all: ['orders'] as const,
  lists: () => [...orderKeys.all, 'list'] as const,
  list: (filters: Record<string, any>) => [...orderKeys.lists(), filters] as const,
  details: () => [...orderKeys.all, 'detail'] as const,
  detail: (id: number) => [...orderKeys.details(), id] as const,
};

export function useOrders() {
  return useQuery({
    queryKey: orderKeys.lists(),
    queryFn: () => apiClient.getOrders(),
    staleTime: 1 * 60 * 1000, // 1 minute
  });
}

export function useOrder(id: number) {
  return useQuery({
    queryKey: orderKeys.detail(id),
    queryFn: () => apiClient.getOrder(id),
    enabled: !!id,
  });
}

// These are available but not currently used in the app
// export function useCreateOrder() { ... }
// export function useCreateOrderWithPayment() { ... }

export function useUpdateOrderStatus() {
  const queryClient = useQueryClient();
  const addNotification = useNotificationStore((state) => state.addNotification);

  return useMutation({
    mutationFn: ({ id, status }: { id: number; status: string }) =>
      apiClient.updateOrderStatus(id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: orderKeys.lists() });
      addNotification('Order status updated!', 'success');
    },
    onError: (error: Error) => {
      addNotification(`Failed to update order: ${error.message}`, 'error');
    },
  });
}

export function useCheckout() {
  const queryClient = useQueryClient();
  const addNotification = useNotificationStore((state) => state.addNotification);
  const clearCart = useCartStore((state) => state.clearCart);
  const cartItems = useCartStore((state) => state.items);

  return useMutation({
    mutationFn: async () => {
      if (cartItems.length === 0) {
        throw new Error('Cart is empty');
      }

      console.log('Starting checkout process...', { cartItems: cartItems.length });

      // Try payment flow first
      try {
        console.log('Attempting payment order creation...');
        const result = await apiClient.createOrderWithPayment({
          customer_id: 1,
          product_id: cartItems[0].id,
          quantity: cartItems.reduce((sum, item) => sum + item.quantity, 0),
          total_price: cartItems.reduce((sum, item) => sum + (item.price * item.quantity), 0),
          currency: 'USD',
        });
        console.log('Payment order created successfully:', result);
        return { type: 'payment', result };
      } catch (paymentError) {
        console.warn('Payment integration failed, trying regular orders:', paymentError);
        
        // Fallback to regular orders
        const results = [];
        for (const item of cartItems) {
          try {
            console.log(`Creating order for product ${item.id}...`);
            const result = await apiClient.createOrder({
              customer_id: 1,
              product_id: item.id,
              quantity: item.quantity,
              total_price: item.price * item.quantity,
            });
            results.push(result);
            console.log(`Order created for product ${item.id}:`, result);
          } catch (orderError) {
            console.error(`Failed to create order for product ${item.id}:`, orderError);
            throw new Error(`Failed to create order for ${item.name}: ${orderError instanceof Error ? orderError.message : 'Unknown error'}`);
          }
        }
        console.log('All regular orders created successfully:', results);
        return { type: 'regular', results };
      }
    },
    onSuccess: (data) => {
      console.log('Checkout successful:', data);
      clearCart();
      queryClient.invalidateQueries({ queryKey: orderKeys.lists() });
      queryClient.invalidateQueries({ queryKey: ['products'] });
      addNotification('Order placed successfully!', 'success');
    },
    onError: (error: Error) => {
      console.error('Checkout failed:', error);
      addNotification(`Checkout failed: ${error.message}`, 'error');
    },
  });
}


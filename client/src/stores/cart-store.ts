import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

export interface CartItem {
  id: number;
  name: string;
  price: number;
  quantity: number;
  image_url?: string;
  category?: string;
  stock_quantity?: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: Omit<CartItem, 'quantity'> & { quantity?: number }) => boolean;
  removeItem: (id: number) => void;
  updateQuantity: (id: number, quantity: number) => void;
  clearCart: () => void;
  getTotalItems: () => number;
  getTotalPrice: () => number;
}

export const useCartStore = create<CartStore>()(
  devtools(
    persist(
      (set, get) => ({
        items: [],

        addItem: (product) => {
          const { items } = get();
          const existingItem = items.find((item) => item.id === product.id);
          
          // Check stock
          if (product.stock_quantity !== undefined && product.stock_quantity <= 0) {
            return false;
          }

          if (existingItem) {
            const newQuantity = existingItem.quantity + (product.quantity || 1);
            
            // Check if new quantity exceeds stock
            if (
              product.stock_quantity !== undefined &&
              newQuantity > product.stock_quantity
            ) {
              return false;
            }

            set({
              items: items.map((item) =>
                item.id === product.id
                  ? { ...item, quantity: newQuantity }
                  : item
              ),
            });
          } else {
            set({
              items: [
                ...items,
                {
                  ...product,
                  quantity: product.quantity || 1,
                },
              ],
            });
          }
          
          return true;
        },

        removeItem: (id) => {
          set((state) => ({
            items: state.items.filter((item) => item.id !== id),
          }));
        },

        updateQuantity: (id, quantity) => {
          if (quantity <= 0) {
            get().removeItem(id);
            return;
          }

          set((state) => ({
            items: state.items.map((item) =>
              item.id === id ? { ...item, quantity } : item
            ),
          }));
        },

        clearCart: () => {
          set({ items: [] });
        },

        getTotalItems: () => {
          return get().items.reduce((total, item) => total + item.quantity, 0);
        },

        getTotalPrice: () => {
          return get().items.reduce(
            (total, item) => total + item.price * item.quantity,
            0
          );
        },
      }),
      {
        name: 'cart-storage',
      }
    )
  )
);


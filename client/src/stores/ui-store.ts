import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

interface UIStore {
  searchQuery: string;
  selectedCategory: string;
  showCheckout: boolean;
  setSearchQuery: (query: string) => void;
  setSelectedCategory: (category: string) => void;
  setShowCheckout: (show: boolean) => void;
}

export const useUIStore = create<UIStore>()(
  devtools(
    persist(
      (set) => ({
        searchQuery: '',
        selectedCategory: 'all',
        showCheckout: false,

        setSearchQuery: (query) => set({ searchQuery: query }),
        setSelectedCategory: (category) => set({ selectedCategory: category }),
        setShowCheckout: (show) => set({ showCheckout: show }),
      }),
      {
        name: 'ui-storage',
        partialize: (state) => ({
          selectedCategory: state.selectedCategory,
        }),
      }
    )
  )
);


import { useQuery } from '@tanstack/react-query';
import { apiClient, type Product } from '@/lib/api-client';

export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters: Record<string, any>) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: number) => [...productKeys.details(), id] as const,
};

export function useProducts() {
  return useQuery({
    queryKey: productKeys.lists(),
    queryFn: () => apiClient.getProducts(),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

export function useProduct(id: number) {
  return useQuery({
    queryKey: productKeys.detail(id),
    queryFn: () => apiClient.getProduct(id),
    enabled: !!id,
    staleTime: 5 * 60 * 1000,
  });
}

export function useFilteredProducts(
  products: Product[] | undefined,
  searchQuery: string,
  selectedCategory: string
) {
  if (!products) return [];

  let filtered = products;

  if (searchQuery) {
    const query = searchQuery.toLowerCase();
    filtered = filtered.filter(
      (product) =>
        product.name.toLowerCase().includes(query) ||
        product.description.toLowerCase().includes(query)
    );
  }

  if (selectedCategory !== 'all') {
    filtered = filtered.filter(
      (product) => product.category === selectedCategory
    );
  }

  return filtered;
}

export function useProductCategories(products: Product[] | undefined) {
  if (!products) return ['all'];

  const uniqueCategories = [
    ...new Set(products.map((p) => p.category).filter(Boolean)),
  ] as string[];

  return ['all', ...uniqueCategories];
}


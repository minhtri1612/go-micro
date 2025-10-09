const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  category: string;
  image_url?: string;
  stock_quantity: number;
  created_at: string;
  updated_at: string;
}

export interface Order {
  id: number;
  customer_id: number;
  product_id: number;
  quantity: number;
  total_price: number;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface CreateOrderRequest {
  customer_id: number;
  product_id: number;
  quantity: number;
}

class ApiService {
  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const config: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  // Product endpoints
  async getProducts(): Promise<Product[]> {
    return this.request<Product[]>('/api/v1/products/');
  }

  async getProduct(id: number): Promise<Product> {
    return this.request<Product>(`/api/v1/products/${id}/`);
  }

  // Order endpoints
  async createOrder(orderData: CreateOrderRequest): Promise<Order> {
    return this.request<Order>('/api/v1/orders/', {
      method: 'POST',
      body: JSON.stringify(orderData),
    });
  }

  async getOrders(): Promise<Order[]> {
    return this.request<Order[]>('/api/v1/orders/');
  }

  async getOrder(id: number): Promise<Order> {
    return this.request<Order>(`/api/v1/orders/${id}/`);
  }

  async updateOrderStatus(id: number, status: string): Promise<Order> {
    return this.request<Order>(`/api/v1/orders/${id}/status/`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
  }

  // Health check
  async healthCheck(): Promise<{ status: string }> {
    return this.request<{ status: string }>('/health');
  }
}

export const apiService = new ApiService();

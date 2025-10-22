const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8089';

export class ApiError extends Error {
  public status: number;
  public statusText: string;
  public data?: any;

  constructor(
    message: string,
    status: number,
    statusText: string,
    data?: any
  ) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.statusText = statusText;
    this.data = data;
  }
}

class ApiClient {
  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
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
        const errorData = await response.json().catch(() => null);
        throw new ApiError(
          errorData?.message || `HTTP error! status: ${response.status}`,
          response.status,
          response.statusText,
          errorData
        );
      }

      return await response.json();
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      
      // Network errors, etc.
      throw new ApiError(
        error instanceof Error ? error.message : 'Network request failed',
        0,
        'Network Error'
      );
    }
  }

  // Product endpoints
  async getProducts() {
    return this.request<Product[]>('/api/v1/products');
  }

  async getProduct(id: number) {
    return this.request<Product>(`/api/v1/products/${id}`);
  }

  // Order endpoints
  async createOrder(orderData: CreateOrderRequest) {
    return this.request<Order>('/api/v1/orders', {
      method: 'POST',
      body: JSON.stringify(orderData),
    });
  }

  async createOrderWithPayment(
    orderData: CreateOrderRequest & { currency: string }
  ) {
    return this.request<{ order: Order; payment: any }>(
      '/api/v1/orders/with-payment',
      {
        method: 'POST',
        body: JSON.stringify(orderData),
      }
    );
  }

  async getOrders() {
    return this.request<Order[]>('/api/v1/orders');
  }

  async getOrder(id: number) {
    return this.request<Order>(`/api/v1/orders/${id}`);
  }

  async updateOrderStatus(id: number, status: string) {
    return this.request<Order>(`/api/v1/orders/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
  }

  // Inventory endpoints
  async checkInventory(productId: number, quantity: number) {
    return this.request<{ available: boolean }>('/api/v1/inventory/check', {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity }),
    });
  }

  async getInventory() {
    return this.request<InventoryItem[]>('/api/v1/inventory');
  }

  // Payment endpoints
  async createPaymentIntent(amount: number, currency: string) {
    return this.request<Payment>('/api/v1/payments', {
      method: 'POST',
      body: JSON.stringify({ amount, currency }),
    });
  }

  async confirmPayment(paymentIntentId: string) {
    return this.request<Payment>('/api/v1/payments/confirm', {
      method: 'POST',
      body: JSON.stringify({ payment_intent_id: paymentIntentId }),
    });
  }

  // Notification endpoints
  async getNotifications() {
    return this.request<ServerNotification[]>('/api/v1/notifications');
  }

  async getCustomerNotifications(customerId: number) {
    return this.request<ServerNotification[]>(
      `/api/v1/notifications/customer/${customerId}`
    );
  }

  // Health check
  async healthCheck() {
    return this.request<{ status: string }>('/health');
  }
}

export const apiClient = new ApiClient();

// Types
export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  category?: string;
  image_url?: string;
  stock_quantity?: number;
  created_at?: string;
  updated_at?: string;
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
  total_price?: number;
}

export interface InventoryItem {
  id: number;
  product_id: number;
  quantity: number;
  updated_at: string;
}

export interface Payment {
  id: string;
  amount: number;
  currency: string;
  status: string;
  created_at: string;
}

export interface ServerNotification {
  id: number;
  customer_id: number;
  message: string;
  type: string;
  read: boolean;
  created_at: string;
}


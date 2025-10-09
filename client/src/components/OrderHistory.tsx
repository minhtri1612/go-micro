import type { Order } from '../services/api';

interface OrderHistoryOrder extends Order {
  product_name?: string;
}

interface OrderHistoryProps {
  orders: OrderHistoryOrder[];
}

const OrderHistory = ({ orders }: OrderHistoryProps) => {
  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'bg-green-100 text-green-800';
      case 'pending':
        return 'bg-yellow-100 text-yellow-800';
      case 'cancelled':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h2 className="text-2xl font-bold mb-4">Order History</h2>
      
      {orders.length === 0 ? (
        <p className="text-gray-500 text-center py-8">No orders found</p>
      ) : (
        <div className="space-y-4">
          {orders.map((order) => (
            <div key={order.id} className="border rounded-lg p-4">
              <div className="flex justify-between items-start mb-2">
                <div>
                  <h3 className="font-semibold">Order #{order.id}</h3>
                  <p className="text-sm text-gray-600">
                    {order.product_name || `Product ID: ${order.product_id}`}
                  </p>
                </div>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(order.status)}`}>
                  {order.status}
                </span>
              </div>
              
              <div className="flex justify-between items-center text-sm text-gray-600">
                <span>Quantity: {order.quantity}</span>
                <span>Total: ${order.total_price.toFixed(2)}</span>
                <span>{new Date(order.created_at).toLocaleDateString()}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default OrderHistory;

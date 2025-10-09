-- Create Products Database
CREATE DATABASE products_db;
\c products_db;

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100),
    image_url VARCHAR(500),
    stock_quantity INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample products
INSERT INTO products (name, description, price, category, image_url, stock_quantity) VALUES
('Laptop Pro 15"', 'High-performance laptop with 16GB RAM and 512GB SSD', 1299.99, 'Electronics', 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400', 10),
('Wireless Headphones', 'Noise-cancelling wireless headphones with 30-hour battery life', 199.99, 'Electronics', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400', 25),
('Smart Watch', 'Fitness tracker with heart rate monitor and GPS', 299.99, 'Electronics', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400', 15),
('Coffee Maker', 'Automatic drip coffee maker with programmable timer', 89.99, 'Kitchen', 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400', 8),
('Running Shoes', 'Lightweight running shoes with cushioned sole', 129.99, 'Sports', 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400', 20),
('Backpack', 'Waterproof backpack with laptop compartment', 79.99, 'Accessories', 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400', 12),
('Bluetooth Speaker', 'Portable speaker with 360-degree sound', 149.99, 'Electronics', 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=400', 18),
('Desk Lamp', 'LED desk lamp with adjustable brightness', 49.99, 'Home', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400', 30);

-- Create Orders Database
CREATE DATABASE orders_db;
\c orders_db;

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Inventory Database
CREATE DATABASE inventory_db;
\c inventory_db;

CREATE TABLE IF NOT EXISTS inventory (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    sku VARCHAR(50) NOT NULL,
    location VARCHAR(100)
);

-- Create Notification Database
CREATE DATABASE notification_db;
\c notification_db;

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP
);

-- Create Payment Database
CREATE DATABASE payment_db;
\c payment_db;

CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(50) NOT NULL,
    stripe_payment_id VARCHAR(255),
    stripe_client_secret VARCHAR(255),
    payment_method VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_stripe_payment_id ON payments(stripe_payment_id);

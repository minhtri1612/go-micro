-- Connect to inventory database and populate it with product data
\c inventory_db;

-- Insert inventory records for all products
INSERT INTO inventory (product_id, quantity, sku, location) 
SELECT id, stock_quantity, CONCAT('SKU-', id), 'Main Warehouse' 
FROM products 
WHERE stock_quantity > 0;


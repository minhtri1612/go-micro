CREATE TABLE IF NOT EXISTS inventory (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    sku VARCHAR(50) NOT NULL,
    location VARCHAR(100)
);

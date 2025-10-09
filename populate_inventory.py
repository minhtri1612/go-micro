#!/usr/bin/env python3
import requests
import json

# Get products from product service
products_response = requests.get('http://localhost:8089/api/v1/products')
products = products_response.json()

print(f"Found {len(products)} products")

# Populate inventory for each product
inventory_service_url = 'http://localhost:8089/api/v1/inventory'

for product in products:
    inventory_data = {
        "product_id": product["id"],
        "quantity": product.get("stock_quantity", 10),  # Use stock_quantity from product
        "sku": f"SKU-{product['id']}",
        "location": "Main Warehouse"
    }
    
    try:
        response = requests.post(inventory_service_url, json=inventory_data)
        if response.status_code == 201:
            print(f"✓ Added inventory for product {product['id']}: {product['name']}")
        else:
            print(f"✗ Failed to add inventory for product {product['id']}: {response.text}")
    except Exception as e:
        print(f"✗ Error adding inventory for product {product['id']}: {e}")

print("Inventory population complete!")


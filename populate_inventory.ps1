# Get products from API
$productsResponse = Invoke-WebRequest -Uri "http://localhost:8089/api/v1/products" -UseBasicParsing
$products = $productsResponse.Content | ConvertFrom-Json

Write-Host "Found $($products.Count) products"

# Populate inventory for each product
foreach ($product in $products) {
    $inventoryData = @{
        product_id = $product.id
        quantity = if ($product.stock_quantity) { $product.stock_quantity } else { 10 }
        sku = "SKU-$($product.id)"
        location = "Main Warehouse"
    } | ConvertTo-Json

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8089/api/v1/inventory" -Method POST -Body $inventoryData -ContentType "application/json" -UseBasicParsing
        if ($response.StatusCode -eq 201) {
            Write-Host "✓ Added inventory for product $($product.id): $($product.name)"
        } else {
            Write-Host "✗ Failed to add inventory for product $($product.id): $($response.Content)"
        }
    } catch {
        Write-Host "✗ Error adding inventory for product $($product.id): $($_.Exception.Message)"
    }
}

Write-Host "Inventory population complete!"


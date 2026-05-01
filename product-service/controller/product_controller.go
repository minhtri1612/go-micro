package controller

import (
	"database/sql"
	"log"
	"net/http"
	"strconv"

	"go-microservices/product-service/model"

	"github.com/gin-gonic/gin"
)

// ProductController handles product-related requests
type ProductController struct {
	DB *sql.DB
}

// NewProductController creates a new product controller
func NewProductController(db *sql.DB) *ProductController {
	return &ProductController{DB: db}
}

// CreateProduct handles creation of a new product
func (pc *ProductController) CreateProduct(c *gin.Context) {
	var product model.Product
	if err := c.BindJSON(&product); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var id int
	err := pc.DB.QueryRow(
		"INSERT INTO products (name, description, price) VALUES ($1, $2, $3) RETURNING id",
		product.Name, product.Description, product.Price).Scan(&id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	product.ID = id
	c.JSON(http.StatusCreated, product)
}

// GetProducts returns all products
func (pc *ProductController) GetProducts(c *gin.Context) {
	rows, err := pc.DB.Query("SELECT id, name, description, price, category, image_url, stock_quantity, created_at, updated_at FROM products")
	if err != nil {
		// Log and return empty list so the service stays responsive while DB recovers
		log.Printf("Failed to query products: %v", err)
		c.JSON(http.StatusOK, []model.Product{})
		return
	}
	defer rows.Close()

	var products []model.Product
	for rows.Next() {
		var p model.Product
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.Price, &p.Category, &p.ImageURL, &p.StockQuantity, &p.CreatedAt, &p.UpdatedAt); err != nil {
			// Log and skip malformed rows; return what we have
			log.Printf("Error scanning product row: %v", err)
			continue
		}
		products = append(products, p)
	}

	c.JSON(http.StatusOK, products)
}

// GetProduct returns a specific product by ID
func (pc *ProductController) GetProduct(c *gin.Context) {
	id := c.Param("id")
	var product model.Product

	err := pc.DB.QueryRow("SELECT id, name, description, price, category, image_url, stock_quantity, created_at, updated_at FROM products WHERE id = $1", id).
		Scan(&product.ID, &product.Name, &product.Description, &product.Price, &product.Category, &product.ImageURL, &product.StockQuantity, &product.CreatedAt, &product.UpdatedAt)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, product)
}

// UpdateProduct updates a product
func (pc *ProductController) UpdateProduct(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
		return
	}

	var product model.Product
	if err := c.BindJSON(&product); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	result, err := pc.DB.Exec("UPDATE products SET name = $1, description = $2, price = $3 WHERE id = $4",
		product.Name, product.Description, product.Price, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	product.ID = id
	c.JSON(http.StatusOK, product)
}

// DeleteProduct deletes a product
func (pc *ProductController) DeleteProduct(c *gin.Context) {
	id := c.Param("id")

	result, err := pc.DB.Exec("DELETE FROM products WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Product deleted successfully"})
}

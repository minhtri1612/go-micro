package main

import (
	"log"

	"go-microservices/product-service/controller"
	"go-microservices/product-service/db"
	"go-microservices/product-service/routes"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	log.Println("Product Service main function started")
	// Initialize database connection
	log.Println("Calling db.GetDB()...")
	database := db.GetDB()
	defer database.Close()
	log.Println("Database connection established")

	// Initialize database schema
	db.InitSchema(database)

	// Create product controller
	productController := controller.NewProductController(database)

	// Initialize router
	router := gin.Default()

	// Add prometheus metrics endpoint
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// Setup routes
	routes.SetupRoutes(router, productController)

	// Start server
	log.Println("Product Service starting on port 8080...")
	if err := router.Run(":8080"); err != nil {
		log.Fatal("Failed to start server: ", err)
	}
}

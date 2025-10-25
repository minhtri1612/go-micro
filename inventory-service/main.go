package main

import (
	"log"

	"go-microservices/inventory-service/controller"
	"go-microservices/inventory-service/db"
	"go-microservices/inventory-service/routes"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// Initialize database connection
	database := db.GetDB()
	defer database.Close()

	// Initialize database schema
	db.InitSchema(database)

	// Create inventory controller
	inventoryController := controller.NewInventoryController(database)

	// Initialize router
	router := gin.Default()

	// Add prometheus metrics endpoint
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// Setup routes
	routes.SetupRoutes(router, inventoryController)

	// Start server
	log.Println("Inventory Service starting on port 8082...")
	if err := router.Run(":8082"); err != nil {
		log.Fatal("Failed to start server: ", err)
	}
}

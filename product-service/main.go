package main

import (
	"log"

	"go-microservices/product-service/controller"
	"go-microservices/product-service/db"
	"go-microservices/product-service/routes"

	"github.com/gin-gonic/gin"
	"github.com/penglongli/gin-metrics/ginmetrics"
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

	// HTTP metrics middleware - track request count, latency, error rate
	m := ginmetrics.GetMonitor()
	m.SetMetricPath("/metrics")
	m.SetSlowTime(2)
	m.SetDuration([]float64{0.05, 0.1, 0.25, 0.5, 1, 2, 5})
	m.Use(router)

	// Add prometheus metrics endpoint (fallback)

	// Setup routes
	routes.SetupRoutes(router, productController)

	// Start server
	log.Println("Product Service starting on port 8080...")
	if err := router.Run(":8080"); err != nil {
		log.Fatal("Failed to start server: ", err)
	}
}

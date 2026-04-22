package main

import (
	"log"

	"go-microservices/payment-service/controller"
	"go-microservices/payment-service/db"
	"go-microservices/payment-service/routes"

	"github.com/gin-gonic/gin"
	"github.com/penglongli/gin-metrics/ginmetrics"
)

func main() {
	// Initialize database connection
	database := db.GetDB()
	defer database.Close()

	// Initialize database schema
	db.InitSchema(database)

	// Create payment controller
	paymentController := controller.NewPaymentController(database)

	// Initialize router
	router := gin.Default()

	// HTTP metrics middleware
	m := ginmetrics.GetMonitor()
	m.SetMetricPath("/metrics")
	m.SetSlowTime(2)
	m.SetDuration([]float64{0.05, 0.1, 0.25, 0.5, 1, 2, 5})
	m.Use(router)


	// Setup routes
	routes.SetupRoutes(router, paymentController)

	// Start server
	log.Println("Payment Service starting on port 8084...")
	if err := router.Run(":8084"); err != nil {
		log.Fatal("Failed to start server: ", err)
	}
}
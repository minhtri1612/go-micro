package main

import (
	"log"

	"go-microservices/notification-service/controller"
	"go-microservices/notification-service/db"
	"go-microservices/notification-service/routes"

	"github.com/gin-gonic/gin"
	"github.com/penglongli/gin-metrics/ginmetrics"
)

func main() {
	// Initialize database connection
	database := db.GetDB()
	defer database.Close()

	// Initialize database schema
	db.InitSchema(database)

	// Create notification controller
	notificationController := controller.NewNotificationController(database)

	// Initialize router
	router := gin.Default()

	// HTTP metrics middleware
	m := ginmetrics.GetMonitor()
	m.SetMetricPath("/metrics")
	m.SetSlowTime(2)
	m.SetDuration([]float64{0.05, 0.1, 0.25, 0.5, 1, 2, 5})
	m.Use(router)


	// Setup routes
	routes.SetupRoutes(router, notificationController)

	// Start server
	log.Println("Notification Service starting on port 8083...")
	if err := router.Run(":8083"); err != nil {
		log.Fatal("Failed to start server: ", err)
	}
}

package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	amqp "github.com/rabbitmq/amqp091-go"
)

var (
	channel *amqp.Channel
	conn    *amqp.Connection
	ctx     = context.Background()
)

// Config holds RabbitMQ configuration
type Config struct {
	QueueName       string
	RoutingKey      string
	ExchangeName    string
	ExchangeType    string
	ConnectionRetry int
}

// InitRabbitMQ initializes RabbitMQ connection
func InitRabbitMQ() error {
	rabbitHost := os.Getenv("RABBITMQ_HOST")
	if rabbitHost == "" {
		rabbitHost = "rabbitmq" // Docker default
	}

	var err error
	conn, err = amqp.Dial(fmt.Sprintf("amqp://guest:guest@%s:5672/", rabbitHost))
	if err != nil {
		return fmt.Errorf("failed to connect to RabbitMQ: %w", err)
	}

	channel, err = conn.Channel()
	if err != nil {
		return fmt.Errorf("failed to open channel: %w", err)
	}

	return nil
}

// DeclareQueue declares a queue with given configuration
func DeclareQueue(config Config) error {
	// Declare exchange
	err := channel.ExchangeDeclare(
		config.ExchangeName,
		config.ExchangeType,
		true,  // durable
		false, // auto-deleted
		false, // internal
		false, // no-wait
		nil,   // arguments
	)
	if err != nil {
		return fmt.Errorf("failed to declare exchange: %w", err)
	}

	// Declare queue
	_, err = channel.QueueDeclare(
		config.QueueName,
		true,  // durable
		false, // delete when unused
		false, // exclusive
		false, // no-wait
		nil,   // arguments
	)
	if err != nil {
		return fmt.Errorf("failed to declare queue: %w", err)
	}

	// Bind queue to exchange
	err = channel.QueueBind(
		config.QueueName,
		config.RoutingKey,
		config.ExchangeName,
		false,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to bind queue: %w", err)
	}

	return nil
}

// PublishMessage publishes a message to queue
func PublishMessage(config Config, message interface{}) error {
	body, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	err = channel.PublishWithContext(
		ctx,
		config.ExchangeName,
		config.RoutingKey,
		false, // mandatory
		false, // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
		},
	)
	if err != nil {
		return fmt.Errorf("failed to publish message: %w", err)
	}

	return nil
}

// ConsumeMessages starts consuming messages from queue
func ConsumeMessages(config Config, handler func([]byte) error) error {
	msgs, err := channel.Consume(
		config.QueueName,
		"",    // consumer
		false, // auto-ack
		false, // exclusive
		false, // no-local
		false, // no-wait
		nil,   // args
	)
	if err != nil {
		return fmt.Errorf("failed to register a consumer: %w", err)
	}

	go func() {
		for msg := range msgs {
			if err := handler(msg.Body); err != nil {
				fmt.Printf("Error processing message: %v\n", err)
				if err := msg.Nack(false, true); err != nil { // Negative acknowledgement, requeue
					fmt.Printf("Error sending nack: %v\n", err)
				}
			} else {
				if err := msg.Ack(false); err != nil { // Positive acknowledgement
					fmt.Printf("Error sending ack: %v\n", err)
				}
			}
		}
	}()

	return nil
}

// Close closes RabbitMQ connection
func Close() {
	if channel != nil {
		if err := channel.Close(); err != nil {
			fmt.Printf("Error closing channel: %v\n", err)
		}
	}
	if conn != nil {
		if err := conn.Close(); err != nil {
			fmt.Printf("Error closing connection: %v\n", err)
		}
	}
}

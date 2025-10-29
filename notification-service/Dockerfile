FROM golang:1.18-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum from root
COPY go.mod ./
COPY go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY notification-service/ ./notification-service/

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /notification-service ./notification-service

# Final stage
FROM alpine:latest

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /notification-service .

# Expose port
EXPOSE 8085

# Run the application
CMD ["./notification-service"]
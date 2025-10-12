# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy the entire project (for go.mod and go.sum)
COPY . .

# Download dependencies
RUN go mod download

# Build the payment service
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o payment-service ./payment-service

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/payment-service .

# Expose port
EXPOSE 8084

# Command to run
CMD ["./payment-service"]
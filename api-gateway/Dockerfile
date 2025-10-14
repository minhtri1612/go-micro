FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum from the project root
COPY ../go.mod ./
COPY ../go.sum ./

# Download dependencies
RUN go mod download

# Copy the API gateway source code
COPY ./api-gateway ./api-gateway

# Build the API gateway service
RUN CGO_ENABLED=0 GOOS=linux go build -o /api-gateway ./api-gateway

# Final stage
FROM alpine:latest

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /api-gateway .

EXPOSE 8000
CMD ["./api-gateway"]

# Build stage (pin to stable LTS to avoid npm v10 issues)
FROM node:20-bullseye-slim AS builder

WORKDIR /app

    # Copy package files
COPY package*.json ./

# Install dependencies deterministically (uses package-lock.json)
RUN npm ci --no-audit --no-fund

# Copy source code
COPY . .

# Set build-time environment variables
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

# E-Commerce Frontend

A modern React TypeScript frontend for the Go Microservices E-Commerce platform.

## Features

- **Product Catalog**: Browse and view product details with images
- **Shopping Cart**: Add/remove items, update quantities
- **Order Management**: View order history and status
- **Responsive Design**: Works on desktop and mobile devices
- **Real-time Updates**: Connected to microservices backend

## Technology Stack

- **React 19** with TypeScript
- **Vite** for fast development and building
- **Tailwind CSS** for styling
- **Lucide React** for icons

## Development

### Prerequisites

- Node.js 18+
- npm or yarn

### Local Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Docker

The frontend is containerized using a multi-stage Docker build:

```bash
# Build the Docker image
docker build -t ecommerce-client .

# Run the container
docker run -p 3000:80 ecommerce-client
```

## Environment Variables

- `REACT_APP_API_URL`: Backend API URL (default: http://localhost:8000)

## API Integration

The frontend communicates with the microservices through the API Gateway:

- **Products**: `/api/v1/products`
- **Orders**: `/api/v1/orders`
- **Health Check**: `/health`

## Usage

1. **Products Tab**: Browse available products and add them to cart
2. **Cart Tab**: Review items, update quantities, and checkout
3. **Orders Tab**: View order history and track status

## Production Deployment

The application is optimized for production with:

- Nginx for serving static files
- Client-side routing support
- Static asset caching
- Security headers
# Quick Start Guide ⚡

## Installation

```bash
cd client

# Install dependencies (choose one)
npm install
# or
pnpm install
# or
yarn install
```

## Development

```bash
# Start development server
npm run dev

# App will be available at http://localhost:5173
```

## Environment Setup

Create a `.env` file in the `client/` directory:

```env
VITE_API_URL=http://localhost:8089
```

## Project Structure

```
client/
├── src/
│   ├── components/       # Reusable UI components
│   ├── pages/           # Route pages
│   ├── stores/          # Zustand state management
│   ├── hooks/           # Custom React hooks
│   ├── lib/             # Utilities and API client
│   ├── App.tsx          # Router setup
│   └── main.tsx         # App entry point
├── package.json
└── vite.config.ts
```

## Key Features

### 🛒 State Management (Zustand)

```typescript
// Cart
import { useCartStore } from '@/stores/cart-store';
const { items, addItem, removeItem } = useCartStore();

// Notifications
import { useNotificationStore } from '@/stores/notification-store';
const { addNotification } = useNotificationStore();

// UI State
import { useUIStore } from '@/stores/ui-store';
const { searchQuery, setSearchQuery } = useUIStore();
```

### 📡 Data Fetching (TanStack Query)

```typescript
// Products
import { useProducts, useProduct } from '@/hooks/use-products';
const { data: products, isLoading, error } = useProducts();

// Orders
import { useOrders, useCheckout } from '@/hooks/use-orders';
const { data: orders } = useOrders();
const checkout = useCheckout();
```

### 🎯 Routing

Navigate between pages:
- `/` - Products page
- `/cart` - Shopping cart
- `/orders` - Order history
- `/notifications` - Notifications

### 📝 Forms (React Hook Form + Zod)

```typescript
import { CheckoutForm } from '@/components/CheckoutForm';

<CheckoutForm
  onSubmit={handleSubmit}
  onCancel={handleCancel}
  isLoading={isLoading}
/>
```

## Development Tools

### React Query DevTools

Press the floating button in bottom-right to open DevTools.
- View all queries and their states
- See cached data
- Monitor refetching
- Debug mutations

### Zustand DevTools

Install Redux DevTools extension to monitor Zustand stores.

## Build for Production

```bash
npm run build

# Preview production build
npm run preview
```

## Common Tasks

### Adding a New Page

1. Create page component in `src/pages/`
2. Add route in `src/App.tsx`
3. Add navigation link in `src/components/Layout/Header.tsx`

### Adding a New API Endpoint

1. Add method to `src/lib/api-client.ts`
2. Create custom hook in `src/hooks/`
3. Use hook in components

### Adding a New Store

1. Create store in `src/stores/`
2. Use `create()` from zustand
3. Add devtools and persist middleware if needed

## Troubleshooting

### Port already in use
```bash
# Kill process on port 5173
lsof -ti:5173 | xargs kill -9

# Or change port in vite.config.ts
```

### API not responding
1. Check backend is running on port 8089
2. Verify VITE_API_URL in .env
3. Check browser console for CORS errors

### Types not working
```bash
# Rebuild TypeScript
npm run build

# Or restart TypeScript server in your IDE
```

## Scripts

```bash
npm run dev       # Start dev server
npm run build     # Build for production
npm run preview   # Preview production build
npm run lint      # Run ESLint
```

## Next Steps

1. ✅ Install dependencies
2. ✅ Create `.env` file
3. ✅ Start dev server
4. ✅ Open http://localhost:5173
5. 🎉 Start coding!

## Documentation

- [MODERNIZATION.md](./MODERNIZATION.md) - Full modernization guide
- [UPGRADE_SUMMARY.md](./UPGRADE_SUMMARY.md) - Complete summary
- [BEFORE_AFTER.md](./BEFORE_AFTER.md) - Visual comparisons

## Support

For questions about:
- **React Router**: https://reactrouter.com/
- **TanStack Query**: https://tanstack.com/query/latest
- **Zustand**: https://zustand-demo.pmnd.rs/
- **Framer Motion**: https://www.framer.com/motion/

Happy coding! 🚀


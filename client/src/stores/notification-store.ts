import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

export interface Notification {
  id: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  timestamp: Date;
}

interface NotificationStore {
  notifications: Notification[];
  addNotification: (
    message: string,
    type?: Notification['type'],
    duration?: number
  ) => void;
  removeNotification: (id: string) => void;
  clearNotifications: () => void;
}

export const useNotificationStore = create<NotificationStore>()(
  devtools((set) => ({
    notifications: [],

    addNotification: (message, type = 'info', duration = 5000) => {
      const id = `${Date.now()}-${Math.random()}`;
      const notification: Notification = {
        id,
        message,
        type,
        timestamp: new Date(),
      };

      set((state) => ({
        notifications: [notification, ...state.notifications.slice(0, 4)], // Keep max 5
      }));

      // Auto-remove after duration
      if (duration > 0) {
        setTimeout(() => {
          set((state) => ({
            notifications: state.notifications.filter((n) => n.id !== id),
          }));
        }, duration);
      }
    },

    removeNotification: (id) => {
      set((state) => ({
        notifications: state.notifications.filter((n) => n.id !== id),
      }));
    },

    clearNotifications: () => {
      set({ notifications: [] });
    },
  }))
);


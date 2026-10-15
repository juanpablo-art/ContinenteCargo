import { defineStore } from 'pinia';
import {
  collection,
  doc,
  onSnapshot,
  query,
  updateDoc,
  where,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import { useAuthStore } from '@/stores/auth';
import type { AppNotification } from '@/lib/domain';
import { parseNotification } from '@/lib/firestore-domain';

let unsub: Unsubscribe | null = null;

export const useNotificationsStore = defineStore('notifications', {
  state: () => ({
    items: [] as AppNotification[],
    ready: false,
  }),

  getters: {
    unreadCount: (s) => s.items.filter((n) => !n.isRead).length,
    sorted: (s) =>
      [...s.items].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
  },

  actions: {
    startListening() {
      const auth = useAuthStore();
      const uuid = auth.currentUser?.uuid;
      if (!uuid || unsub) return;
      const q = query(collection(db, 'notifications'), where('userId', '==', uuid));
      unsub = onSnapshot(q, (snap) => {
        this.items = snap.docs
          .map((d) => parseNotification({ id: d.id, ...d.data() }))
          .filter((n): n is AppNotification => n != null);
        this.ready = true;
      });
    },

    stopListening() {
      unsub?.();
      unsub = null;
      this.items = [];
      this.ready = false;
    },

    async markRead(id: string) {
      await updateDoc(doc(db, 'notifications', id), { isRead: true });
    },

    async markAllRead() {
      await Promise.all(
        this.items.filter((n) => !n.isRead).map((n) => this.markRead(n.id)),
      );
    },
  },
});

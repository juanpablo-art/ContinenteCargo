import { defineStore } from 'pinia';
import {
  collection,
  doc,
  onSnapshot,
  updateDoc,
  addDoc,
  type Unsubscribe,
  type DocumentData,
} from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import type { AppUser, UserStatus } from '@/lib/models';
import { parseUser } from '@/lib/firestore-user';
import type { Invitation } from '@/lib/domain';
import { parseInvitation } from '@/lib/firestore-domain';

let usersUnsub: Unsubscribe | null = null;
let invitesUnsub: Unsubscribe | null = null;

export const useCarriersStore = defineStore('carriers', {
  state: () => ({
    users: [] as AppUser[],
    /** Auth UID keyed by user.uuid for status updates */
    uidByUuid: {} as Record<string, string>,
    invitations: [] as Invitation[],
    ready: false,
  }),

  getters: {
    carriers: (s) =>
      s.users.filter(
        (u) => u.role === 'carrier' || u.role === 'independent_operator',
      ),
    pending: (s) =>
      s.users.filter(
        (u) =>
          u.status === 'pending_approval' &&
          (u.role === 'carrier' || u.role === 'independent_operator'),
      ),
    byUuid: (s) => (uuid: string) => s.users.find((u) => u.uuid === uuid),
  },

  actions: {
    startListening() {
      if (!usersUnsub) {
        usersUnsub = onSnapshot(collection(db, 'users'), (snap) => {
          const list: AppUser[] = [];
          const map: Record<string, string> = {};
          for (const d of snap.docs) {
            const user = parseUser(d.data() as DocumentData);
            if (!user) continue;
            list.push(user);
            map[user.uuid] = d.id;
          }
          this.users = list;
          this.uidByUuid = map;
          this.ready = true;
        });
      }
      if (!invitesUnsub) {
        invitesUnsub = onSnapshot(collection(db, 'invitations'), (snap) => {
          this.invitations = snap.docs
            .map((d) => parseInvitation(d.id, d.data()))
            .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        });
      }
    },

    stopListening() {
      usersUnsub?.();
      invitesUnsub?.();
      usersUnsub = null;
      invitesUnsub = null;
      this.users = [];
      this.invitations = [];
      this.ready = false;
    },

    async setStatus(uuid: string, status: UserStatus) {
      const uid = this.uidByUuid[uuid];
      if (!uid) return;
      await updateDoc(doc(db, 'users', uid), { status });
    },

    async sendInvitation(input: { name: string; phone?: string; email?: string }) {
      await addDoc(collection(db, 'invitations'), {
        name: input.name,
        phone: input.phone || '',
        email: input.email || '',
        status: 'sent',
        createdAt: new Date(),
      });
    },
  },
});

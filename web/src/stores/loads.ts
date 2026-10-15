import { defineStore } from 'pinia';
import {
  collection,
  doc,
  onSnapshot,
  setDoc,
  updateDoc,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import { useAuthStore } from '@/stores/auth';
import {
  coversLoad,
  isFull,
  isOpen,
  nextTripStatus,
  type Load,
  type LoadStatus,
  type StatusChange,
} from '@/lib/domain';
import {
  carrierConfirmationFields,
  loadToData,
  makeStatusChange,
  parseLoad,
} from '@/lib/firestore-domain';

let unsub: Unsubscribe | null = null;

export const useLoadsStore = defineStore('loads', {
  state: () => ({
    loads: [] as Load[],
    ready: false,
    error: null as string | null,
  }),

  getters: {
    byId: (s) => (id: string) => s.loads.find((l) => l.id === id),
    published: (s) => s.loads.filter((l) => l.status === 'Publicado'),
    needingCI: (s) =>
      s.loads.filter(
        (l) =>
          !l.cartaInstruccion &&
          (l.status === 'Asignado' ||
            (l.status === 'Publicado' && l.confirmedUnitCount > 0) ||
            ['En camino a recolección', 'En origen', 'Cargado', 'En tránsito'].includes(
              l.status,
            )),
      ),
  },

  actions: {
    startListening() {
      if (unsub) return;
      unsub = onSnapshot(
        collection(db, 'loads'),
        (snap) => {
          this.loads = snap.docs
            .map((d) => parseLoad(d.data()))
            .filter((l): l is Load => l != null)
            .sort((a, b) => b.publishedAt.getTime() - a.publishedAt.getTime());
          this.ready = true;
          this.error = null;
        },
        (err) => {
          this.error = err.message;
          this.ready = true;
        },
      );
    },

    stopListening() {
      unsub?.();
      unsub = null;
      this.loads = [];
      this.ready = false;
    },

    loadsForCurrentUser(): Load[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      if (user.role === 'admin') return this.loads;
      return this.loads.filter((load) => {
        if (load.confirmedCarrierIds.includes(user.uuid)) return true;
        if (load.assignedCarrierId === user.uuid) return true;
        if (load.status !== 'Publicado' || isFull(load)) return false;
        if (load.assignmentMode === 'Consolidada LTL') {
          return user.handlesLTL && Date.now() < load.deadline.getTime();
        }
        return coversLoad(user, load);
      });
    },

    availableForCarrier(): Load[] {
      return this.loadsForCurrentUser()
        .filter((l) => isOpen(l))
        .sort((a, b) => a.deadline.getTime() - b.deadline.getTime());
    },

    myTrips(wonLoadIds: Set<string>): Load[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      return this.loads
        .filter(
          (l) =>
            l.assignedCarrierId === user.uuid ||
            l.assignedOperatorId === user.uuid ||
            l.confirmedCarrierIds.includes(user.uuid) ||
            wonLoadIds.has(l.id),
        )
        .sort((a, b) => b.pickupDate.getTime() - a.pickupDate.getTime());
    },

    async publishLoad(load: Load) {
      const auth = useAuthStore();
      const history: StatusChange[] = [
        makeStatusChange(
          'Publicado',
          auth.currentUser?.uuid ?? load.publishedBy,
          auth.currentUser?.name ?? 'Admin',
        ),
      ];
      const payload: Load = { ...load, statusHistory: history, status: 'Publicado' };
      await setDoc(doc(db, 'loads', payload.id), loadToData(payload));
    },

    async cancelLoad(loadId: string, reason = '') {
      const auth = useAuthStore();
      const load = this.byId(loadId);
      if (!load) return;
      const history = [
        ...load.statusHistory,
        makeStatusChange(
          'Cancelado',
          auth.currentUser?.uuid ?? '',
          auth.currentUser?.name ?? 'Admin',
          reason,
        ),
      ];
      const updated: Load = { ...load, status: 'Cancelado', statusHistory: history };
      await setDoc(doc(db, 'loads', loadId), loadToData(updated), { merge: true });
    },

    async updateLoadStatus(loadId: string, status: LoadStatus, notes = '') {
      const auth = useAuthStore();
      const load = this.byId(loadId);
      if (!load) return;
      const history = [
        ...load.statusHistory,
        makeStatusChange(
          status,
          auth.currentUser?.uuid ?? '',
          auth.currentUser?.name ?? 'Usuario',
          notes,
        ),
      ];
      const updated: Load = { ...load, status, statusHistory: history };
      await setDoc(doc(db, 'loads', loadId), loadToData(updated), { merge: true });
    },

    async advanceTrip(loadId: string, trackingUrl?: string) {
      const load = this.byId(loadId);
      if (!load) return;
      const next = nextTripStatus(load.status);
      if (!next) return;
      if (trackingUrl != null) load.trackingUrl = trackingUrl;
      await this.updateLoadStatus(loadId, next);
      if (trackingUrl != null) {
        await updateDoc(doc(db, 'loads', loadId), { trackingUrl });
      }
    },

    async applyCarrierConfirmation(updated: Load) {
      await updateDoc(doc(db, 'loads', updated.id), carrierConfirmationFields(updated));
    },

    async updateLoadFields(loadId: string, fields: Record<string, unknown>) {
      await updateDoc(doc(db, 'loads', loadId), fields);
    },

    async saveCartaInstruccion(
      loadId: string,
      carta: NonNullable<Load['cartaInstruccion']>,
    ) {
      await updateDoc(doc(db, 'loads', loadId), {
        cartaInstruccion: {
          ...carta,
          creadaAt: carta.creadaAt,
        },
      });
    },
  },
});

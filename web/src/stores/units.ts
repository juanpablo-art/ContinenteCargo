import { defineStore } from 'pinia';
import {
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  setDoc,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import { useAuthStore } from '@/stores/auth';
import type { Unit } from '@/lib/domain';
import { parseUnit, unitToData } from '@/lib/firestore-domain';

let unsub: Unsubscribe | null = null;

export const useUnitsStore = defineStore('units', {
  state: () => ({
    units: [] as Unit[],
    ready: false,
  }),

  getters: {
    myUnits(): Unit[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      if (user.role === 'admin') return this.units;
      return this.units.filter(
        (u) => u.ownerId === user.uuid || u.ownerId === user.companyId,
      );
    },
    available: (s) => s.units.filter((u) => u.status === 'Disponible'),
  },

  actions: {
    startListening() {
      if (unsub) return;
      unsub = onSnapshot(collection(db, 'units'), (snap) => {
        this.units = snap.docs
          .map((d) => parseUnit(d.data()))
          .filter((u): u is Unit => u != null);
        this.ready = true;
      });
    },

    stopListening() {
      unsub?.();
      unsub = null;
      this.units = [];
      this.ready = false;
    },

    async saveUnit(unit: Unit) {
      await setDoc(doc(db, 'units', unit.id), unitToData(unit));
    },

    async deleteUnit(unitId: string) {
      await deleteDoc(doc(db, 'units', unitId));
    },

    async postQuickAvailability(input: {
      equipmentType: Unit['equipmentType'];
      originState: string;
      destinationState: string;
      count: number;
      notes?: string;
    }) {
      const auth = useAuthStore();
      if (!auth.currentUser) return;
      const unit: Unit = {
        id: crypto.randomUUID(),
        ownerId: auth.currentUser.uuid,
        equipmentType: input.equipmentType,
        plates: '',
        trailerNumber: String(input.count),
        currentLocation: input.originState,
        operatorName: '',
        scac: '',
        caat: '',
        availableFrom: new Date(),
        coverageZones: [],
        status: 'Disponible',
        notes: 'availability_post',
        postedOriginState: input.originState,
        postedDestinationState: input.destinationState,
        isAvailabilityPosted: true,
      };
      await this.saveUnit(unit);
    },
  },
});

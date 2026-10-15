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
import { useLoadsStore } from '@/stores/loads';
import {
  isFull,
  type Offer,
  type OfferStatus,
} from '@/lib/domain';
import {
  makeStatusChange,
  offerToData,
  parseOffer,
} from '@/lib/firestore-domain';
import { loadToData } from '@/lib/firestore-domain';

let unsub: Unsubscribe | null = null;

const MY_STATUSES: OfferStatus[] = [
  'Activa',
  'Ganando',
  'Superada',
  'PendienteAprobacion',
];

export const useOffersStore = defineStore('offers', {
  state: () => ({
    offers: [] as Offer[],
    ready: false,
  }),

  getters: {
    forLoad: (s) => (loadId: string) =>
      s.offers
        .filter((o) => o.loadId === loadId)
        .sort((a, b) => a.amount - b.amount),
    myOffers(): Offer[] {
      const auth = useAuthStore();
      const uid = auth.currentUser?.uuid;
      if (!uid) return [];
      return this.offers.filter(
        (o) => o.carrierId === uid && MY_STATUSES.includes(o.status),
      );
    },
    wonLoadIds(): Set<string> {
      const auth = useAuthStore();
      const uid = auth.currentUser?.uuid;
      if (!uid) return new Set();
      return new Set(
        this.offers
          .filter((o) => o.carrierId === uid && o.status === 'Ganadora')
          .map((o) => o.loadId),
      );
    },
    pendingApproval: (s) =>
      s.offers.filter((o) => o.status === 'PendienteAprobacion'),
  },

  actions: {
    startListening() {
      if (unsub) return;
      unsub = onSnapshot(collection(db, 'offers'), (snap) => {
        this.offers = snap.docs
          .map((d) => parseOffer(d.data()))
          .filter((o): o is Offer => o != null)
          .sort((a, b) => b.submittedAt.getTime() - a.submittedAt.getTime());
        this.ready = true;
      });
    },

    stopListening() {
      unsub?.();
      unsub = null;
      this.offers = [];
      this.ready = false;
    },

    async saveOffer(offer: Offer) {
      await setDoc(doc(db, 'offers', offer.id), offerToData(offer));
    },

    async updateOfferFields(offerId: string, fields: Record<string, unknown>) {
      await updateDoc(doc(db, 'offers', offerId), fields);
    },

    async takeLoad(opts: {
      loadId: string;
      unitId?: string;
      availableUnitCount: number;
      unitETA?: Date;
      trackingUrl?: string;
      proposedPricePerUnit?: number;
    }): Promise<'success' | 'pendingApproval' | 'error' | string> {
      const auth = useAuthStore();
      const loads = useLoadsStore();
      const user = auth.currentUser;
      const load = loads.byId(opts.loadId);
      if (!user || user.status !== 'approved') return 'Tu cuenta no está aprobada';
      if (!load) return 'Carga no encontrada';
      if (load.status !== 'Publicado') return 'La carga ya no está disponible';
      if (Date.now() >= load.deadline.getTime()) return 'La fecha límite pasó';
      if (isFull(load)) return 'La carga ya está completa';
      if (load.confirmedCarrierIds.includes(user.uuid)) {
        return 'Ya confirmaste esta carga';
      }

      const proposed = opts.proposedPricePerUnit ?? load.offeredPrice;
      const needsApproval =
        proposed > load.offeredPrice && load.maxAuthorizedPriceSinIVA == null;

      if (needsApproval || (load.assignmentMode !== 'Tarifa Fija' && proposed > load.offeredPrice)) {
        if (proposed > load.offeredPrice) {
          const offer: Offer = {
            id: crypto.randomUUID(),
            loadId: load.id,
            carrierId: user.uuid,
            carrierName: user.name,
            unitId: opts.unitId,
            amount: proposed * opts.availableUnitCount,
            currency: load.currency,
            isAvailabilityOnly: false,
            proposedPrice: proposed,
            availableUnitCount: opts.availableUnitCount,
            status: 'PendienteAprobacion',
            submittedAt: new Date(),
            notes: opts.trackingUrl ? `Rastreo: ${opts.trackingUrl}` : '',
          };
          await this.saveOffer(offer);
          return 'pendingApproval';
        }
      }

      if (load.assignmentMode === 'Subasta Inversa') {
        return this.placeBid(load.id, proposed, opts.unitId, opts.availableUnitCount);
      }

      if (load.assignmentMode === 'Confirmación Manual') {
        const offer: Offer = {
          id: crypto.randomUUID(),
          loadId: load.id,
          carrierId: user.uuid,
          carrierName: user.name,
          unitId: opts.unitId,
          amount: proposed,
          currency: load.currency,
          isAvailabilityOnly: false,
          proposedPrice: proposed,
          availableUnitCount: opts.availableUnitCount,
          status: 'Activa',
          submittedAt: new Date(),
          notes: '',
        };
        await this.saveOffer(offer);
        return 'success';
      }

      if (load.assignmentMode === 'Consolidada LTL') {
        const offer: Offer = {
          id: crypto.randomUUID(),
          loadId: load.id,
          carrierId: user.uuid,
          carrierName: user.name,
          amount: proposed,
          currency: load.currency,
          isAvailabilityOnly: false,
          proposedPrice: proposed,
          availableUnitCount: 1,
          status: 'Activa',
          submittedAt: new Date(),
          notes: '',
        };
        await this.saveOffer(offer);
        return 'success';
      }

      // Tarifa Fija confirm
      const remaining = load.unitCount - load.confirmedUnitCount;
      const add = Math.min(opts.availableUnitCount, Math.max(1, remaining));
      const confirmedCarrierIds = [...load.confirmedCarrierIds, user.uuid];
      const confirmedUnitCount = load.confirmedUnitCount + add;
      const updated = { ...load, confirmedCarrierIds, confirmedUnitCount };
      updated.trackingUrl = opts.trackingUrl || load.trackingUrl;
      if (opts.unitId) updated.assignedUnitId = opts.unitId;
      if (opts.unitETA) updated.unitETA = opts.unitETA;

      const willFull = confirmedUnitCount >= load.unitCount;
      if (willFull) {
        updated.status = 'Asignado';
        updated.assignedCarrierId = user.uuid;
        updated.statusHistory = [
          ...load.statusHistory,
          makeStatusChange(
            'Asignado',
            user.uuid,
            user.name,
            `Todas las unidades confirmadas (${load.unitCount}/${load.unitCount})`,
          ),
        ];
      } else {
        updated.statusHistory = [
          ...load.statusHistory,
          makeStatusChange(
            'Publicado',
            user.uuid,
            user.name,
            `Unidad confirmada (${confirmedUnitCount}/${load.unitCount})`,
          ),
        ];
      }

      if (willFull || load.unitCount > 1) {
        await loads.applyCarrierConfirmation(updated);
      }

      const won: Offer = {
        id: crypto.randomUUID(),
        loadId: load.id,
        carrierId: user.uuid,
        carrierName: user.name,
        unitId: opts.unitId,
        amount: load.offeredPrice,
        currency: load.currency,
        isAvailabilityOnly: false,
        availableUnitCount: opts.availableUnitCount,
        status: 'Ganadora',
        submittedAt: new Date(),
        notes: '',
      };
      await this.saveOffer(won);
      return 'success';
    },

    async placeBid(
      loadId: string,
      amount: number,
      unitId?: string,
      availableUnitCount = 1,
    ): Promise<'success' | string> {
      const auth = useAuthStore();
      const loads = useLoadsStore();
      const user = auth.currentUser;
      const load = loads.byId(loadId);
      if (!user || user.status !== 'approved') return 'No aprobado';
      if (!load || load.assignmentMode !== 'Subasta Inversa') return 'No es subasta';
      if (load.status !== 'Publicado') return 'Cerrada';
      if (Date.now() >= load.deadline.getTime()) return 'Deadline pasado';

      const existing = this.offers.find(
        (o) =>
          o.loadId === loadId &&
          o.carrierId === user.uuid &&
          (o.status === 'Activa' || o.status === 'Ganando'),
      );
      if (existing && amount < existing.amount) {
        if (amount > existing.amount - load.minBidDecrement) {
          return `Decremento mínimo: ${load.minBidDecrement}`;
        }
        await this.updateOfferFields(existing.id, { status: 'Cancelada' });
      }

      // Mark previous winners as Superada
      const others = this.offers.filter(
        (o) =>
          o.loadId === loadId &&
          o.carrierId !== user.uuid &&
          (o.status === 'Activa' || o.status === 'Ganando'),
      );
      const winningAmount = Math.min(
        amount,
        ...others.map((o) => o.amount),
        amount,
      );
      for (const o of others) {
        if (o.amount > amount) {
          await this.updateOfferFields(o.id, { status: 'Superada' });
        }
      }

      const offer: Offer = {
        id: crypto.randomUUID(),
        loadId,
        carrierId: user.uuid,
        carrierName: user.name,
        unitId,
        amount,
        currency: load.currency,
        isAvailabilityOnly: false,
        availableUnitCount,
        status: amount <= winningAmount ? 'Ganando' : 'Activa',
        submittedAt: new Date(),
        notes: '',
      };
      await this.saveOffer(offer);
      return 'success';
    },

    async approveCounterOffer(offerId: string) {
      const auth = useAuthStore();
      const loads = useLoadsStore();
      const offer = this.offers.find((o) => o.id === offerId);
      if (!offer || offer.status !== 'PendienteAprobacion') return;
      const load = loads.byId(offer.loadId);
      if (!load) return;

      await this.updateOfferFields(offerId, { status: 'Ganadora' });

      const remaining = load.unitCount - load.confirmedUnitCount;
      const unitsToConfirm = Math.min(offer.availableUnitCount, Math.max(1, remaining));
      const confirmedCarrierIds = [...load.confirmedCarrierIds, offer.carrierId];
      const confirmedUnitCount = load.confirmedUnitCount + unitsToConfirm;
      const updated = { ...load, confirmedCarrierIds, confirmedUnitCount };
      updated.assignedPriceSinIVA = offer.proposedPrice ?? offer.amount;
      if (offer.unitId) updated.assignedUnitId = offer.unitId;
      if (offer.operatorId) updated.assignedOperatorId = offer.operatorId;

      if (confirmedUnitCount >= load.unitCount) {
        updated.status = 'Asignado';
        updated.assignedCarrierId = offer.carrierId;
        updated.statusHistory = [
          ...load.statusHistory,
          makeStatusChange(
            'Asignado',
            auth.currentUser?.uuid ?? '',
            auth.currentUser?.name ?? 'Admin',
            'Contra-oferta aprobada por administrador',
          ),
        ];
      } else {
        updated.statusHistory = [
          ...load.statusHistory,
          makeStatusChange(
            'Publicado',
            auth.currentUser?.uuid ?? '',
            auth.currentUser?.name ?? 'Admin',
            `Contra-oferta aprobada (${confirmedUnitCount}/${load.unitCount})`,
          ),
        ];
      }
      await setDoc(doc(db, 'loads', load.id), loadToData(updated), { merge: true });
    },

    async rejectCounterOffer(offerId: string) {
      await this.updateOfferFields(offerId, { status: 'Rechazada' });
    },

    async updateMyOffer(offerId: string, amountPerUnit: number, unitCount: number) {
      const offer = this.offers.find((o) => o.id === offerId);
      if (!offer || !MY_STATUSES.includes(offer.status)) return;
      await this.updateOfferFields(offerId, {
        proposedPrice: amountPerUnit,
        amount: amountPerUnit * Math.max(1, unitCount),
        availableUnitCount: unitCount,
      });
    },
  },
});

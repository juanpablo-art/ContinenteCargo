import { defineStore } from 'pinia';
import type { Unsubscribe } from 'firebase/firestore';
import { useAuthStore } from '@/stores/auth';
import { coversLoad } from '@/lib/coverage';
import {
  deleteUnitDoc,
  fetchUserByPhone,
  listenToCompanies,
  listenToLoads,
  listenToNotifications,
  listenToOffers,
  listenToOwnUser,
  listenToUnits,
  listenToUsers,
  saveLoad,
  saveNotification,
  saveOffer,
  saveUnit,
  updateLoadFields,
  updateLoadForCarrierConfirmation,
  updateNotificationFields,
  updateOfferFields,
  updateUnitFields,
  updateUserLTL,
  updateUserRoutes,
  updateUserStatus,
} from '@/lib/firestore-data';
import {
  loadIsFull,
  newUuid,
  type AppNotification,
  type AppUser,
  type EquipmentType,
  type Load,
  type LoadStatus,
  type NotificationType,
  type Offer,
  type OfferStatus,
  type TransportCompany,
  type Unit,
  type UnitStatus,
} from '@/lib/models';

export type TakeLoadResult =
  | 'success'
  | 'alreadyAssigned'
  | 'notApproved'
  | 'deadlinePassed'
  | 'noUnit'
  | 'pendingApproval';

export type BidResult =
  | 'success'
  | 'deadlinePassed'
  | 'notApproved'
  | 'decrementTooSmall'
  | 'alreadyAssigned';

let unsubs: Unsubscribe[] = [];

function makeStatusChange(
  status: LoadStatus,
  changedBy: string,
  changedByName: string,
  notes = '',
) {
  return {
    id: newUuid(),
    status,
    changedBy,
    changedByName,
    changedAt: new Date(),
    notes,
  };
}

export const useDataStore = defineStore('data', {
  state: () => ({
    loads: [] as Load[],
    offers: [] as Offer[],
    units: [] as Unit[],
    notifications: [] as AppNotification[],
    users: [] as AppUser[],
    companies: [] as TransportCompany[],
    listening: false,
    errorMessage: null as string | null,
  }),

  getters: {
    unreadCount(state): number {
      const auth = useAuthStore();
      const uid = auth.currentUser?.uuid;
      if (!uid) return 0;
      return state.notifications.filter((n) => n.userId === uid && !n.isRead).length;
    },
  },

  actions: {
    startListeners() {
      this.stopListeners();
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user || user.uuid === 'demo-layout') return;

      this.loads = [];
      this.units = [];
      this.offers = [];
      this.notifications = [];
      this.companies = [];
      this.users = user.role === 'admin' ? [] : [user];

      unsubs.push(
        listenToLoads((incoming) => {
          this.loads = incoming;
        }),
      );
      unsubs.push(
        listenToUnits((incoming) => {
          // Preserve in-memory availability posts (not in Firestore schema)
          this.units = incoming.map((incomingUnit) => {
            const existing = this.units.find((u) => u.id === incomingUnit.id);
            if (!existing?.isAvailabilityPosted) return incomingUnit;
            return {
              ...incomingUnit,
              isAvailabilityPosted: existing.isAvailabilityPosted,
              postedOriginState: existing.postedOriginState,
              postedDestinationState: existing.postedDestinationState,
            };
          });
        }),
      );
      unsubs.push(
        listenToOffers((incoming) => {
          this.offers = incoming;
        }),
      );
      unsubs.push(
        listenToNotifications(user.uuid, (incoming) => {
          this.notifications = incoming.sort(
            (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
          );
        }),
      );

      if (user.role === 'admin') {
        unsubs.push(
          listenToUsers((incoming) => {
            this.users = incoming;
          }),
        );
        unsubs.push(
          listenToCompanies((incoming) => {
            this.companies = incoming;
          }),
        );
      } else {
        unsubs.push(
          listenToOwnUser((incoming) => {
            if (!incoming) return;
            this.users = [incoming];
            if (auth.currentUser?.uuid === incoming.uuid) {
              auth.currentUser = incoming;
            }
          }),
        );
      }

      this.listening = true;
    },

    stopListeners() {
      unsubs.forEach((u) => u());
      unsubs = [];
      this.listening = false;
      this.loads = [];
      this.offers = [];
      this.units = [];
      this.notifications = [];
      this.users = [];
      this.companies = [];
    },

    // ── Helpers ───────────────────────────────────────────────────────

    loadsForCurrentUser(): Load[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      if (user.role === 'admin') return this.loads;

      return this.loads.filter((load) => {
        if (load.confirmedCarrierIds.includes(user.uuid)) return true;
        if (load.assignedCarrierId === user.uuid) return true;
        if (load.status !== 'Publicado' || loadIsFull(load)) return false;
        if (load.assignmentMode === 'Consolidada LTL') {
          return user.handlesLTL && new Date() < load.deadline;
        }
        return coversLoad(
          user,
          load.originCity,
          load.originState,
          load.destinationCity,
          load.destinationState,
          load.equipmentType,
        );
      });
    },

    myOffers(): Offer[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      const pending: OfferStatus[] = [
        'Activa',
        'Ganando',
        'Superada',
        'PendienteAprobacion',
      ];
      return this.offers.filter(
        (o) => o.carrierId === user.uuid && pending.includes(o.status),
      );
    },

    myTrips(): Load[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      const wonLoadIds = new Set(
        this.offers
          .filter((o) => o.carrierId === user.uuid && o.status === 'Ganadora')
          .map((o) => o.loadId),
      );
      return this.loads.filter(
        (l) =>
          l.assignedCarrierId === user.uuid ||
          l.assignedOperatorId === user.uuid ||
          l.confirmedCarrierIds.includes(user.uuid) ||
          wonLoadIds.has(l.id),
      );
    },

    myUnits(): Unit[] {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return [];
      if (user.role === 'admin') return this.units;
      return this.units.filter(
        (u) => u.ownerId === user.uuid || u.ownerId === user.companyId,
      );
    },

    offersForLoad(loadId: string): Offer[] {
      return this.offers
        .filter((o) => o.loadId === loadId)
        .sort((a, b) => a.amount - b.amount);
    },

    pendingUsers(): AppUser[] {
      return this.users.filter(
        (u) => u.status === 'pending_approval' && u.role !== 'admin',
      );
    },

    loadById(id: string): Load | undefined {
      return this.loads.find((l) => l.id === id);
    },

    canSeePrivateFields(load: Load): boolean {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return false;
      if (user.role === 'admin') return true;
      return (
        load.assignedCarrierId === user.uuid ||
        load.confirmedCarrierIds.includes(user.uuid)
      );
    },

    // ── Notifications ─────────────────────────────────────────────────

    async notify(
      userId: string,
      type: NotificationType,
      title: string,
      body: string,
      loadId?: string,
    ) {
      const n: AppNotification = {
        id: newUuid(),
        userId,
        type,
        title,
        body,
        loadId,
        isRead: false,
        createdAt: new Date(),
      };
      await saveNotification(n);
    },

    async markNotificationRead(id: string) {
      const idx = this.notifications.findIndex((n) => n.id === id);
      if (idx < 0) return;
      this.notifications[idx].isRead = true;
      await updateNotificationFields(id, { isRead: true });
    },

    async markAllRead() {
      const auth = useAuthStore();
      const uid = auth.currentUser?.uuid;
      if (!uid) return;
      for (const n of this.notifications) {
        if (n.userId === uid && !n.isRead) {
          n.isRead = true;
          await updateNotificationFields(n.id, { isRead: true });
        }
      }
    },

    // ── Carrier approval ──────────────────────────────────────────────

    async approveCarrier(userId: string) {
      const idx = this.users.findIndex((u) => u.uuid === userId);
      if (idx < 0) return;
      this.users[idx].status = 'approved';
      await updateUserStatus(userId, 'approved');
      await this.notify(
        userId,
        'registration_approved',
        'Registro aprobado',
        'Tu registro fue aprobado. Ya puedes participar en cargas.',
      );
    },

    async rejectCarrier(userId: string) {
      const idx = this.users.findIndex((u) => u.uuid === userId);
      if (idx < 0) return;
      this.users[idx].status = 'rejected';
      await updateUserStatus(userId, 'rejected');
      await this.notify(
        userId,
        'registration_rejected',
        'Registro rechazado',
        'Tu solicitud de registro no fue aprobada. Contacta a Continente Cargo.',
      );
    },

    // ── Loads ─────────────────────────────────────────────────────────

    async publishLoad(load: Load) {
      const auth = useAuthStore();
      const published: Load = {
        ...load,
        statusHistory: [
          makeStatusChange(
            'Publicado',
            load.publishedBy,
            auth.currentUser?.name ?? 'Admin',
          ),
        ],
      };
      this.loads.push(published);
      await saveLoad(published);
      await this.notifyCarriersForNewLoad(published);
    },

    async notifyCarriersForNewLoad(load: Load) {
      if (!load.notificationChannels.inApp) return;
      const matching = this.users.filter(
        (u) =>
          u.role !== 'admin' &&
          coversLoad(
            u,
            load.originCity,
            load.originState,
            load.destinationCity,
            load.destinationState,
            load.equipmentType,
          ),
      );
      for (const carrier of matching) {
        await this.notify(
          carrier.uuid,
          'new_load',
          'Nueva carga en tu ruta',
          `${load.originCity}, ${load.originState} → ${load.destinationCity}, ${load.destinationState} · ${load.equipmentType}`,
          load.id,
        );
      }
    },

    async cancelLoad(loadId: string, reason = '') {
      const idx = this.loads.findIndex((l) => l.id === loadId);
      if (idx < 0) return;
      const auth = useAuthStore();
      this.loads[idx].status = 'Cancelado';
      this.loads[idx].statusHistory.push(
        makeStatusChange(
          'Cancelado',
          auth.currentUser?.uuid ?? '',
          auth.currentUser?.name ?? 'Sistema',
          reason,
        ),
      );
      for (const offer of this.offers) {
        if (offer.loadId === loadId) {
          offer.status = 'Cancelada';
          await updateOfferFields(offer.id, { status: 'Cancelada' });
        }
      }
      await saveLoad(this.loads[idx]);
    },

    async updateLoadStatus(loadId: string, status: LoadStatus, notes = '') {
      const idx = this.loads.findIndex((l) => l.id === loadId);
      if (idx < 0) return;
      const auth = useAuthStore();
      this.loads[idx].status = status;
      this.loads[idx].statusHistory.push(
        makeStatusChange(
          status,
          auth.currentUser?.uuid ?? '',
          auth.currentUser?.name ?? 'Sistema',
          notes,
        ),
      );
      await saveLoad(this.loads[idx]);
    },

    // ── Take load (fixed rate) ────────────────────────────────────────

    async takeLoad(opts: {
      loadId: string;
      unitId?: string;
      operatorId?: string;
      unitETA?: Date;
      trackingUrl?: string;
      availableUnitCount?: number;
    }): Promise<TakeLoadResult> {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user || user.status !== 'approved') return 'notApproved';

      const loadIdx = this.loads.findIndex((l) => l.id === opts.loadId);
      if (loadIdx < 0) return 'noUnit';

      const load = this.loads[loadIdx];
      if (load.status !== 'Publicado') return 'alreadyAssigned';
      if (new Date() >= load.deadline) return 'deadlinePassed';
      if (load.assignmentMode !== 'Tarifa Fija') return 'alreadyAssigned';
      if (loadIsFull(load)) return 'alreadyAssigned';
      if (load.confirmedCarrierIds.includes(user.uuid)) return 'alreadyAssigned';

      let optUnitIdx: number | undefined;
      if (opts.unitId) {
        const idx = this.units.findIndex((u) => u.id === opts.unitId);
        if (
          idx < 0 ||
          this.units[idx].status !== 'Disponible' ||
          this.units[idx].availableFrom > load.pickupDate
        ) {
          return 'noUnit';
        }
        optUnitIdx = idx;
      }

      const availableUnitCount = opts.availableUnitCount ?? 1;
      this.loads[loadIdx].confirmedCarrierIds = [
        ...this.loads[loadIdx].confirmedCarrierIds,
        user.uuid,
      ];
      const remaining =
        this.loads[loadIdx].unitCount - this.loads[loadIdx].confirmedUnitCount;
      this.loads[loadIdx].confirmedUnitCount += Math.min(
        availableUnitCount,
        Math.max(1, remaining),
      );

      if (opts.unitId) this.loads[loadIdx].assignedUnitId = opts.unitId;
      this.loads[loadIdx].assignedOperatorId = opts.operatorId;
      this.loads[loadIdx].unitETA = opts.unitETA;
      this.loads[loadIdx].trackingUrl = opts.trackingUrl ?? '';
      if (optUnitIdx != null) this.units[optUnitIdx].status = 'Reservada';

      if (loadIsFull(this.loads[loadIdx])) {
        this.loads[loadIdx].status = 'Asignado';
        this.loads[loadIdx].assignedCarrierId = user.uuid;
        this.loads[loadIdx].statusHistory.push(
          makeStatusChange(
            'Asignado',
            user.uuid,
            user.name,
            `Todas las unidades confirmadas (${this.loads[loadIdx].unitCount}/${this.loads[loadIdx].unitCount})`,
          ),
        );
      } else {
        this.loads[loadIdx].statusHistory.push(
          makeStatusChange(
            'Publicado',
            user.uuid,
            user.name,
            `Unidad confirmada (${this.loads[loadIdx].confirmedUnitCount}/${this.loads[loadIdx].unitCount})`,
          ),
        );
      }

      const wonOffer: Offer = {
        id: newUuid(),
        loadId: opts.loadId,
        carrierId: user.uuid,
        carrierName: user.name,
        unitId: opts.unitId,
        amount: load.offeredPrice,
        currency: load.currency,
        isAvailabilityOnly: false,
        availableUnitCount,
        status: 'Ganadora',
        submittedAt: new Date(),
        notes: '',
      };
      this.offers.push(wonOffer);

      const isMultiUnit = this.loads[loadIdx].unitCount > 1;
      if (loadIsFull(this.loads[loadIdx]) || isMultiUnit) {
        await updateLoadForCarrierConfirmation(this.loads[loadIdx]);
      }
      if (optUnitIdx != null) await saveUnit(this.units[optUnitIdx]);
      await saveOffer(wonOffer);

      await this.notify(
        user.uuid,
        'load_assigned',
        '¡Participación confirmada!',
        `Confirmaste tu unidad para el viaje ${load.reference}.`,
        opts.loadId,
      );

      return 'success';
    },

    async submitCounterOffer(opts: {
      loadId: string;
      unitId?: string;
      operatorId?: string;
      unitETA?: Date;
      trackingUrl?: string;
      availableUnitCount: number;
      proposedPricePerUnit: number;
    }): Promise<TakeLoadResult> {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user || user.status !== 'approved') return 'notApproved';
      const load = this.loads.find((l) => l.id === opts.loadId);
      if (!load) return 'noUnit';
      if (load.status !== 'Publicado') return 'alreadyAssigned';
      if (new Date() >= load.deadline) return 'deadlinePassed';

      const offer: Offer = {
        id: newUuid(),
        loadId: opts.loadId,
        carrierId: user.uuid,
        carrierName: user.name,
        unitId: opts.unitId,
        operatorId: opts.operatorId,
        amount: opts.proposedPricePerUnit * opts.availableUnitCount,
        currency: load.currency,
        isAvailabilityOnly: false,
        proposedPrice: opts.proposedPricePerUnit,
        availableUnitCount: opts.availableUnitCount,
        status: 'PendienteAprobacion',
        submittedAt: new Date(),
        notes: opts.trackingUrl ? `Rastreo: ${opts.trackingUrl}` : '',
      };
      this.offers.push(offer);
      await saveOffer(offer);
      return 'pendingApproval';
    },

    async approveCounterOffer(offerId: string) {
      const offerIdx = this.offers.findIndex((o) => o.id === offerId);
      if (offerIdx < 0 || this.offers[offerIdx].status !== 'PendienteAprobacion') return;
      const offer = this.offers[offerIdx];
      const loadIdx = this.loads.findIndex((l) => l.id === offer.loadId);
      if (loadIdx < 0) return;
      const auth = useAuthStore();

      this.offers[offerIdx].status = 'Ganadora';
      this.loads[loadIdx].assignedPriceSinIVA =
        offer.proposedPrice ?? offer.amount;

      const remaining =
        this.loads[loadIdx].unitCount - this.loads[loadIdx].confirmedUnitCount;
      const unitsToConfirm = Math.min(offer.availableUnitCount, Math.max(1, remaining));
      this.loads[loadIdx].confirmedCarrierIds = [
        ...this.loads[loadIdx].confirmedCarrierIds,
        offer.carrierId,
      ];
      this.loads[loadIdx].confirmedUnitCount += unitsToConfirm;
      if (offer.unitId) this.loads[loadIdx].assignedUnitId = offer.unitId;
      this.loads[loadIdx].assignedOperatorId = offer.operatorId;

      if (loadIsFull(this.loads[loadIdx])) {
        this.loads[loadIdx].status = 'Asignado';
        this.loads[loadIdx].assignedCarrierId = offer.carrierId;
        this.loads[loadIdx].statusHistory.push(
          makeStatusChange(
            'Asignado',
            auth.currentUser?.uuid ?? '',
            auth.currentUser?.name ?? 'Admin',
            'Contra-oferta aprobada por administrador',
          ),
        );
      } else {
        this.loads[loadIdx].statusHistory.push(
          makeStatusChange(
            'Publicado',
            auth.currentUser?.uuid ?? '',
            auth.currentUser?.name ?? 'Admin',
            `Contra-oferta aprobada (${this.loads[loadIdx].confirmedUnitCount}/${this.loads[loadIdx].unitCount})`,
          ),
        );
      }

      await saveLoad(this.loads[loadIdx]);
      await updateOfferFields(offerId, { status: 'Ganadora' });
      await this.notify(
        offer.carrierId,
        'load_assigned',
        '¡Propuesta aprobada!',
        'Tu contra-oferta para el viaje fue aprobada.',
        offer.loadId,
      );
    },

    async rejectCounterOffer(offerId: string) {
      const offerIdx = this.offers.findIndex((o) => o.id === offerId);
      if (offerIdx < 0 || this.offers[offerIdx].status !== 'PendienteAprobacion') return;
      this.offers[offerIdx].status = 'Rechazada';
      await updateOfferFields(offerId, { status: 'Rechazada' });
    },

    // ── Bids ──────────────────────────────────────────────────────────

    async placeBid(opts: {
      loadId: string;
      amount: number;
      unitId?: string;
      availableUnitCount?: number;
    }): Promise<BidResult> {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user || user.status !== 'approved') return 'notApproved';
      const load = this.loads.find((l) => l.id === opts.loadId);
      if (!load) return 'alreadyAssigned';
      if (load.status !== 'Publicado' || load.assignmentMode !== 'Subasta Inversa') {
        return 'alreadyAssigned';
      }
      if (new Date() >= load.deadline) return 'deadlinePassed';

      const existingIdx = this.offers.findIndex(
        (o) =>
          o.loadId === opts.loadId &&
          o.carrierId === user.uuid &&
          (o.status === 'Activa' || o.status === 'Ganando'),
      );
      if (existingIdx >= 0) {
        const existing = this.offers[existingIdx];
        if (opts.amount < existing.amount) {
          if (opts.amount > existing.amount - load.minBidDecrement) {
            return 'decrementTooSmall';
          }
        }
        this.offers[existingIdx].status = 'Cancelada';
        await updateOfferFields(this.offers[existingIdx].id, { status: 'Cancelada' });
      }

      const status = await this.updateBidStatuses(opts.loadId, opts.amount);
      const offer: Offer = {
        id: newUuid(),
        loadId: opts.loadId,
        carrierId: user.uuid,
        carrierName: user.name,
        unitId: opts.unitId,
        amount: opts.amount,
        currency: load.currency,
        isAvailabilityOnly: false,
        availableUnitCount: opts.availableUnitCount ?? 1,
        status,
        submittedAt: new Date(),
        notes: '',
      };
      this.offers.push(offer);
      await saveOffer(offer);
      return 'success';
    },

    async updateBidStatuses(loadId: string, newAmount: number): Promise<OfferStatus> {
      const active = this.offers.filter(
        (o) =>
          o.loadId === loadId && (o.status === 'Activa' || o.status === 'Ganando'),
      );
      const minExisting = active.length
        ? Math.min(...active.map((o) => o.amount))
        : Number.POSITIVE_INFINITY;

      if (newAmount < minExisting) {
        for (const offer of this.offers) {
          if (
            offer.loadId === loadId &&
            (offer.status === 'Ganando' || offer.status === 'Activa')
          ) {
            offer.status = 'Superada';
            await updateOfferFields(offer.id, { status: 'Superada' });
            await this.notify(
              offer.carrierId,
              'outbid',
              'Tu oferta fue superada',
              'Alguien ofreció una tarifa menor para el viaje.',
              loadId,
            );
          }
        }
        return 'Ganando';
      }
      return 'Activa';
    },

    async closeAuction(loadId: string) {
      const loadIdx = this.loads.findIndex((l) => l.id === loadId);
      if (loadIdx < 0) return;
      const load = this.loads[loadIdx];
      if (load.assignmentMode !== 'Subasta Inversa') return;
      const auth = useAuthStore();

      const validOffers = this.offers
        .filter(
          (o) =>
            o.loadId === loadId && (o.status === 'Activa' || o.status === 'Ganando'),
        )
        .filter((o) => {
          const u = this.users.find((x) => x.uuid === o.carrierId);
          return u?.status === 'approved';
        })
        .sort((a, b) => {
          if (a.amount !== b.amount) return a.amount - b.amount;
          return a.submittedAt.getTime() - b.submittedAt.getTime();
        });

      if (validOffers[0]) {
        const winner = validOffers[0];
        this.loads[loadIdx].status = 'Asignado';
        this.loads[loadIdx].assignedCarrierId = winner.carrierId;
        this.loads[loadIdx].assignedUnitId = winner.unitId;
        this.loads[loadIdx].assignedOperatorId = winner.operatorId;
        for (const offer of this.offers) {
          if (offer.loadId === loadId) {
            const newStatus: OfferStatus =
              offer.id === winner.id ? 'Ganadora' : 'Perdida';
            offer.status = newStatus;
            await updateOfferFields(offer.id, { status: newStatus });
          }
        }
        this.loads[loadIdx].statusHistory.push(
          makeStatusChange(
            'Asignado',
            auth.currentUser?.uuid ?? '',
            auth.currentUser?.name ?? 'Admin',
            `Subasta cerrada. Ganador: ${winner.carrierName}`,
          ),
        );
        await saveLoad(this.loads[loadIdx]);
        await this.notify(
          winner.carrierId,
          'load_assigned',
          '¡Ganaste la subasta!',
          `Tu oferta ganó el viaje ${load.reference}.`,
          loadId,
        );
      }
    },

    async submitLTLQuote(loadId: string, amount: number, notes = ''): Promise<boolean> {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user || user.status !== 'approved') return false;
      const load = this.loads.find((l) => l.id === loadId);
      if (
        !load ||
        load.assignmentMode !== 'Consolidada LTL' ||
        load.status !== 'Publicado' ||
        new Date() >= load.deadline
      ) {
        return false;
      }
      if (this.offers.some((o) => o.loadId === loadId && o.carrierId === user.uuid)) {
        return false;
      }
      const offer: Offer = {
        id: newUuid(),
        loadId,
        carrierId: user.uuid,
        carrierName: user.name,
        amount,
        currency: load.currency,
        isAvailabilityOnly: false,
        availableUnitCount: 1,
        status: 'Activa',
        submittedAt: new Date(),
        notes,
      };
      this.offers.push(offer);
      await saveOffer(offer);
      return true;
    },

    async confirmLTLOffer(offerId: string) {
      const offerIdx = this.offers.findIndex((o) => o.id === offerId);
      if (offerIdx < 0) return;
      const offer = this.offers[offerIdx];
      const loadIdx = this.loads.findIndex((l) => l.id === offer.loadId);
      if (loadIdx < 0) return;
      const auth = useAuthStore();

      this.offers[offerIdx].status = 'Ganadora';
      await updateOfferFields(offerId, { status: 'Ganadora' });

      for (const o of this.offers) {
        if (o.loadId === offer.loadId && o.id !== offerId && o.status === 'Activa') {
          o.status = 'Perdida';
          await updateOfferFields(o.id, { status: 'Perdida' });
        }
      }

      this.loads[loadIdx].status = 'Asignado';
      this.loads[loadIdx].assignedCarrierId = offer.carrierId;
      this.loads[loadIdx].assignedPriceSinIVA = offer.amount;
      this.loads[loadIdx].statusHistory.push(
        makeStatusChange(
          'Asignado',
          auth.currentUser?.uuid ?? '',
          auth.currentUser?.name ?? 'Admin',
          `Cotización LTL confirmada. Ganador: ${offer.carrierName}`,
        ),
      );
      await saveLoad(this.loads[loadIdx]);
      await this.notify(
        offer.carrierId,
        'load_assigned',
        '¡Cotización aceptada!',
        `Tu cotización para el viaje ${this.loads[loadIdx].reference} fue confirmada.`,
        offer.loadId,
      );
    },

    async rejectLTLOffer(offerId: string) {
      const offerIdx = this.offers.findIndex((o) => o.id === offerId);
      if (offerIdx < 0) return;
      this.offers[offerIdx].status = 'Rechazada';
      await updateOfferFields(offerId, { status: 'Rechazada' });
    },

    async indicateAvailability(
      loadId: string,
      unitId?: string,
      proposedPrice?: number,
    ) {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user || user.status !== 'approved') return;
      const load = this.loads.find((l) => l.id === loadId);
      if (!load || load.assignmentMode !== 'Confirmación Manual') return;

      const offer: Offer = {
        id: newUuid(),
        loadId,
        carrierId: user.uuid,
        carrierName: user.name,
        unitId,
        amount: proposedPrice ?? load.offeredPrice,
        currency: load.currency,
        isAvailabilityOnly: proposedPrice == null,
        proposedPrice,
        availableUnitCount: 1,
        status: 'Activa',
        submittedAt: new Date(),
        notes: '',
      };
      this.offers.push(offer);
      await saveOffer(offer);
    },

    async assignManually(
      loadId: string,
      carrierId: string,
      unitId?: string,
      operatorId?: string,
    ) {
      const loadIdx = this.loads.findIndex((l) => l.id === loadId);
      if (loadIdx < 0) return;
      const auth = useAuthStore();
      this.loads[loadIdx].status = 'Asignado';
      this.loads[loadIdx].assignedCarrierId = carrierId;
      this.loads[loadIdx].assignedUnitId = unitId;
      this.loads[loadIdx].assignedOperatorId = operatorId;
      this.loads[loadIdx].statusHistory.push(
        makeStatusChange(
          'Asignado',
          auth.currentUser?.uuid ?? '',
          auth.currentUser?.name ?? 'Admin',
          'Asignación manual',
        ),
      );
      for (const offer of this.offers) {
        if (offer.loadId === loadId) {
          const newStatus: OfferStatus =
            offer.carrierId === carrierId ? 'Ganadora' : 'Perdida';
          offer.status = newStatus;
          await updateOfferFields(offer.id, { status: newStatus });
        }
      }
      await saveLoad(this.loads[loadIdx]);
      await this.notify(
        carrierId,
        'load_assigned',
        '¡Viaje asignado!',
        `Se te asignó el viaje ${this.loads[loadIdx].reference}.`,
        loadId,
      );
    },

    async sendUrgencyAlert(
      loadId: string,
      priceIncrement: number,
      allowCounterOffer: boolean,
    ) {
      const idx = this.loads.findIndex((l) => l.id === loadId);
      if (idx < 0) return;
      if (priceIncrement > 0) this.loads[idx].offeredPrice += priceIncrement;
      if (allowCounterOffer && this.loads[idx].assignmentMode === 'Tarifa Fija') {
        this.loads[idx].assignmentMode = 'Subasta Inversa';
      }
      const fields: Record<string, unknown> = {
        urgentRepost: true,
        offeredPrice: this.loads[idx].offeredPrice,
      };
      if (allowCounterOffer) fields.assignmentMode = 'Confirmación Manual';
      await updateLoadFields(loadId, fields);
    },

    // ── Units ─────────────────────────────────────────────────────────

    async addUnit(unit: Unit) {
      this.units.push(unit);
      await saveUnit(unit);
    },

    async updateUnit(unit: Unit) {
      const idx = this.units.findIndex((u) => u.id === unit.id);
      if (idx < 0) return;
      this.units[idx] = unit;
      await saveUnit(unit);
    },

    async deleteUnit(unitId: string) {
      this.units = this.units.filter((u) => u.id !== unitId);
      await deleteUnitDoc(unitId);
    },

    async updateUnitStatus(unitId: string, status: UnitStatus) {
      const idx = this.units.findIndex((u) => u.id === unitId);
      if (idx < 0) return;
      this.units[idx].status = status;
      await updateUnitFields(unitId, { status });
    },

    postUnitAvailability(unitId: string, originState: string, destinationState: string) {
      const idx = this.units.findIndex((u) => u.id === unitId);
      if (idx < 0) return;
      this.units[idx].postedOriginState = originState;
      this.units[idx].postedDestinationState = destinationState;
      this.units[idx].isAvailabilityPosted = true;
    },

    removeUnitPost(unitId: string) {
      const idx = this.units.findIndex((u) => u.id === unitId);
      if (idx < 0) return;
      this.units[idx].isAvailabilityPosted = false;
      this.units[idx].postedOriginState = '';
      this.units[idx].postedDestinationState = '';
    },

    async postQuickAvailability(
      equipmentType: EquipmentType,
      count: number,
      originState: string,
      destinationState: string,
    ) {
      const auth = useAuthStore();
      const user = auth.currentUser;
      if (!user) return;
      const unit: Unit = {
        id: newUuid(),
        ownerId: user.companyId ?? user.uuid,
        equipmentType,
        plates: '',
        trailerNumber: String(count),
        currentLocation: originState,
        operatorName: '',
        scac: '',
        caat: '',
        availableFrom: new Date(),
        coverageZones: destinationState ? [destinationState] : [],
        status: 'Disponible',
        notes: 'availability_post',
        postedOriginState: originState,
        postedDestinationState: destinationState,
        isAvailabilityPosted: true,
      };
      await this.addUnit(unit);
    },

    // ── Profile ───────────────────────────────────────────────────────

    async updateCarrierRoutes(routes: AppUser['routes']) {
      const auth = useAuthStore();
      if (!auth.currentUser) return;
      const previous = { ...auth.currentUser };
      auth.currentUser = {
        ...auth.currentUser,
        routes,
        coverageStates: [],
        coverageZones: [],
      };
      try {
        await updateUserRoutes(routes);
      } catch (err) {
        auth.currentUser = previous;
        throw err;
      }
    },

    async setHandlesLTL(value: boolean) {
      const auth = useAuthStore();
      if (!auth.currentUser) return;
      auth.currentUser = { ...auth.currentUser, handlesLTL: value };
      await updateUserLTL(value);
    },

    async lookupOperator(phone: string): Promise<AppUser | null> {
      return fetchUserByPhone(phone);
    },
  },
});

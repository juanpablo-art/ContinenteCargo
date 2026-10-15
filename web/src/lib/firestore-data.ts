import {
  collection,
  doc,
  onSnapshot,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  getDocs,
  getDoc,
  Timestamp,
  type DocumentData,
  type Unsubscribe,
} from 'firebase/firestore';
import { auth, db } from '@/plugins/firebase';
import type {
  AppNotification,
  AppUser,
  AssignmentMode,
  CartaInstruccion,
  Currency,
  EquipmentType,
  Load,
  LoadStatus,
  NotificationChannels,
  NotificationType,
  Offer,
  OfferStatus,
  SpecialRequirement,
  StatusChange,
  TransportCompany,
  Unit,
  UnitStatus,
  UserRole,
  UserStatus,
} from '@/lib/models';
import { parseUser, userToData, companyToData } from '@/lib/firestore-user';

function ts(date: Date): Timestamp {
  return Timestamp.fromDate(date);
}

function asDate(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return new Date();
}

function asNumber(value: unknown): number {
  return typeof value === 'number' ? value : 0;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function statusChangeToData(sc: StatusChange): DocumentData {
  return {
    id: sc.id,
    status: sc.status,
    changedBy: sc.changedBy,
    changedByName: sc.changedByName,
    changedAt: ts(sc.changedAt),
    notes: sc.notes,
  };
}

function parseStatusChange(d: DocumentData): StatusChange | null {
  if (typeof d.status !== 'string' || typeof d.changedBy !== 'string') return null;
  return {
    id: asString(d.id) || crypto.randomUUID(),
    status: d.status as LoadStatus,
    changedBy: d.changedBy,
    changedByName: asString(d.changedByName),
    changedAt: asDate(d.changedAt),
    notes: asString(d.notes),
  };
}

function parseCarta(d: DocumentData | undefined): CartaInstruccion | undefined {
  if (!d || typeof d !== 'object') return undefined;
  return {
    folio: asString(d.folio),
    instruccionesRecoleccion: asString(d.instruccionesRecoleccion),
    instruccionesEntrega: asString(d.instruccionesEntrega),
    contactoCarga: asString(d.contactoCarga),
    contactoDescarga: asString(d.contactoDescarga),
    observaciones: asString(d.observaciones),
    archivoNombre: asString(d.archivoNombre),
    creadaAt: asDate(d.creadaAt),
  };
}

export function loadToData(load: Load): DocumentData {
  const data: DocumentData = {
    id: load.id,
    reference: load.reference,
    originCity: load.originCity,
    originState: load.originState,
    destinationCity: load.destinationCity,
    destinationState: load.destinationState,
    pickupDate: ts(load.pickupDate),
    deliveryDate: ts(load.deliveryDate),
    equipmentType: load.equipmentType,
    unitCount: load.unitCount,
    confirmedUnitCount: load.confirmedUnitCount,
    weightKg: load.weightKg,
    merchandiseDescription: load.merchandiseDescription,
    measurementsDescription: load.measurementsDescription,
    specialRequirements: load.specialRequirements,
    offeredPrice: load.offeredPrice,
    currency: load.currency,
    includesVAT: load.includesVAT,
    includedConcepts: load.includedConcepts,
    allowedExtraExpenses: load.allowedExtraExpenses,
    assignmentMode: load.assignmentMode,
    deadline: ts(load.deadline),
    minBidDecrement: load.minBidDecrement,
    observations: load.observations,
    status: load.status,
    publishedBy: load.publishedBy,
    publishedAt: ts(load.publishedAt),
    trackingUrl: load.trackingUrl,
    statusHistory: load.statusHistory.map(statusChangeToData),
    clientContactName: load.clientContactName,
    clientContactPhone: load.clientContactPhone,
    exactPickupAddress: load.exactPickupAddress,
    exactDeliveryAddress: load.exactDeliveryAddress,
    notificationChannels: {
      inApp: load.notificationChannels.inApp,
      email: load.notificationChannels.email,
      whatsapp: load.notificationChannels.whatsapp,
      aiCall: load.notificationChannels.aiCall,
    },
  };
  if (load.assignedCarrierId) data.assignedCarrierId = load.assignedCarrierId;
  if (load.assignedUnitId) data.assignedUnitId = load.assignedUnitId;
  if (load.assignedOperatorId) data.assignedOperatorId = load.assignedOperatorId;
  if (load.unitETA) data.unitETA = ts(load.unitETA);
  if (load.maxAuthorizedPriceSinIVA != null) {
    data.maxAuthorizedPriceSinIVA = load.maxAuthorizedPriceSinIVA;
  }
  if (load.assignedPriceSinIVA != null) {
    data.assignedPriceSinIVA = load.assignedPriceSinIVA;
  }
  if (load.confirmedCarrierIds.length) {
    data.confirmedCarrierIds = load.confirmedCarrierIds;
  }
  if (load.cartaInstruccion) {
    data.cartaInstruccion = {
      ...load.cartaInstruccion,
      creadaAt: ts(load.cartaInstruccion.creadaAt),
    };
  }
  return data;
}

export function parseLoad(data: DocumentData): Load | null {
  if (
    typeof data.id !== 'string' ||
    typeof data.reference !== 'string' ||
    typeof data.originCity !== 'string' ||
    typeof data.originState !== 'string' ||
    typeof data.destinationCity !== 'string' ||
    typeof data.destinationState !== 'string' ||
    typeof data.equipmentType !== 'string' ||
    typeof data.assignmentMode !== 'string' ||
    typeof data.status !== 'string' ||
    typeof data.publishedBy !== 'string'
  ) {
    return null;
  }

  const nc = (data.notificationChannels as DocumentData | undefined) ?? {};
  const channels: NotificationChannels = {
    inApp: Boolean(nc.inApp ?? true),
    email: Boolean(nc.email ?? true),
    whatsapp: Boolean(nc.whatsapp ?? true),
    aiCall: Boolean(nc.aiCall ?? false),
  };

  return {
    id: data.id,
    reference: data.reference,
    originCity: data.originCity,
    originState: data.originState,
    destinationCity: data.destinationCity,
    destinationState: data.destinationState,
    pickupDate: asDate(data.pickupDate),
    deliveryDate: asDate(data.deliveryDate),
    equipmentType: data.equipmentType as EquipmentType,
    unitCount: typeof data.unitCount === 'number' ? data.unitCount : 1,
    weightKg: asNumber(data.weightKg),
    merchandiseDescription: asString(data.merchandiseDescription),
    measurementsDescription: asString(data.measurementsDescription),
    specialRequirements: Array.isArray(data.specialRequirements)
      ? (data.specialRequirements as SpecialRequirement[])
      : [],
    offeredPrice: asNumber(data.offeredPrice),
    currency: (asString(data.currency) as Currency) || 'MXN',
    includesVAT: Boolean(data.includesVAT),
    maxAuthorizedPriceSinIVA:
      typeof data.maxAuthorizedPriceSinIVA === 'number'
        ? data.maxAuthorizedPriceSinIVA
        : undefined,
    assignedPriceSinIVA:
      typeof data.assignedPriceSinIVA === 'number' ? data.assignedPriceSinIVA : undefined,
    includedConcepts: asString(data.includedConcepts),
    allowedExtraExpenses: asString(data.allowedExtraExpenses),
    assignmentMode: data.assignmentMode as AssignmentMode,
    deadline: asDate(data.deadline),
    minBidDecrement: asNumber(data.minBidDecrement) || 100,
    observations: asString(data.observations),
    status: data.status as LoadStatus,
    publishedBy: data.publishedBy,
    publishedAt: asDate(data.publishedAt),
    assignedCarrierId:
      typeof data.assignedCarrierId === 'string' ? data.assignedCarrierId : undefined,
    assignedUnitId: typeof data.assignedUnitId === 'string' ? data.assignedUnitId : undefined,
    assignedOperatorId:
      typeof data.assignedOperatorId === 'string' ? data.assignedOperatorId : undefined,
    unitETA: data.unitETA ? asDate(data.unitETA) : undefined,
    trackingUrl: asString(data.trackingUrl),
    statusHistory: Array.isArray(data.statusHistory)
      ? (data.statusHistory as DocumentData[])
          .map(parseStatusChange)
          .filter((s): s is StatusChange => s != null)
      : [],
    clientContactName: asString(data.clientContactName),
    clientContactPhone: asString(data.clientContactPhone),
    exactPickupAddress: asString(data.exactPickupAddress),
    exactDeliveryAddress: asString(data.exactDeliveryAddress),
    notificationChannels: channels,
    confirmedCarrierIds: Array.isArray(data.confirmedCarrierIds)
      ? (data.confirmedCarrierIds as string[])
      : [],
    confirmedUnitCount:
      typeof data.confirmedUnitCount === 'number' ? data.confirmedUnitCount : 0,
    cartaInstruccion: parseCarta(data.cartaInstruccion as DocumentData | undefined),
  };
}

export function unitToData(unit: Unit): DocumentData {
  const data: DocumentData = {
    id: unit.id,
    ownerId: unit.ownerId,
    equipmentType: unit.equipmentType,
    plates: unit.plates,
    trailerNumber: unit.trailerNumber,
    currentLocation: unit.currentLocation,
    operatorName: unit.operatorName,
    scac: unit.scac,
    caat: unit.caat,
    availableFrom: ts(unit.availableFrom),
    coverageZones: unit.coverageZones,
    status: unit.status,
    notes: unit.notes,
  };
  if (unit.operatorId) data.operatorId = unit.operatorId;
  return data;
}

export function parseUnit(data: DocumentData): Unit | null {
  if (
    typeof data.id !== 'string' ||
    typeof data.ownerId !== 'string' ||
    typeof data.equipmentType !== 'string'
  ) {
    return null;
  }
  return {
    id: data.id,
    ownerId: data.ownerId,
    equipmentType: data.equipmentType as EquipmentType,
    plates: asString(data.plates),
    trailerNumber: asString(data.trailerNumber),
    currentLocation: asString(data.currentLocation),
    operatorName: asString(data.operatorName),
    scac: asString(data.scac),
    caat: asString(data.caat),
    availableFrom: asDate(data.availableFrom),
    coverageZones: Array.isArray(data.coverageZones) ? (data.coverageZones as string[]) : [],
    status: (asString(data.status) as UnitStatus) || 'Disponible',
    operatorId: typeof data.operatorId === 'string' ? data.operatorId : undefined,
    notes: asString(data.notes),
    postedOriginState: asString(data.postedOriginState),
    postedDestinationState: asString(data.postedDestinationState),
    isAvailabilityPosted: Boolean(data.isAvailabilityPosted),
  };
}

export function offerToData(offer: Offer): DocumentData {
  const data: DocumentData = {
    id: offer.id,
    loadId: offer.loadId,
    carrierId: offer.carrierId,
    carrierName: offer.carrierName,
    amount: offer.amount,
    currency: offer.currency,
    isAvailabilityOnly: offer.isAvailabilityOnly,
    availableUnitCount: offer.availableUnitCount,
    status: offer.status,
    submittedAt: ts(offer.submittedAt),
    notes: offer.notes,
  };
  if (offer.unitId) data.unitId = offer.unitId;
  if (offer.operatorId) data.operatorId = offer.operatorId;
  if (offer.proposedPrice != null) data.proposedPrice = offer.proposedPrice;
  return data;
}

export function parseOffer(data: DocumentData): Offer | null {
  if (
    typeof data.id !== 'string' ||
    typeof data.loadId !== 'string' ||
    typeof data.carrierId !== 'string' ||
    typeof data.carrierName !== 'string' ||
    typeof data.status !== 'string'
  ) {
    return null;
  }
  return {
    id: data.id,
    loadId: data.loadId,
    carrierId: data.carrierId,
    carrierName: data.carrierName,
    unitId: typeof data.unitId === 'string' ? data.unitId : undefined,
    operatorId: typeof data.operatorId === 'string' ? data.operatorId : undefined,
    amount: asNumber(data.amount),
    currency: (asString(data.currency) as Currency) || 'MXN',
    isAvailabilityOnly: Boolean(data.isAvailabilityOnly),
    proposedPrice: typeof data.proposedPrice === 'number' ? data.proposedPrice : undefined,
    availableUnitCount:
      typeof data.availableUnitCount === 'number' ? data.availableUnitCount : 1,
    status: data.status as OfferStatus,
    submittedAt: asDate(data.submittedAt),
    notes: asString(data.notes),
  };
}

export function notificationToData(n: AppNotification): DocumentData {
  const data: DocumentData = {
    id: n.id,
    userId: n.userId,
    type: n.type,
    title: n.title,
    body: n.body,
    isRead: n.isRead,
    createdAt: ts(n.createdAt),
  };
  if (n.loadId) data.loadId = n.loadId;
  return data;
}

export function parseNotification(data: DocumentData): AppNotification | null {
  if (
    typeof data.id !== 'string' ||
    typeof data.userId !== 'string' ||
    typeof data.type !== 'string' ||
    typeof data.title !== 'string' ||
    typeof data.body !== 'string'
  ) {
    return null;
  }
  return {
    id: data.id,
    userId: data.userId,
    type: data.type as NotificationType,
    title: data.title,
    body: data.body,
    loadId: typeof data.loadId === 'string' ? data.loadId : undefined,
    isRead: Boolean(data.isRead),
    createdAt: asDate(data.createdAt),
  };
}

export function parseCompany(data: DocumentData): TransportCompany | null {
  if (
    typeof data.name !== 'string' ||
    typeof data.contactName !== 'string' ||
    typeof data.phone !== 'string' ||
    typeof data.email !== 'string'
  ) {
    return null;
  }
  return {
    id: typeof data.id === 'string' ? data.id : crypto.randomUUID(),
    name: data.name,
    contactName: data.contactName,
    phone: data.phone,
    email: data.email,
    rfc: asString(data.rfc),
    status: (asString(data.status) as UserStatus) || 'pending_approval',
    createdAt: asDate(data.createdAt),
  };
}

// ── Writes ──────────────────────────────────────────────────────────────

export async function saveLoad(load: Load): Promise<void> {
  await setDoc(doc(db, 'loads', load.id), loadToData(load));
}

/** Carrier confirmation — updateData only so backend fields are preserved. */
export async function updateLoadForCarrierConfirmation(load: Load): Promise<void> {
  const fields: DocumentData = {
    confirmedCarrierIds: load.confirmedCarrierIds,
    confirmedUnitCount: load.confirmedUnitCount,
    statusHistory: load.statusHistory.map(statusChangeToData),
    trackingUrl: load.trackingUrl,
  };
  if (load.assignedUnitId) fields.assignedUnitId = load.assignedUnitId;
  if (load.assignedOperatorId) fields.assignedOperatorId = load.assignedOperatorId;
  if (load.unitETA) fields.unitETA = ts(load.unitETA);
  if (load.status === 'Asignado') {
    fields.status = load.status;
    if (load.assignedCarrierId) fields.assignedCarrierId = load.assignedCarrierId;
  }
  await updateDoc(doc(db, 'loads', load.id), fields);
}

export async function updateLoadFields(
  loadId: string,
  fields: DocumentData,
): Promise<void> {
  await updateDoc(doc(db, 'loads', loadId), fields);
}

/** Carrier/admin status bump — updateData only. */
export async function updateLoadStatusFields(
  loadId: string,
  status: LoadStatus,
  statusHistory: StatusChange[],
): Promise<void> {
  await updateDoc(doc(db, 'loads', loadId), {
    status,
    statusHistory: statusHistory.map(statusChangeToData),
  });
}

export async function saveUnit(unit: Unit): Promise<void> {
  await setDoc(doc(db, 'units', unit.id), unitToData(unit));
}

export async function updateUnitFields(
  unitId: string,
  fields: DocumentData,
): Promise<void> {
  await updateDoc(doc(db, 'units', unitId), fields);
}

export async function deleteUnitDoc(unitId: string): Promise<void> {
  await deleteDoc(doc(db, 'units', unitId));
}

export async function saveOffer(offer: Offer): Promise<void> {
  await setDoc(doc(db, 'offers', offer.id), offerToData(offer));
}

export async function updateOfferFields(
  offerId: string,
  fields: DocumentData,
): Promise<void> {
  await updateDoc(doc(db, 'offers', offerId), fields);
}

export async function saveNotification(n: AppNotification): Promise<void> {
  await setDoc(doc(db, 'notifications', n.id), notificationToData(n));
}

export async function updateNotificationFields(
  id: string,
  fields: DocumentData,
): Promise<void> {
  await updateDoc(doc(db, 'notifications', id), fields);
}

export async function updateUserStatus(userUuid: string, status: UserStatus): Promise<void> {
  const snap = await getDocs(query(collection(db, 'users'), where('uuid', '==', userUuid)));
  const first = snap.docs[0];
  if (!first) return;
  await updateDoc(first.ref, { status });
  const digits = first.data().phoneDigits as string | undefined;
  if (digits) {
    await updateDoc(doc(db, 'users_by_phone', digits), { status });
  }
}

export async function updateUserRoutes(
  routes: AppUser['routes'],
): Promise<void> {
  const uid = auth.currentUser?.uid;
  if (!uid) throw new Error('Usuario no autenticado');
  await updateDoc(doc(db, 'users', uid), {
    routes: routes.map((r) => ({
      id: r.id,
      originState: r.originState,
      destinationState: r.destinationState,
      bidirectional: r.bidirectional,
      equipmentTypes: r.equipmentTypes,
    })),
    coverageStates: [],
    coverageZones: [],
  });
}

export async function updateUserLTL(handlesLTL: boolean): Promise<void> {
  const uid = auth.currentUser?.uid;
  if (!uid) return;
  await updateDoc(doc(db, 'users', uid), { handlesLTL });
}

export async function fetchUserByPhone(phone: string): Promise<AppUser | null> {
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 10 || digits.length > 15) return null;
  const snap = await getDoc(doc(db, 'users_by_phone', digits));
  if (!snap.exists()) return null;
  const data = snap.data();
  if (
    typeof data.name !== 'string' ||
    typeof data.role !== 'string' ||
    typeof data.status !== 'string' ||
    data.status !== 'approved' ||
    data.role === 'admin' ||
    typeof data.uuid !== 'string'
  ) {
    return null;
  }
  return {
    uuid: data.uuid,
    name: data.name,
    email: '',
    phone,
    role: data.role as UserRole,
    status: data.status as UserStatus,
    canNegotiateRates: true,
    handlesLTL: false,
    routes: [],
    coverageStates: [],
    coverageZones: [],
    coverageEquipmentTypes: [],
  };
}

// ── Listeners ───────────────────────────────────────────────────────────

export function listenToLoads(onChange: (loads: Load[]) => void): Unsubscribe {
  return onSnapshot(collection(db, 'loads'), (snap) => {
    onChange(
      snap.docs
        .map((d) => parseLoad(d.data()))
        .filter((l): l is Load => l != null),
    );
  });
}

export function listenToUnits(onChange: (units: Unit[]) => void): Unsubscribe {
  return onSnapshot(collection(db, 'units'), (snap) => {
    onChange(
      snap.docs
        .map((d) => parseUnit(d.data()))
        .filter((u): u is Unit => u != null),
    );
  });
}

export function listenToOffers(onChange: (offers: Offer[]) => void): Unsubscribe {
  return onSnapshot(collection(db, 'offers'), (snap) => {
    onChange(
      snap.docs
        .map((d) => parseOffer(d.data()))
        .filter((o): o is Offer => o != null),
    );
  });
}

export function listenToNotifications(
  userId: string,
  onChange: (items: AppNotification[]) => void,
): Unsubscribe {
  return onSnapshot(
    query(collection(db, 'notifications'), where('userId', '==', userId)),
    (snap) => {
      onChange(
        snap.docs
          .map((d) => parseNotification(d.data()))
          .filter((n): n is AppNotification => n != null),
      );
    },
  );
}

export function listenToUsers(onChange: (users: AppUser[]) => void): Unsubscribe {
  return onSnapshot(collection(db, 'users'), (snap) => {
    onChange(
      snap.docs
        .map((d) => parseUser(d.data()))
        .filter((u): u is AppUser => u != null),
    );
  });
}

export function listenToOwnUser(onChange: (user: AppUser | null) => void): Unsubscribe {
  const uid = auth.currentUser?.uid ?? '';
  return onSnapshot(doc(db, 'users', uid), (snap) => {
    onChange(snap.exists() ? parseUser(snap.data()) : null);
  });
}

export function listenToCompanies(
  onChange: (companies: TransportCompany[]) => void,
): Unsubscribe {
  return onSnapshot(collection(db, 'companies'), (snap) => {
    onChange(
      snap.docs
        .map((d) => parseCompany(d.data()))
        .filter((c): c is TransportCompany => c != null),
    );
  });
}

export { userToData, companyToData };

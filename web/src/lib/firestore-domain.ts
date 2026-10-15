import {
  Timestamp,
  type DocumentData,
} from 'firebase/firestore';
import type { EquipmentType } from '@/lib/models';
import type {
  AppNotification,
  CartaInstruccion,
  Currency,
  Invitation,
  Load,
  LoadStatus,
  NotificationChannels,
  Offer,
  OfferStatus,
  SpecialRequirement,
  StatusChange,
  Unit,
  UnitStatus,
  AssignmentMode,
} from '@/lib/domain';

function asDate(v: unknown): Date {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string' || typeof v === 'number') return new Date(v);
  return new Date();
}

function asNumber(v: unknown, fallback = 0): number {
  return typeof v === 'number' && !Number.isNaN(v) ? v : fallback;
}

function statusChangeToData(sc: StatusChange): DocumentData {
  return {
    id: sc.id,
    status: sc.status,
    changedBy: sc.changedBy,
    changedByName: sc.changedByName,
    changedAt: Timestamp.fromDate(sc.changedAt),
    notes: sc.notes,
  };
}

function parseStatusChange(d: DocumentData): StatusChange | null {
  if (typeof d.status !== 'string' || typeof d.changedBy !== 'string') return null;
  return {
    id: typeof d.id === 'string' ? d.id : crypto.randomUUID(),
    status: d.status as LoadStatus,
    changedBy: d.changedBy,
    changedByName: typeof d.changedByName === 'string' ? d.changedByName : '',
    changedAt: asDate(d.changedAt),
    notes: typeof d.notes === 'string' ? d.notes : '',
  };
}

function parseCarta(d: DocumentData): CartaInstruccion {
  return {
    folio: String(d.folio ?? ''),
    instruccionesRecoleccion: String(d.instruccionesRecoleccion ?? ''),
    instruccionesEntrega: String(d.instruccionesEntrega ?? ''),
    contactoCarga: String(d.contactoCarga ?? ''),
    contactoDescarga: String(d.contactoDescarga ?? ''),
    observaciones: String(d.observaciones ?? ''),
    archivoNombre: String(d.archivoNombre ?? ''),
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
    pickupDate: Timestamp.fromDate(load.pickupDate),
    deliveryDate: Timestamp.fromDate(load.deliveryDate),
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
    deadline: Timestamp.fromDate(load.deadline),
    minBidDecrement: load.minBidDecrement,
    observations: load.observations,
    status: load.status,
    publishedBy: load.publishedBy,
    publishedAt: Timestamp.fromDate(load.publishedAt),
    trackingUrl: load.trackingUrl,
    statusHistory: load.statusHistory.map(statusChangeToData),
    clientContactName: load.clientContactName,
    clientContactPhone: load.clientContactPhone,
    exactPickupAddress: load.exactPickupAddress,
    exactDeliveryAddress: load.exactDeliveryAddress,
    notificationChannels: { ...load.notificationChannels },
    confirmedCarrierIds: load.confirmedCarrierIds,
  };
  if (load.assignedCarrierId) data.assignedCarrierId = load.assignedCarrierId;
  if (load.assignedUnitId) data.assignedUnitId = load.assignedUnitId;
  if (load.assignedOperatorId) data.assignedOperatorId = load.assignedOperatorId;
  if (load.unitETA) data.unitETA = Timestamp.fromDate(load.unitETA);
  if (load.maxAuthorizedPriceSinIVA != null) {
    data.maxAuthorizedPriceSinIVA = load.maxAuthorizedPriceSinIVA;
  }
  if (load.assignedPriceSinIVA != null) {
    data.assignedPriceSinIVA = load.assignedPriceSinIVA;
  }
  if (load.cartaInstruccion) {
    data.cartaInstruccion = {
      ...load.cartaInstruccion,
      creadaAt: Timestamp.fromDate(load.cartaInstruccion.creadaAt),
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
  const nc = (data.notificationChannels as DocumentData) || {};
  const channels: NotificationChannels = {
    inApp: Boolean(nc.inApp ?? true),
    email: Boolean(nc.email ?? true),
    whatsapp: Boolean(nc.whatsapp ?? true),
    aiCall: Boolean(nc.aiCall ?? false),
  };
  const load: Load = {
    id: data.id,
    reference: data.reference,
    originCity: data.originCity,
    originState: data.originState,
    destinationCity: data.destinationCity,
    destinationState: data.destinationState,
    pickupDate: asDate(data.pickupDate),
    deliveryDate: asDate(data.deliveryDate),
    equipmentType: data.equipmentType as EquipmentType,
    unitCount: asNumber(data.unitCount, 1),
    weightKg: asNumber(data.weightKg),
    merchandiseDescription: String(data.merchandiseDescription ?? ''),
    measurementsDescription: String(data.measurementsDescription ?? ''),
    specialRequirements: Array.isArray(data.specialRequirements)
      ? (data.specialRequirements as SpecialRequirement[])
      : [],
    offeredPrice: asNumber(data.offeredPrice),
    currency: (data.currency as Currency) || 'MXN',
    includesVAT: Boolean(data.includesVAT),
    includedConcepts: String(data.includedConcepts ?? ''),
    allowedExtraExpenses: String(data.allowedExtraExpenses ?? ''),
    assignmentMode: data.assignmentMode as AssignmentMode,
    deadline: asDate(data.deadline),
    minBidDecrement: asNumber(data.minBidDecrement, 100),
    observations: String(data.observations ?? ''),
    status: data.status as LoadStatus,
    publishedBy: data.publishedBy,
    publishedAt: asDate(data.publishedAt),
    trackingUrl: String(data.trackingUrl ?? ''),
    statusHistory: Array.isArray(data.statusHistory)
      ? data.statusHistory
          .map((x) => parseStatusChange(x as DocumentData))
          .filter((x): x is StatusChange => x != null)
      : [],
    clientContactName: String(data.clientContactName ?? ''),
    clientContactPhone: String(data.clientContactPhone ?? ''),
    exactPickupAddress: String(data.exactPickupAddress ?? ''),
    exactDeliveryAddress: String(data.exactDeliveryAddress ?? ''),
    notificationChannels: channels,
    confirmedCarrierIds: Array.isArray(data.confirmedCarrierIds)
      ? (data.confirmedCarrierIds as string[])
      : [],
    confirmedUnitCount: asNumber(data.confirmedUnitCount),
  };
  if (typeof data.assignedCarrierId === 'string') {
    load.assignedCarrierId = data.assignedCarrierId;
  }
  if (typeof data.assignedUnitId === 'string') load.assignedUnitId = data.assignedUnitId;
  if (typeof data.assignedOperatorId === 'string') {
    load.assignedOperatorId = data.assignedOperatorId;
  }
  if (data.unitETA) load.unitETA = asDate(data.unitETA);
  if (typeof data.maxAuthorizedPriceSinIVA === 'number') {
    load.maxAuthorizedPriceSinIVA = data.maxAuthorizedPriceSinIVA;
  }
  if (typeof data.assignedPriceSinIVA === 'number') {
    load.assignedPriceSinIVA = data.assignedPriceSinIVA;
  }
  if (data.cartaInstruccion && typeof data.cartaInstruccion === 'object') {
    load.cartaInstruccion = parseCarta(data.cartaInstruccion as DocumentData);
  }
  return load;
}

export function carrierConfirmationFields(load: Load): DocumentData {
  const fields: DocumentData = {
    confirmedCarrierIds: load.confirmedCarrierIds,
    confirmedUnitCount: load.confirmedUnitCount,
    statusHistory: load.statusHistory.map(statusChangeToData),
    trackingUrl: load.trackingUrl,
  };
  if (load.assignedUnitId) fields.assignedUnitId = load.assignedUnitId;
  if (load.assignedOperatorId) fields.assignedOperatorId = load.assignedOperatorId;
  if (load.unitETA) fields.unitETA = Timestamp.fromDate(load.unitETA);
  if (load.status === 'Asignado') {
    fields.status = load.status;
    if (load.assignedCarrierId) fields.assignedCarrierId = load.assignedCarrierId;
  }
  return fields;
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
    submittedAt: Timestamp.fromDate(offer.submittedAt),
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
    typeof data.status !== 'string'
  ) {
    return null;
  }
  return {
    id: data.id,
    loadId: data.loadId,
    carrierId: data.carrierId,
    carrierName: String(data.carrierName ?? ''),
    unitId: typeof data.unitId === 'string' ? data.unitId : undefined,
    operatorId: typeof data.operatorId === 'string' ? data.operatorId : undefined,
    amount: asNumber(data.amount),
    currency: (data.currency as Currency) || 'MXN',
    isAvailabilityOnly: Boolean(data.isAvailabilityOnly),
    proposedPrice:
      typeof data.proposedPrice === 'number' ? data.proposedPrice : undefined,
    availableUnitCount: asNumber(data.availableUnitCount, 1),
    status: data.status as OfferStatus,
    submittedAt: asDate(data.submittedAt),
    notes: String(data.notes ?? ''),
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
    availableFrom: Timestamp.fromDate(unit.availableFrom),
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
    plates: String(data.plates ?? ''),
    trailerNumber: String(data.trailerNumber ?? ''),
    currentLocation: String(data.currentLocation ?? ''),
    operatorName: String(data.operatorName ?? ''),
    scac: String(data.scac ?? ''),
    caat: String(data.caat ?? ''),
    availableFrom: asDate(data.availableFrom),
    coverageZones: Array.isArray(data.coverageZones)
      ? (data.coverageZones as string[])
      : [],
    status: (data.status as UnitStatus) || 'Disponible',
    operatorId: typeof data.operatorId === 'string' ? data.operatorId : undefined,
    notes: String(data.notes ?? ''),
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
    createdAt: Timestamp.fromDate(n.createdAt),
  };
  if (n.loadId) data.loadId = n.loadId;
  return data;
}

export function parseNotification(data: DocumentData): AppNotification | null {
  if (
    typeof data.id !== 'string' ||
    typeof data.userId !== 'string' ||
    typeof data.title !== 'string'
  ) {
    return null;
  }
  return {
    id: data.id,
    userId: data.userId,
    type: (data.type as AppNotification['type']) || 'new_load',
    title: data.title,
    body: String(data.body ?? ''),
    loadId: typeof data.loadId === 'string' ? data.loadId : undefined,
    isRead: Boolean(data.isRead),
    createdAt: asDate(data.createdAt),
  };
}

export function parseInvitation(id: string, data: DocumentData): Invitation {
  return {
    id,
    name: String(data.name ?? ''),
    phone: typeof data.phone === 'string' ? data.phone : undefined,
    email: typeof data.email === 'string' ? data.email : undefined,
    status: String(data.status ?? 'sent'),
    createdAt: asDate(data.createdAt),
  };
}

export function makeStatusChange(
  status: LoadStatus,
  changedBy: string,
  changedByName: string,
  notes = '',
): StatusChange {
  return {
    id: crypto.randomUUID(),
    status,
    changedBy,
    changedByName,
    changedAt: new Date(),
    notes,
  };
}

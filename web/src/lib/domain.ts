import type { AppUser, CarrierRoute, EquipmentType } from '@/lib/models';
import { MEXICAN_ZONES } from '@/lib/models';

export type AssignmentMode =
  | 'Tarifa Fija'
  | 'Subasta Inversa'
  | 'Confirmación Manual'
  | 'Consolidada LTL';

export const ASSIGNMENT_MODES: AssignmentMode[] = [
  'Tarifa Fija',
  'Subasta Inversa',
  'Confirmación Manual',
  'Consolidada LTL',
];

export type LoadStatus =
  | 'Publicado'
  | 'Asignado'
  | 'En camino a recolección'
  | 'En origen'
  | 'Cargado'
  | 'En tránsito'
  | 'Entregado'
  | 'Cancelado';

export const LOAD_STATUSES: LoadStatus[] = [
  'Publicado',
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
  'Cancelado',
];

export const TRIP_ADVANCE: LoadStatus[] = [
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
];

export type OfferStatus =
  | 'Activa'
  | 'Ganando'
  | 'Superada'
  | 'Ganadora'
  | 'Perdida'
  | 'Cancelada'
  | 'Rechazada'
  | 'PendienteAprobacion';

export type UnitStatus =
  | 'Disponible'
  | 'Reservada'
  | 'En viaje'
  | 'Fuera de servicio';

export type Currency = 'MXN' | 'USD';

export type NotificationType =
  | 'new_load'
  | 'outbid'
  | 'auction_closing_soon'
  | 'load_assigned'
  | 'load_cancelled'
  | 'status_changed'
  | 'registration_approved'
  | 'registration_rejected';

export type SpecialRequirement =
  | 'Refrigeración'
  | 'Material Peligroso'
  | 'Acceso a Puerto'
  | 'Carga Sobredimensionada'
  | 'Plataforma Hidráulica'
  | 'Operadores en Equipo';

export const SPECIAL_REQUIREMENTS: SpecialRequirement[] = [
  'Refrigeración',
  'Material Peligroso',
  'Acceso a Puerto',
  'Carga Sobredimensionada',
  'Plataforma Hidráulica',
  'Operadores en Equipo',
];

export interface NotificationChannels {
  inApp: boolean;
  email: boolean;
  whatsapp: boolean;
  aiCall: boolean;
}

export interface StatusChange {
  id: string;
  status: LoadStatus;
  changedBy: string;
  changedByName: string;
  changedAt: Date;
  notes: string;
}

export interface CartaInstruccion {
  folio: string;
  instruccionesRecoleccion: string;
  instruccionesEntrega: string;
  contactoCarga: string;
  contactoDescarga: string;
  observaciones: string;
  archivoNombre: string;
  creadaAt: Date;
}

export interface Load {
  id: string;
  reference: string;
  originCity: string;
  originState: string;
  destinationCity: string;
  destinationState: string;
  pickupDate: Date;
  deliveryDate: Date;
  equipmentType: EquipmentType;
  unitCount: number;
  weightKg: number;
  merchandiseDescription: string;
  measurementsDescription: string;
  specialRequirements: SpecialRequirement[];
  offeredPrice: number;
  currency: Currency;
  includesVAT: boolean;
  maxAuthorizedPriceSinIVA?: number;
  assignedPriceSinIVA?: number;
  includedConcepts: string;
  allowedExtraExpenses: string;
  assignmentMode: AssignmentMode;
  deadline: Date;
  minBidDecrement: number;
  observations: string;
  status: LoadStatus;
  publishedBy: string;
  publishedAt: Date;
  assignedCarrierId?: string;
  assignedUnitId?: string;
  assignedOperatorId?: string;
  unitETA?: Date;
  trackingUrl: string;
  statusHistory: StatusChange[];
  clientContactName: string;
  clientContactPhone: string;
  exactPickupAddress: string;
  exactDeliveryAddress: string;
  notificationChannels: NotificationChannels;
  confirmedCarrierIds: string[];
  confirmedUnitCount: number;
  cartaInstruccion?: CartaInstruccion;
}

export interface Offer {
  id: string;
  loadId: string;
  carrierId: string;
  carrierName: string;
  unitId?: string;
  operatorId?: string;
  amount: number;
  currency: Currency;
  isAvailabilityOnly: boolean;
  proposedPrice?: number;
  availableUnitCount: number;
  status: OfferStatus;
  submittedAt: Date;
  notes: string;
}

export interface Unit {
  id: string;
  ownerId: string;
  equipmentType: EquipmentType;
  plates: string;
  trailerNumber: string;
  currentLocation: string;
  operatorName: string;
  scac: string;
  caat: string;
  availableFrom: Date;
  coverageZones: string[];
  status: UnitStatus;
  operatorId?: string;
  notes: string;
  postedOriginState?: string;
  postedDestinationState?: string;
  isAvailabilityPosted?: boolean;
}

export interface AppNotification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  loadId?: string;
  isRead: boolean;
  createdAt: Date;
}

export interface Invitation {
  id: string;
  name: string;
  phone?: string;
  email?: string;
  status: string;
  createdAt: Date;
}

export function originDisplay(load: Load) {
  return `${load.originCity}, ${load.originState}`;
}

export function destinationDisplay(load: Load) {
  return `${load.destinationCity}, ${load.destinationState}`;
}

export function isFull(load: Load) {
  return load.unitCount > 0 && load.confirmedUnitCount >= load.unitCount;
}

export function isOpen(load: Load) {
  return load.status === 'Publicado' && Date.now() < load.deadline.getTime() && !isFull(load);
}

export function isPartial(load: Load) {
  return load.confirmedUnitCount > 0 && load.confirmedUnitCount < load.unitCount;
}

export function progressStep(status: LoadStatus): number {
  const map: Record<LoadStatus, number> = {
    Publicado: 0,
    Asignado: 1,
    'En camino a recolección': 2,
    'En origen': 3,
    Cargado: 4,
    'En tránsito': 5,
    Entregado: 6,
    Cancelado: -1,
  };
  return map[status];
}

export function nextTripStatus(status: LoadStatus): LoadStatus | null {
  const i = TRIP_ADVANCE.indexOf(status);
  if (i < 0 || i >= TRIP_ADVANCE.length - 1) return null;
  return TRIP_ADVANCE[i + 1];
}

export function canSeeSensitiveLoadFields(
  load: Load,
  role: AppUser['role'] | undefined,
): boolean {
  if (role === 'admin') return true;
  return load.status !== 'Publicado';
}

export function routeMatches(
  route: CarrierRoute,
  originState: string,
  destinationState: string,
  equipmentType: EquipmentType,
): boolean {
  let stateMatch = false;
  if (route.originState === originState && route.destinationState === destinationState) {
    stateMatch = true;
  } else if (
    route.bidirectional &&
    route.originState === destinationState &&
    route.destinationState === originState
  ) {
    stateMatch = true;
  }
  if (!stateMatch) return false;
  return (
    route.equipmentTypes.length === 0 || route.equipmentTypes.includes(equipmentType)
  );
}

const USA_STATE = /^[A-Z]{2}$/;

export function coversLoad(
  user: AppUser & {
    coversUSA?: boolean;
    coverageUSAStates?: string[];
    handlesLocal?: boolean;
    handlesIntraState?: boolean;
  },
  load: Pick<
    Load,
    | 'originCity'
    | 'originState'
    | 'destinationCity'
    | 'destinationState'
    | 'equipmentType'
  >,
): boolean {
  const originIsUSA = USA_STATE.test(load.originState) && load.originState.length === 2;
  const destIsUSA =
    USA_STATE.test(load.destinationState) && load.destinationState.length === 2;
  const coversUSA = Boolean(user.coversUSA);
  const coverageUSAStates = user.coverageUSAStates ?? [];

  if (originIsUSA || destIsUSA) {
    if (!coversUSA) return false;
    if (originIsUSA && destIsUSA) {
      if (!coverageUSAStates.length) return true;
      return (
        coverageUSAStates.includes(load.originState) &&
        coverageUSAStates.includes(load.destinationState)
      );
    }
    const usaState = originIsUSA ? load.originState : load.destinationState;
    if (coverageUSAStates.length && !coverageUSAStates.includes(usaState)) return false;
    if (user.routes.length) {
      return user.routes.some((r) =>
        routeMatches(r, load.originState, load.destinationState, load.equipmentType),
      );
    }
    return true;
  }

  if (user.routes.length) {
    return user.routes.some((r) =>
      routeMatches(r, load.originState, load.destinationState, load.equipmentType),
    );
  }

  if (load.originState === load.destinationState) {
    if (load.originCity === load.destinationCity) {
      if (user.handlesLocal) return true;
    } else if (user.handlesIntraState) {
      return true;
    }
  }

  const eqOk =
    !user.coverageEquipmentTypes.length ||
    user.coverageEquipmentTypes.includes(load.equipmentType);

  if (user.coverageStates.length) {
    return (
      eqOk &&
      user.coverageStates.includes(load.originState) &&
      user.coverageStates.includes(load.destinationState)
    );
  }

  if (user.coverageZones.length) {
    const originZone = MEXICAN_ZONES.find((z) =>
      (z.states as readonly string[]).includes(load.originState),
    )?.id;
    const destZone = MEXICAN_ZONES.find((z) =>
      (z.states as readonly string[]).includes(load.destinationState),
    )?.id;
    return (
      eqOk &&
      !!originZone &&
      !!destZone &&
      user.coverageZones.includes(originZone) &&
      user.coverageZones.includes(destZone)
    );
  }

  return true;
}

export const MX_STATES = MEXICAN_ZONES.flatMap((z) => [...z.states]);

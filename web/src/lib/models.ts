/** Mirrors iOS UserModels / LoadModels / OfferModels / UnitModels. */

export type UserRole = 'admin' | 'carrier' | 'independent_operator' | 'pricer';

export type UserStatus =
  | 'pending_approval'
  | 'approved'
  | 'rejected'
  | 'suspended';

/** Exact raw values must match iOS EquipmentType + Firestore rules. */
export const EQUIPMENT_TYPES = [
  "Caja Seca 48'",
  "Caja Seca 53'",
  'Plataforma',
  'Refrigerado',
  'Rabón',
  'Tортón', // Cyrillic "о" — matches iOS / Firestore rules
  'Sencillo Portacontenedor',
  'Full Portacontenedor',
] as const;

export type EquipmentType = (typeof EQUIPMENT_TYPES)[number];

export const ASSIGNMENT_MODES = [
  'Tarifa Fija',
  'Subasta Inversa',
  'Confirmación Manual',
  'Consolidada LTL',
] as const;

export type AssignmentMode = (typeof ASSIGNMENT_MODES)[number];

export const LOAD_STATUSES = [
  'Publicado',
  'Asignado',
  'En camino a recolección',
  'En origen',
  'Cargado',
  'En tránsito',
  'Entregado',
  'Cancelado',
] as const;

export type LoadStatus = (typeof LOAD_STATUSES)[number];

export const SPECIAL_REQUIREMENTS = [
  'Refrigeración',
  'Material Peligroso',
  'Acceso a Puerto',
  'Carga Sobredimensionada',
  'Plataforma Hidráulica',
  'Operadores en Equipo',
] as const;

export type SpecialRequirement = (typeof SPECIAL_REQUIREMENTS)[number];

export type Currency = 'MXN' | 'USD';

export const OFFER_STATUSES = [
  'Activa',
  'Ganando',
  'Superada',
  'Ganadora',
  'Perdida',
  'Cancelada',
  'Rechazada',
  'PendienteAprobacion',
] as const;

export type OfferStatus = (typeof OFFER_STATUSES)[number];

export const UNIT_STATUSES = [
  'Disponible',
  'Reservada',
  'En viaje',
  'Fuera de servicio',
] as const;

export type UnitStatus = (typeof UNIT_STATUSES)[number];

export type NotificationType =
  | 'new_load'
  | 'outbid'
  | 'auction_closing_soon'
  | 'load_assigned'
  | 'load_cancelled'
  | 'status_changed'
  | 'registration_approved'
  | 'registration_rejected';

export const MEXICAN_STATES = [
  'Aguascalientes',
  'B.C.',
  'B.C.S.',
  'Campeche',
  'Chiapas',
  'Chihuahua',
  'Coahuila',
  'Colima',
  'CDMX',
  'Durango',
  'Estado de México',
  'Guanajuato',
  'Guerrero',
  'Hidalgo',
  'Jalisco',
  'Michoacán',
  'Morelos',
  'Nayarit',
  'N.L.',
  'Oaxaca',
  'Puebla',
  'Querétaro',
  'Quintana Roo',
  'S.L.P.',
  'Sinaloa',
  'Sonora',
  'Tabasco',
  'Tamaulipas',
  'Tlaxcala',
  'Veracruz',
  'Yucatán',
  'Zacatecas',
] as const;

export type MexicanState = (typeof MEXICAN_STATES)[number];

export const US_STATES = [
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL',
  'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME',
  'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH',
  'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI',
  'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
] as const;

export type USState = (typeof US_STATES)[number];

export const MEXICAN_ZONES = [
  {
    id: 'Noroeste',
    states: ['B.C.', 'B.C.S.', 'Sonora', 'Sinaloa', 'Nayarit'],
  },
  {
    id: 'Norte',
    states: ['Chihuahua', 'Coahuila', 'Durango', 'N.L.', 'Tamaulipas', 'Zacatecas'],
  },
  {
    id: 'Bajío',
    states: ['Aguascalientes', 'Guanajuato', 'Querétaro', 'S.L.P.'],
  },
  {
    id: 'Centro Occidente',
    states: ['Jalisco', 'Colima', 'Michoacán'],
  },
  {
    id: 'Centro',
    states: ['CDMX', 'Estado de México', 'Hidalgo', 'Morelos', 'Puebla', 'Tlaxcala'],
  },
  {
    id: 'Sur',
    states: ['Guerrero', 'Oaxaca', 'Veracruz'],
  },
  {
    id: 'Sureste',
    states: ['Campeche', 'Chiapas', 'Quintana Roo', 'Tabasco', 'Yucatán'],
  },
] as const;

export interface CarrierRoute {
  id: string;
  originState: string;
  destinationState: string;
  bidirectional: boolean;
  equipmentTypes: EquipmentType[];
}

export interface AppUser {
  uuid: string;
  name: string;
  email: string;
  phone: string;
  phoneDigits?: string;
  role: UserRole;
  status: UserStatus;
  companyId?: string;
  canNegotiateRates: boolean;
  handlesLTL: boolean;
  handlesLocal?: boolean;
  handlesIntraState?: boolean;
  coversUSA?: boolean;
  routes: CarrierRoute[];
  coverageStates: string[];
  coverageZones: string[];
  coverageEquipmentTypes: EquipmentType[];
  coverageUSAStates?: string[];
  notificationEmails?: string[];
  whatsappNumbers?: string[];
  /** Pricer assigned to this carrier. */
  pricerId?: string;
  createdAt?: Date;
}

export interface TransportCompany {
  id: string;
  name: string;
  contactName: string;
  phone: string;
  email: string;
  rfc: string;
  status: UserStatus;
  createdAt: Date;
}

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
  /** Admin-only / assigned — never show raw value to unassigned carriers. */
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
  postedOriginState: string;
  postedDestinationState: string;
  isAvailabilityPosted: boolean;
}

export function phoneDigits(phone: string): string {
  return phone.replace(/\D/g, '');
}

export function newUuid(): string {
  return crypto.randomUUID();
}

export function loadOriginDisplay(load: Pick<Load, 'originCity' | 'originState'>): string {
  return `${load.originCity}, ${load.originState}`;
}

export function loadDestinationDisplay(
  load: Pick<Load, 'destinationCity' | 'destinationState'>,
): string {
  return `${load.destinationCity}, ${load.destinationState}`;
}

export function loadIsFull(load: Pick<Load, 'unitCount' | 'confirmedUnitCount'>): boolean {
  return load.unitCount > 0 && load.confirmedUnitCount >= load.unitCount;
}

export function loadIsOpen(
  load: Pick<Load, 'status' | 'deadline' | 'unitCount' | 'confirmedUnitCount'>,
): boolean {
  return load.status === 'Publicado' && new Date() < load.deadline && !loadIsFull(load);
}

/** Published and still missing a carrier. Every pricer can work these. */
export function loadAwaitingCarrier(
  load: Pick<Load, 'status' | 'unitCount' | 'confirmedUnitCount' | 'assignedCarrierId'>,
): boolean {
  return load.status === 'Publicado' && !load.assignedCarrierId && !loadIsFull(load);
}

export function loadStatusIsActive(status: LoadStatus): boolean {
  return status !== 'Entregado' && status !== 'Cancelado';
}

export function unitIsAvailableFor(
  unit: Pick<Unit, 'status' | 'availableFrom'>,
  pickupDate: Date,
): boolean {
  return unit.status === 'Disponible' && unit.availableFrom <= pickupDate;
}

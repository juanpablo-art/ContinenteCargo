/** Mirrors iOS UserModels / UnitModels auth-relevant enums and types. */

export type UserRole = 'admin' | 'carrier' | 'independent_operator';

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
  routes: CarrierRoute[];
  coverageStates: string[];
  coverageZones: string[];
  coverageEquipmentTypes: EquipmentType[];
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

export function phoneDigits(phone: string): string {
  return phone.replace(/\D/g, '');
}

export function newUuid(): string {
  return crypto.randomUUID();
}

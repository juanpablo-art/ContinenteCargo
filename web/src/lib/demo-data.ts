/** DEV-only sample data for the `ccDemoRole` screenshot login. Never imported in production paths. */
import type { AppNotification, AppUser, Load, Offer, Unit } from '@/lib/models';

const H = 3600000;
const D = 24 * H;
const now = Date.now();
const at = (ms: number) => new Date(now + ms);

const DEMO = 'demo-layout';

function load(partial: Partial<Load> & Pick<Load, 'id' | 'reference'>): Load {
  return {
    originCity: 'Monterrey',
    originState: 'N.L.',
    destinationCity: 'Ciudad de México',
    destinationState: 'CDMX',
    pickupDate: at(2 * D),
    deliveryDate: at(4 * D),
    equipmentType: "Caja Seca 53'",
    unitCount: 1,
    weightKg: 22000,
    merchandiseDescription: 'Electrodomésticos paletizados',
    measurementsDescription: '26 tarimas 1.2 × 1.0 m',
    specialRequirements: [],
    offeredPrice: 38500,
    currency: 'MXN',
    includesVAT: false,
    maxAuthorizedPriceSinIVA: 41000,
    includedConcepts: 'Flete, maniobras de carga',
    allowedExtraExpenses: 'Casetas',
    assignmentMode: 'Tarifa Fija',
    deadline: at(9 * H),
    minBidDecrement: 500,
    observations: '',
    status: 'Publicado',
    publishedBy: 'admin',
    publishedAt: at(-6 * H),
    trackingUrl: '',
    statusHistory: [],
    clientContactName: 'Laura Méndez',
    clientContactPhone: '81 5555 0101',
    exactPickupAddress: 'Av. Industrial 450, Apodaca, N.L.',
    exactDeliveryAddress: 'Calz. Vallejo 1020, Azcapotzalco, CDMX',
    notificationChannels: { inApp: true, email: true, whatsapp: true, aiCall: false },
    confirmedCarrierIds: [],
    confirmedUnitCount: 0,
    ...partial,
  };
}

export function demoLoads(): Load[] {
  return [
    load({ id: 'l1', reference: 'CC-24-1081' }),
    load({
      id: 'l2',
      reference: 'CC-24-1082',
      originCity: 'Guadalajara',
      originState: 'Jalisco',
      destinationCity: 'Querétaro',
      destinationState: 'Querétaro',
      equipmentType: 'Refrigerado',
      specialRequirements: ['Refrigeración'],
      offeredPrice: 23000,
      includesVAT: true,
      assignmentMode: 'Subasta Inversa',
      deadline: at(2 * H),
      weightKg: 14500,
    }),
    load({
      id: 'l8',
      reference: 'CC-24-1066',
      status: 'En tránsito',
      assignedCarrierId: 'c9',
      confirmedCarrierIds: ['c9'],
      confirmedUnitCount: 1,
      originCity: 'Saltillo',
      originState: 'Coahuila',
      destinationCity: 'Monterrey',
      destinationState: 'N.L.',
      offeredPrice: 14200,
      pickupDate: at(-1 * D),
      deliveryDate: at(D),
      deadline: at(-2 * D),
    }),
    load({
      id: 'l3',
      reference: 'CC-24-1083',
      originCity: 'Nuevo Laredo',
      originState: 'Tamaulipas',
      destinationCity: 'Saltillo',
      destinationState: 'Coahuila',
      unitCount: 4,
      confirmedUnitCount: 1,
      confirmedCarrierIds: ['c9'],
      offeredPrice: 18900,
      equipmentType: 'Plataforma',
      assignmentMode: 'Confirmación Manual',
      deadline: at(30 * H),
    }),
    load({
      id: 'l4',
      reference: 'CC-24-1084',
      originCity: 'Puebla',
      originState: 'Puebla',
      destinationCity: 'Veracruz',
      destinationState: 'Veracruz',
      equipmentType: "Caja Seca 48'",
      assignmentMode: 'Consolidada LTL',
      offeredPrice: 9800,
      weightKg: 4200,
      deadline: at(3 * D),
    }),
    load({
      id: 'l5',
      reference: 'CC-24-1075',
      status: 'En tránsito',
      assignedCarrierId: DEMO,
      confirmedCarrierIds: [DEMO],
      confirmedUnitCount: 1,
      originCity: 'León',
      originState: 'Guanajuato',
      destinationCity: 'Tijuana',
      destinationState: 'B.C.',
      offeredPrice: 64200,
      pickupDate: at(-1 * D),
      deliveryDate: at(2 * D),
      deadline: at(-2 * D),
    }),
    load({
      id: 'l6',
      reference: 'CC-24-1070',
      status: 'Asignado',
      assignedCarrierId: DEMO,
      confirmedCarrierIds: [DEMO],
      confirmedUnitCount: 1,
      originCity: 'San Luis Potosí',
      originState: 'S.L.P.',
      destinationCity: 'Mérida',
      destinationState: 'Yucatán',
      offeredPrice: 52700,
      deadline: at(-1 * D),
    }),
    load({
      id: 'l7',
      reference: 'CC-24-1061',
      status: 'Entregado',
      assignedCarrierId: 'c9',
      originCity: 'Toluca',
      originState: 'Estado de México',
      destinationCity: 'Morelia',
      destinationState: 'Michoacán',
      offeredPrice: 15400,
      pickupDate: at(-6 * D),
      deliveryDate: at(-5 * D),
      deadline: at(-7 * D),
    }),
  ];
}

export function demoOffers(): Offer[] {
  const base = {
    unitId: 'u1',
    currency: 'MXN' as const,
    isAvailabilityOnly: false,
    availableUnitCount: 1,
    notes: '',
  };
  return [
    { ...base, id: 'o1', loadId: 'l2', carrierId: DEMO, carrierName: 'Transportes del Norte', amount: 22000, status: 'Ganando', submittedAt: at(-40 * 60000) },
    { ...base, id: 'o2', loadId: 'l1', carrierId: DEMO, carrierName: 'Transportes del Norte', amount: 38500, proposedPrice: 36800, status: 'PendienteAprobacion', submittedAt: at(-2 * H) },
    { ...base, id: 'o3', loadId: 'l3', carrierId: 'c9', carrierName: 'Fletes Rápidos Saltillo', amount: 18900, availableUnitCount: 2, proposedPrice: 18200, status: 'PendienteAprobacion', submittedAt: at(-3 * H) },
    { ...base, id: 'o4', loadId: 'l5', carrierId: DEMO, carrierName: 'Transportes del Norte', amount: 64200, status: 'Ganadora', submittedAt: at(-3 * D) },
  ];
}

export function demoUnits(): Unit[] {
  const base = {
    ownerId: DEMO,
    trailerNumber: '',
    scac: 'TDNM',
    caat: 'CA-88213',
    availableFrom: at(-D),
    coverageZones: ['Norte', 'Centro'],
    notes: '',
    postedOriginState: '',
    postedDestinationState: '',
    isAvailabilityPosted: false,
  };
  return [
    { ...base, id: 'u1', equipmentType: "Caja Seca 53'", plates: '58-AK-3K', trailerNumber: 'CJ-1029', currentLocation: 'Monterrey, N.L.', operatorName: 'Rogelio Treviño', status: 'Disponible', isAvailabilityPosted: true, postedOriginState: 'N.L.', postedDestinationState: 'CDMX' },
    { ...base, id: 'u2', equipmentType: 'Refrigerado', plates: '71-BD-9R', currentLocation: 'León, Gto.', operatorName: 'Arturo Salinas', status: 'En viaje' },
    { ...base, id: 'u3', equipmentType: 'Plataforma', plates: '33-CF-1M', currentLocation: 'Saltillo, Coah.', operatorName: 'Daniel Garza', status: 'Reservada' },
    { ...base, id: 'u4', equipmentType: 'Rabón', plates: '12-AA-7P', currentLocation: 'Apodaca, N.L.', operatorName: '', status: 'Fuera de servicio' },
  ];
}

export function demoNotifications(): AppNotification[] {
  return [
    { id: 'n1', userId: DEMO, type: 'new_load', title: 'Nueva carga en tu ruta', body: 'Monterrey, N.L. → Ciudad de México, CDMX · Caja Seca 53\'', loadId: 'l1', isRead: false, createdAt: at(-25 * 60000) },
    { id: 'n2', userId: DEMO, type: 'auction_closing_soon', title: 'La subasta cierra pronto', body: 'CC-24-1082 cierra en 2 horas. Vas ganando con MXN $22,000.', loadId: 'l2', isRead: false, createdAt: at(-70 * 60000) },
    { id: 'n3', userId: DEMO, type: 'status_changed', title: 'Viaje en tránsito', body: 'CC-24-1075 cambió a En tránsito.', loadId: 'l5', isRead: true, createdAt: at(-D) },
    { id: 'n4', userId: DEMO, type: 'registration_approved', title: 'Cuenta aprobada', body: 'Ya puedes tomar cargas y enviar ofertas.', isRead: true, createdAt: at(-9 * D) },
  ];
}

export function demoUsers(): AppUser[] {
  const base = {
    canNegotiateRates: true,
    handlesLTL: false,
    routes: [],
    coverageStates: [],
    coverageZones: ['Norte', 'Bajío'],
    coverageEquipmentTypes: [],
  };
  return [
    { ...base, uuid: 'p1', name: 'Ana Ruiz', email: 'ana.ruiz@continentecargo.com', phone: '81 8000 2201', role: 'pricer', status: 'approved', createdAt: at(-20 * D) },
    { ...base, uuid: 'c9', name: 'Fletes Rápidos Saltillo', email: 'ops@fletesrapidos.mx', phone: '844 555 0192', role: 'carrier', status: 'approved', pricerId: 'p1', createdAt: at(-40 * D) },
    { ...base, uuid: 'c10', name: 'Héctor Villarreal', email: 'hector.v@gmail.com', phone: '81 1234 5678', role: 'independent_operator', status: 'pending_approval', createdAt: at(-5 * H) },
    { ...base, uuid: 'c11', name: 'Logística Bajío Express', email: 'contacto@bajioexpress.mx', phone: '477 555 0110', role: 'carrier', status: 'pending_approval', handlesLTL: true, createdAt: at(-D) },
    { ...base, uuid: 'c12', name: 'Transportes del Norte', email: 'trafico@tdn.mx', phone: '81 5555 0177', role: 'carrier', status: 'approved', pricerId: 'p1', createdAt: at(-90 * D) },
    { ...base, uuid: 'c13', name: 'Autotransportes Pacífico', email: 'ventas@atpacifico.mx', phone: '667 555 0133', role: 'carrier', status: 'suspended', createdAt: at(-120 * D) },
  ];
}

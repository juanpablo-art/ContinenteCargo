import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  Timestamp,
  updateDoc,
  type DocumentData,
} from 'firebase/firestore';
import { auth, db } from '@/plugins/firebase';
import { MEXICAN_ZONES, newUuid, type CarrierRoute } from '@/lib/models';

export type AccountStatus = '' | 'approved' | 'pending_approval' | 'rejected' | 'suspended';

/** What the pricer should do next. The invite itself is always their action. */
export type FollowUp = 'unsent' | 'waiting' | 'failed' | 'issue' | 'ready';

/** Mirrors iOS CarrierDirectoryRecord / carrier_preprofiles. */
export interface CarrierDirectoryRecord {
  id: string;
  companyName: string;
  contactName: string;
  phone: string;
  email: string;
  baseCity: string;
  equipmentTypes: string[];
  coverageZones: string[];
  handlesLTL: boolean;
  handlesLocal?: boolean;
  handlesIntraState?: boolean;
  coversUSA?: boolean;
  /** Nombre de la persona, distinto del contacto de la empresa cuando el registro los separa. */
  name?: string;
  coverageStates?: string[];
  coverageUSAStates?: string[];
  routes?: CarrierRoute[];
  notificationEmails?: string[];
  whatsappNumbers?: string[];
  /** Invitation state on the preprofile: pending_invitation, sent, failed, registered. */
  status: string;
  /** Pricer who sent the invitation and owns the follow-up. Empty until they send it. */
  pricerEmail: string;
  /** True when a carrier account already exists for this phone or email. */
  registered: boolean;
  accountStatus: AccountStatus;
  followUp: FollowUp;
}

export type InviteChannel = 'whatsapp' | 'email' | 'auto';

export interface AccountMatch {
  status: AccountStatus;
}

export interface RegistrationIndex {
  phones: Map<string, AccountMatch>;
  emails: Map<string, AccountMatch>;
}

interface ContactLike {
  role?: string;
  status?: string;
  phone?: string;
  phoneDigits?: string;
  email?: string;
  whatsappNumbers?: string[];
  notificationEmails?: string[];
}

export interface ManualInviteInput {
  contactName: string;
  companyName: string;
  phone: string;
  email: string;
  baseCity: string;
  equipmentTypes: string[];
  coverageZones: string[];
  /** Exact Mexican states kept after the admin removes some from a zone. */
  coverageStates: string[];
  handlesLTL: boolean;
  handlesLocal: boolean;
  handlesIntraState: boolean;
  coversUSA: boolean;
  coverageUSAStates: string[];
}

const demoDirectory: CarrierDirectoryRecord[] = [
  {
    id: '8110001001',
    companyName: 'Fletes del Golfo',
    contactName: 'Raúl Peña',
    phone: '8110001001',
    email: 'raul@fletesgolfo.mx',
    baseCity: 'Monterrey, N.L.',
    equipmentTypes: ["Caja Seca 53'", 'Plataforma'],
    coverageZones: ['Norte', 'Centro'],
    handlesLTL: false,
    status: 'pending_invitation',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'unsent',
  },
  {
    id: '3310002002',
    companyName: 'Logística Occidente',
    contactName: 'Patricia Ríos',
    phone: '3310002002',
    email: 'patricia@loccidente.mx',
    baseCity: 'Guadalajara, Jalisco',
    equipmentTypes: ['Refrigerado'],
    coverageZones: ['Centro Occidente'],
    handlesLTL: true,
    status: 'pending_invitation',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'unsent',
  },
  {
    id: '5510003003',
    companyName: 'Transportes Altiplano',
    contactName: 'Jorge Medina',
    phone: '5510003003',
    email: '',
    baseCity: 'Puebla',
    equipmentTypes: ["Caja Seca 48'"],
    coverageZones: ['Centro', 'Sur'],
    handlesLTL: false,
    status: 'sent',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'waiting',
  },
  {
    id: '6640004004',
    companyName: 'Pacífico Carga',
    contactName: 'Elena Cruz',
    phone: '6640004004',
    email: 'elena@pacificocarga.mx',
    baseCity: 'Tijuana, B.C.',
    equipmentTypes: ['Plataforma', 'Full Portacontenedor'],
    coverageZones: ['Noroeste'],
    handlesLTL: false,
    status: 'registered',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'issue',
  },
  {
    id: '8445550192',
    companyName: 'Fletes Rápidos Saltillo',
    contactName: 'Mesa de control',
    phone: '8445550192',
    email: 'ops@fletesrapidos.mx',
    baseCity: 'Saltillo, Coahuila',
    equipmentTypes: ["Caja Seca 53'"],
    coverageZones: ['Norte'],
    handlesLTL: false,
    status: 'sent',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'waiting',
  },
  {
    id: '8112345678',
    companyName: 'Héctor Villarreal',
    contactName: 'Héctor Villarreal',
    phone: '8112345678',
    email: 'hector.v@gmail.com',
    baseCity: 'Monterrey, N.L.',
    equipmentTypes: ['Rabón'],
    coverageZones: ['Norte'],
    handlesLTL: false,
    status: 'sent',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'waiting',
  },
  {
    id: '4775550110',
    companyName: 'Logística Bajío Express',
    contactName: 'Logística Bajío Express',
    phone: '4775550110',
    email: 'contacto@bajioexpress.mx',
    baseCity: 'León, Guanajuato',
    equipmentTypes: ["Caja Seca 53'"],
    coverageZones: ['Bajío'],
    handlesLTL: true,
    status: 'sent',
    pricerEmail: 'otro.pricer@continentecargo.com',
    registered: false,
    accountStatus: '',
    followUp: 'waiting',
  },
  {
    id: '9990005005',
    companyName: 'Sureste Express',
    contactName: 'Luis Canul',
    phone: '9990005005',
    email: 'luis@sureste.mx',
    baseCity: 'Mérida, Yucatán',
    equipmentTypes: ['Rabón'],
    coverageZones: ['Sureste'],
    handlesLTL: true,
    status: 'failed',
    pricerEmail: '',
    registered: false,
    accountStatus: '',
    followUp: 'failed',
  },
];

export function demoDirectoryRecords(): CarrierDirectoryRecord[] {
  return demoDirectory;
}

export function upsertDemoRecord(record: CarrierDirectoryRecord) {
  const idx = demoDirectory.findIndex((r) => r.id === record.id);
  if (idx >= 0) demoDirectory[idx] = record;
  else demoDirectory.push(record);
}

function asStringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : [];
}

/** Last 10 Mexican digits, dropping a leading 52 or 521 country code. */
export function directoryPhone(phone: string): string {
  let digits = phone.replace(/\D/g, '');
  if (digits.startsWith('521') && digits.length === 13) digits = digits.slice(3);
  else if (digits.startsWith('52') && digits.length === 12) digits = digits.slice(2);
  if (digits.length > 10) digits = digits.slice(-10);
  return digits.length === 10 ? digits : '';
}

function asAccountStatus(value: unknown): AccountStatus {
  if (
    value === 'approved' ||
    value === 'pending_approval' ||
    value === 'rejected' ||
    value === 'suspended'
  ) {
    return value;
  }
  return '';
}

const ACCOUNT_RANK: Record<AccountStatus, number> = {
  '': 0,
  approved: 1,
  pending_approval: 2,
  suspended: 3,
  rejected: 4,
};

function remember(map: Map<string, AccountMatch>, key: string, status: AccountStatus) {
  if (!key || !status) return;
  const previous = map.get(key);
  if (!previous || ACCOUNT_RANK[status] > ACCOUNT_RANK[previous.status]) {
    map.set(key, { status });
  }
}

export function registrationIndexFromContacts(contacts: ContactLike[]): RegistrationIndex {
  const phones = new Map<string, AccountMatch>();
  const emails = new Map<string, AccountMatch>();
  for (const contact of contacts) {
    if (contact.role && contact.role !== 'carrier' && contact.role !== 'independent_operator') {
      continue;
    }
    const status = asAccountStatus(contact.status);
    if (!status) continue;
    const phoneKeys = [contact.phone, contact.phoneDigits, ...(contact.whatsappNumbers ?? [])];
    for (const value of phoneKeys) {
      if (typeof value === 'string') remember(phones, directoryPhone(value), status);
    }
    const emailKeys = [contact.email, ...(contact.notificationEmails ?? [])];
    for (const value of emailKeys) {
      if (typeof value !== 'string') continue;
      const email = value.trim().toLowerCase();
      if (email.includes('@')) remember(emails, email, status);
    }
  }
  return { phones, emails };
}

function lookupAccount(record: CarrierDirectoryRecord, index: RegistrationIndex): AccountMatch | null {
  const phone = directoryPhone(record.phone || record.id);
  const email = record.email.trim().toLowerCase();
  if (phone && index.phones.has(phone)) return index.phones.get(phone) ?? null;
  if (email.includes('@') && index.emails.has(email)) return index.emails.get(email) ?? null;
  return null;
}

export function followUpFor(record: Pick<CarrierDirectoryRecord, 'status'>, match: AccountMatch | null): FollowUp {
  if (match?.status === 'approved') return 'ready';
  if (match) return 'issue';
  if (record.status === 'registered') return 'issue';
  if (record.status === 'failed') return 'failed';
  if (record.status === 'sent') return 'waiting';
  return 'unsent';
}

export function followUpCopy(record: CarrierDirectoryRecord): { label: string; detail: string; tone: string } {
  if (record.followUp === 'ready') {
    return {
      label: 'Registro listo',
      detail: 'Ya puede operar. No hace falta insistir.',
      tone: 'text-success',
    };
  }
  if (record.followUp === 'issue') {
    if (record.accountStatus === 'pending_approval') {
      return {
        label: 'Falta aprobación',
        detail: 'Ya se registró, pero su cuenta sigue pendiente. Confírmale que terminó y revisa la aprobación.',
        tone: 'text-orange',
      };
    }
    if (record.accountStatus === 'rejected') {
      return {
        label: 'Registro rechazado',
        detail: 'Se registró, pero la cuenta fue rechazada. Hay que resolverlo antes de que opere.',
        tone: 'text-danger',
      };
    }
    if (record.accountStatus === 'suspended') {
      return {
        label: 'Cuenta suspendida',
        detail: 'Se registró, pero la cuenta está suspendida.',
        tone: 'text-danger',
      };
    }
    return {
      label: 'Sin cuenta',
      detail: 'Figura como registrado, pero no hay una cuenta con este teléfono o correo.',
      tone: 'text-orange',
    };
  }
  if (record.followUp === 'failed') {
    return {
      label: 'No llegó',
      detail: 'La invitación no se pudo enviar. Envíala de nuevo.',
      tone: 'text-danger',
    };
  }
  if (record.followUp === 'waiting') {
    return {
      label: 'Invitación enviada',
      detail: 'Aún no se registra. Dale seguimiento para que termine.',
      tone: 'text-orange',
    };
  }
  return {
    label: 'Sin enviar',
    detail: 'La invitación la envías tú, para poder darle seguimiento al registro.',
    tone: 'text-muted',
  };
}

export function withRegistration(
  records: CarrierDirectoryRecord[],
  users: RegistrationIndex,
  companies: RegistrationIndex = { phones: new Map(), emails: new Map() },
): CarrierDirectoryRecord[] {
  return records.map((record) => {
    const match = lookupAccount(record, users) ?? lookupAccount(record, companies);
    const followUp = followUpFor(record, match);
    return {
      ...record,
      registered: Boolean(match),
      accountStatus: match?.status ?? '',
      followUp,
    };
  });
}

function contactFromDoc(data: DocumentData, role?: string): ContactLike {
  return {
    role,
    status: typeof data.status === 'string' ? data.status : '',
    phone: typeof data.phone === 'string' ? data.phone : '',
    phoneDigits: typeof data.phoneDigits === 'string' ? data.phoneDigits : '',
    email: typeof data.email === 'string' ? data.email : '',
    whatsappNumbers: asStringList(data.whatsappNumbers),
    notificationEmails: asStringList(data.notificationEmails),
  };
}

async function loadRegistrationIndexes(): Promise<{
  users: RegistrationIndex;
  companies: RegistrationIndex;
}> {
  const [usersSnap, companiesSnap] = await Promise.all([
    getDocs(collection(db, 'users')),
    getDocs(collection(db, 'companies')).catch(() => null),
  ]);
  const users = registrationIndexFromContacts(
    usersSnap.docs.map((item) => {
      const data = item.data();
      const role = typeof data.role === 'string' ? data.role : undefined;
      return contactFromDoc(data, role);
    }),
  );
  const companies = registrationIndexFromContacts(
    companiesSnap?.docs.map((item) => contactFromDoc(item.data())) ?? [],
  );
  return { users, companies };
}

export async function fetchCarrierDirectory(): Promise<CarrierDirectoryRecord[]> {
  const [snap, indexes] = await Promise.all([
    getDocs(collection(db, 'carrier_preprofiles')),
    loadRegistrationIndexes(),
  ]);
  const records: CarrierDirectoryRecord[] = [];
  snap.forEach((item) => {
    const data = item.data();
    const companyName = typeof data.companyName === 'string' ? data.companyName : '';
    if (!companyName) return;
    records.push({
      id: item.id,
      companyName,
      contactName: typeof data.contactName === 'string' ? data.contactName : '',
      phone: typeof data.phone === 'string' && data.phone ? data.phone : item.id,
      email: typeof data.email === 'string' ? data.email : '',
      baseCity: typeof data.baseCity === 'string' ? data.baseCity : '',
      equipmentTypes: asStringList(data.equipmentTypes),
      coverageZones: asStringList(data.coverageZones),
      handlesLTL: Boolean(data.handlesLTL),
      status: typeof data.status === 'string' ? data.status : 'pending_invitation',
      pricerEmail: typeof data.pricerEmail === 'string' ? data.pricerEmail : '',
      registered: false,
      accountStatus: '',
      followUp: 'unsent',
    });
  });
  return withRegistration(records, indexes.users, indexes.companies);
}

export interface CarrierProfileDraft {
  name: string;
  companyName: string;
  contactName: string;
  email: string;
  baseCity: string;
  equipmentTypes: string[];
  coverageZones: string[];
  coverageStates: string[];
  handlesLTL: boolean;
  handlesLocal: boolean;
  handlesIntraState: boolean;
  coversUSA: boolean;
  coverageUSAStates: string[];
  routes: CarrierRoute[];
  notificationEmails: string[];
  whatsappNumbers: string[];
}

export interface CarrierProfile extends CarrierProfileDraft {
  id: string;
  phone: string;
  status: string;
  pricerEmail: string;
}

function statesFromZones(zones: string[]): string[] {
  return zones.flatMap((zoneId) => {
    const zone = MEXICAN_ZONES.find((item) => item.id === zoneId);
    return zone ? [...zone.states] : [];
  });
}

export function zonesFromStates(states: string[]): string[] {
  return MEXICAN_ZONES.filter((zone) =>
    zone.states.some((state) => states.includes(state)),
  ).map((zone) => zone.id);
}

function asRoutes(value: unknown): CarrierRoute[] {
  if (!Array.isArray(value)) return [];
  const routes: CarrierRoute[] = [];
  for (const item of value) {
    if (!item || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    if (typeof row.originState !== 'string' || typeof row.destinationState !== 'string') continue;
    routes.push({
      id: typeof row.id === 'string' ? row.id : newUuid(),
      originState: row.originState,
      destinationState: row.destinationState,
      bidirectional: row.bidirectional !== false,
      equipmentTypes: asStringList(row.equipmentTypes) as CarrierRoute['equipmentTypes'],
    });
  }
  return routes;
}

function profileFromRecord(record: CarrierDirectoryRecord): CarrierProfile {
  const coverageStates = record.coverageStates?.length
    ? [...record.coverageStates]
    : statesFromZones(record.coverageZones);
  return {
    id: record.id,
    name: record.name || record.contactName,
    companyName: record.companyName,
    contactName: record.contactName,
    phone: record.phone,
    email: record.email,
    baseCity: record.baseCity,
    equipmentTypes: [...record.equipmentTypes],
    coverageZones: [...record.coverageZones],
    coverageStates,
    handlesLTL: record.handlesLTL,
    handlesLocal: Boolean(record.handlesLocal),
    handlesIntraState: Boolean(record.handlesIntraState),
    coversUSA: Boolean(record.coversUSA),
    coverageUSAStates: [...(record.coverageUSAStates ?? [])],
    routes: record.routes ? record.routes.map((route) => ({ ...route, equipmentTypes: [...route.equipmentTypes] })) : [],
    notificationEmails: [...(record.notificationEmails ?? [])],
    whatsappNumbers: [...(record.whatsappNumbers ?? [])],
    status: record.status,
    pricerEmail: record.pricerEmail,
  };
}

function profileFromData(id: string, data: DocumentData): CarrierProfile | null {
  const companyName = typeof data.companyName === 'string' ? data.companyName : '';
  if (!companyName) return null;
  return {
    id,
    companyName,
    contactName: typeof data.contactName === 'string' ? data.contactName : '',
    phone: typeof data.phone === 'string' && data.phone ? data.phone : id,
    email: typeof data.email === 'string' ? data.email : '',
    baseCity: typeof data.baseCity === 'string' ? data.baseCity : '',
    equipmentTypes: asStringList(data.equipmentTypes),
    coverageZones: asStringList(data.coverageZones),
    coverageStates: asStringList(data.coverageStates).length
      ? asStringList(data.coverageStates)
      : statesFromZones(asStringList(data.coverageZones)),
    handlesLTL: Boolean(data.handlesLTL),
    handlesLocal: Boolean(data.handlesLocal),
    handlesIntraState: Boolean(data.handlesIntraState),
    coversUSA: Boolean(data.coversUSA),
    coverageUSAStates: asStringList(data.coverageUSAStates),
    routes: asRoutes(data.routes),
    notificationEmails: asStringList(data.notificationEmails),
    whatsappNumbers: asStringList(data.whatsappNumbers),
    name: typeof data.name === 'string' && data.name ? data.name : (typeof data.contactName === 'string' ? data.contactName : ''),
    status: typeof data.status === 'string' ? data.status : 'pending_invitation',
    pricerEmail: typeof data.pricerEmail === 'string' ? data.pricerEmail : '',
  };
}

export function carrierProfileError(input: CarrierProfileDraft): string | null {
  const company = input.companyName.trim();
  const contact = input.contactName.trim();
  const email = input.email.trim();
  const city = input.baseCity.trim();
  if (!company || company.length > 120) return 'Escribe el nombre de la empresa (máximo 120 caracteres).';
  if (contact.length > 80) return 'El nombre del contacto no puede pasar de 80 caracteres.';
  if (email && (!email.includes('@') || email.length > 120)) {
    return 'Escribe un correo válido o déjalo vacío.';
  }
  if (city.length > 80) return 'La ciudad no puede pasar de 80 caracteres.';
  if (input.name.trim().length > 80) return 'El nombre no puede pasar de 80 caracteres.';
  if (input.notificationEmails.length > 10) return 'Máximo 10 correos adicionales.';
  if (input.whatsappNumbers.length > 10) return 'Máximo 10 WhatsApp adicionales.';
  if (input.notificationEmails.some((item) => !item.includes('@') || item.length > 120)) {
    return 'Revisa los correos adicionales.';
  }
  if (input.whatsappNumbers.some((item) => !/^\d{10}$/.test(item))) {
    return 'Cada WhatsApp adicional debe tener 10 dígitos.';
  }
  if (input.routes.length > 12) return 'Máximo 12 rutas.';
  if (input.coverageUSAStates.length > 51) return 'Demasiados estados de Estados Unidos.';
  return null;
}

export function demoCarrierProfile(id: string): CarrierProfile | null {
  const row = demoDirectoryRecords().find((record) => record.id === id);
  return row ? profileFromRecord(row) : null;
}

export function saveDemoCarrierProfile(id: string, input: CarrierProfileDraft): void {
  const row = demoDirectoryRecords().find((record) => record.id === id);
  if (!row) throw new Error('No se encontró el transportista.');
  const error = carrierProfileError(input);
  if (error) throw new Error(error);
  row.name = input.name.trim();
  row.companyName = input.companyName.trim();
  row.contactName = input.contactName.trim();
  row.email = input.email.trim();
  row.baseCity = input.baseCity.trim();
  row.equipmentTypes = [...input.equipmentTypes];
  row.coverageZones = [...input.coverageZones];
  row.coverageStates = [...input.coverageStates];
  row.handlesLTL = input.handlesLTL;
  row.handlesLocal = input.handlesLocal;
  row.handlesIntraState = input.handlesIntraState;
  row.coversUSA = input.coversUSA;
  row.coverageUSAStates = [...input.coverageUSAStates];
  row.routes = input.routes.map((route) => ({ ...route, equipmentTypes: [...route.equipmentTypes] }));
  row.notificationEmails = [...input.notificationEmails];
  row.whatsappNumbers = [...input.whatsappNumbers];
}

export async function fetchCarrierProfile(id: string): Promise<CarrierProfile | null> {
  const snap = await getDoc(doc(db, 'carrier_preprofiles', id));
  if (!snap.exists()) return null;
  return profileFromData(snap.id, snap.data());
}

export async function saveCarrierProfile(id: string, input: CarrierProfileDraft): Promise<void> {
  const error = carrierProfileError(input);
  if (error) throw new Error(error);
  await updateDoc(doc(db, 'carrier_preprofiles', id), {
    name: input.name.trim(),
    companyName: input.companyName.trim(),
    contactName: input.contactName.trim(),
    email: input.email.trim(),
    baseCity: input.baseCity.trim(),
    equipmentTypes: input.equipmentTypes,
    coverageZones: input.coverageZones,
    coverageStates: input.coverageStates,
    handlesLTL: input.handlesLTL,
    handlesLocal: input.handlesLocal,
    handlesIntraState: input.handlesIntraState,
    coversUSA: input.coversUSA,
    coverageUSAStates: input.coversUSA ? input.coverageUSAStates : [],
    routes: input.routes,
    notificationEmails: input.notificationEmails,
    whatsappNumbers: input.whatsappNumbers,
  });
}

function channelFor(record: CarrierDirectoryRecord, requested: InviteChannel): 'whatsapp' | 'email' | null {
  const phone = directoryPhone(record.phone);
  const email = record.email.trim();
  if (requested === 'whatsapp') return phone ? 'whatsapp' : null;
  if (requested === 'email') return email.includes('@') ? 'email' : null;
  if (phone) return 'whatsapp';
  if (email.includes('@')) return 'email';
  return null;
}

async function mapPool<T>(items: T[], limit: number, fn: (item: T) => Promise<void>) {
  if (!items.length) return;
  let cursor = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (cursor < items.length) {
      const item = items[cursor];
      cursor += 1;
      await fn(item);
    }
  });
  await Promise.all(workers);
}

export async function inviteFromDirectory(
  records: CarrierDirectoryRecord[],
  channel: InviteChannel,
  createdBy: string,
  pricerEmail?: string,
): Promise<{ success: number; failed: number }> {
  const now = Timestamp.now();
  let success = 0;
  let failed = 0;
  const pending = records.filter((record) => record.followUp !== 'ready' && record.followUp !== 'issue');
  await mapPool(pending, 8, async (record) => {
    const chosen = channelFor(record, channel);
    const rawName = (record.contactName || record.companyName).trim();
    const name = rawName.slice(0, 80);
    if (!chosen || !name) {
      failed += 1;
      return;
    }
    const invite: Record<string, unknown> = {
      name,
      phone: directoryPhone(record.phone) || record.phone,
      channel: chosen,
      status: 'pending',
      createdAt: now,
      createdBy,
      preProfilePhone: record.id,
    };
    if (record.email.trim()) invite.email = record.email.trim();
    if (pricerEmail) invite.pricerEmail = pricerEmail;
    try {
      await setDoc(doc(collection(db, 'invitations')), invite);
      success += 1;
    } catch {
      failed += 1;
      return;
    }
    const profile: Record<string, unknown> = {
      status: 'sent',
      lastInvitedAt: now,
      inviteChannel: chosen,
    };
    if (pricerEmail) {
      profile.pricerEmail = pricerEmail;
      profile.invitedBy = createdBy;
    }
    try {
      await updateDoc(doc(db, 'carrier_preprofiles', record.id), profile);
    } catch {
      // The invitation was created; a missing pre-profile should not undo it.
    }
  });
  return { success, failed };
}

export async function saveManualPreProfileAndInvite(
  input: ManualInviteInput,
  createdBy: string,
  pricerEmail?: string,
): Promise<void> {
  const now = Timestamp.now();
  const name = (input.contactName || input.companyName).trim().slice(0, 80);
  if (input.phone) {
    const profileRef = doc(db, 'carrier_preprofiles', input.phone);
    const existing = await getDoc(profileRef);
    const previousStatus =
      existing.exists() && typeof existing.data().status === 'string' ? existing.data().status : '';
    if (previousStatus === 'registered') {
      throw new Error('Este transportista ya completó su registro.');
    }
    const profile: Record<string, unknown> = {
      companyName: input.companyName,
      contactName: input.contactName,
      phone: input.phone,
      email: input.email,
      baseCity: input.baseCity,
      equipmentTypes: input.equipmentTypes,
      coverageZones: input.coverageZones,
      coverageStates: input.coverageStates,
      handlesLTL: input.handlesLTL,
      handlesLocal: input.handlesLocal,
      handlesIntraState: input.handlesIntraState,
      coversUSA: input.coversUSA,
      coverageUSAStates: input.coversUSA ? input.coverageUSAStates : [],
      handlesHazmat: false,
      handlesImpoExpo: false,
      status: 'sent',
      lastInvitedAt: now,
      importedAt: now,
    };
    if (pricerEmail) profile.pricerEmail = pricerEmail;
    await setDoc(profileRef, profile, { merge: true });
    const wa: Record<string, unknown> = {
      name,
      phone: input.phone,
      channel: 'whatsapp',
      status: 'pending',
      createdAt: now,
      createdBy,
      preProfilePhone: input.phone,
    };
    if (input.email) wa.email = input.email;
    await setDoc(doc(collection(db, 'invitations')), wa);
  }
  if (input.email) {
    await setDoc(doc(collection(db, 'invitations')), {
      name,
      phone: input.phone,
      email: input.email,
      channel: 'email',
      status: 'pending',
      createdAt: now,
      createdBy,
      preProfilePhone: input.phone,
    });
  }
}

export async function importCarrierDirectory(): Promise<{ imported: number; error: string | null }> {
  const user = auth.currentUser;
  if (!user) return { imported: 0, error: 'No autenticado' };
  const idToken = await user.getIdToken();
  const response = await fetch(
    'https://us-central1-continente-conecta.cloudfunctions.net/importCarrierDirectory',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ data: {} }),
    },
  );
  const json = (await response.json().catch(() => null)) as
    | { result?: { imported?: number }; error?: { message?: string } | string }
    | null;
  if (!response.ok) {
    const message =
      typeof json?.error === 'string'
        ? json.error
        : json?.error?.message || 'No se pudo importar el directorio';
    return { imported: 0, error: message };
  }
  return { imported: json?.result?.imported ?? 0, error: null };
}

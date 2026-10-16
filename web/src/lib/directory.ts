import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
  type DocumentData,
} from 'firebase/firestore';
import { auth, db } from '@/plugins/firebase';

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
  status: string;
  /** True when this phone or email already belongs to a transportista account. */
  registered: boolean;
}

export type InviteChannel = 'whatsapp' | 'email' | 'auto';

export interface RegistrationIndex {
  phones: Set<string>;
  emails: Set<string>;
}

interface ContactLike {
  role?: string;
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
    registered: false,
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
    registered: false,
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
    registered: false,
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
    registered: true,
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
    registered: false,
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
    registered: false,
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

function addPhone(phones: Set<string>, value: unknown) {
  if (typeof value !== 'string' || !value) return;
  const digits = directoryPhone(value);
  if (digits) phones.add(digits);
}

function addEmail(emails: Set<string>, value: unknown) {
  if (typeof value !== 'string') return;
  const email = value.trim().toLowerCase();
  if (email.includes('@')) emails.add(email);
}

export function registrationIndexFromContacts(contacts: ContactLike[]): RegistrationIndex {
  const phones = new Set<string>();
  const emails = new Set<string>();
  for (const contact of contacts) {
    if (contact.role && contact.role !== 'carrier' && contact.role !== 'independent_operator') {
      continue;
    }
    addPhone(phones, contact.phone);
    addPhone(phones, contact.phoneDigits);
    contact.whatsappNumbers?.forEach((number) => addPhone(phones, number));
    addEmail(emails, contact.email);
    contact.notificationEmails?.forEach((email) => addEmail(emails, email));
  }
  return { phones, emails };
}

export function withRegistration(
  records: CarrierDirectoryRecord[],
  index: RegistrationIndex,
): CarrierDirectoryRecord[] {
  return records.map((record) => {
    const phone = directoryPhone(record.phone || record.id);
    const email = record.email.trim().toLowerCase();
    const registered =
      record.registered ||
      record.status === 'registered' ||
      (phone.length === 10 && index.phones.has(phone)) ||
      Boolean(email.includes('@') && index.emails.has(email));
    return {
      ...record,
      registered,
      status: registered ? 'registered' : record.status || 'pending_invitation',
    };
  });
}

function contactFromDoc(data: DocumentData, role?: string): ContactLike {
  return {
    role,
    phone: typeof data.phone === 'string' ? data.phone : '',
    phoneDigits: typeof data.phoneDigits === 'string' ? data.phoneDigits : '',
    email: typeof data.email === 'string' ? data.email : '',
    whatsappNumbers: asStringList(data.whatsappNumbers),
    notificationEmails: asStringList(data.notificationEmails),
  };
}

async function loadRegistrationIndex(): Promise<RegistrationIndex> {
  const [usersSnap, companiesSnap] = await Promise.all([
    getDocs(collection(db, 'users')),
    getDocs(collection(db, 'companies')).catch(() => null),
  ]);
  const contacts: ContactLike[] = usersSnap.docs.map((item) => {
    const data = item.data();
    const role = typeof data.role === 'string' ? data.role : undefined;
    return contactFromDoc(data, role);
  });
  companiesSnap?.forEach((item) => {
    contacts.push(contactFromDoc(item.data()));
  });
  return registrationIndexFromContacts(contacts);
}

async function persistRegistered(ids: string[]) {
  const now = Timestamp.now();
  for (let offset = 0; offset < ids.length; offset += 400) {
    const batch = writeBatch(db);
    for (const id of ids.slice(offset, offset + 400)) {
      batch.update(doc(db, 'carrier_preprofiles', id), {
        status: 'registered',
        registeredAt: now,
      });
    }
    await batch.commit();
  }
}

export async function fetchCarrierDirectory(): Promise<CarrierDirectoryRecord[]> {
  const [snap, index] = await Promise.all([
    getDocs(collection(db, 'carrier_preprofiles')),
    loadRegistrationIndex(),
  ]);
  const records: CarrierDirectoryRecord[] = [];
  const toPersist: string[] = [];
  snap.forEach((item) => {
    const data = item.data();
    const companyName = typeof data.companyName === 'string' ? data.companyName : '';
    if (!companyName) return;
    const storedStatus = typeof data.status === 'string' ? data.status : 'pending_invitation';
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
      status: storedStatus,
      registered: storedStatus === 'registered',
    });
    if (storedStatus !== 'registered') toPersist.push(item.id);
  });
  const marked = withRegistration(records, index);
  const persistIds = marked.filter((record, i) => record.registered && toPersist.includes(records[i].id));
  if (persistIds.length) {
    void persistRegistered(persistIds.map((record) => record.id)).catch(() => {
      // The screen still shows the match. The next visit can stamp the profile.
    });
  }
  return marked;
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
): Promise<{ success: number; failed: number }> {
  const now = Timestamp.now();
  let success = 0;
  let failed = 0;
  const pending = records.filter((record) => !record.registered && record.status !== 'registered');
  await mapPool(pending, 8, async (record) => {
    const chosen = channelFor(record, channel);
    if (!chosen) {
      failed += 1;
      return;
    }
    const invite: Record<string, unknown> = {
      name: record.contactName || record.companyName,
      phone: directoryPhone(record.phone) || record.phone,
      channel: chosen,
      status: 'pending',
      createdAt: now,
      createdBy,
      preProfilePhone: record.id,
    };
    if (record.email.trim()) invite.email = record.email.trim();
    try {
      await setDoc(doc(collection(db, 'invitations')), invite);
      success += 1;
    } catch {
      failed += 1;
      return;
    }
    try {
      await updateDoc(doc(db, 'carrier_preprofiles', record.id), {
        status: 'sent',
        lastInvitedAt: now,
        inviteChannel: chosen,
      });
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
  const name = input.contactName || input.companyName;
  if (input.phone) {
    const profileRef = doc(db, 'carrier_preprofiles', input.phone);
    const existing = await getDoc(profileRef);
    const previousStatus =
      existing.exists() && typeof existing.data().status === 'string' ? existing.data().status : '';
    if (previousStatus === 'registered') {
      throw new Error('Este transportista ya completó su registro.');
    }
    const status =
      previousStatus === 'sent' || previousStatus === 'failed'
        ? previousStatus
        : 'pending_invitation';
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
      status,
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

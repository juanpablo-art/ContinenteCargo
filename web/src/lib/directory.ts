import {
  collection,
  doc,
  getDocs,
  setDoc,
  Timestamp,
  updateDoc,
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

export async function fetchCarrierDirectory(): Promise<CarrierDirectoryRecord[]> {
  const snap = await getDocs(collection(db, 'carrier_preprofiles'));
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
    });
  });
  return records;
}

export async function inviteFromDirectory(
  records: CarrierDirectoryRecord[],
  channel: 'whatsapp' | 'email',
  createdBy: string,
): Promise<{ success: number; failed: number }> {
  const now = Timestamp.now();
  let success = 0;
  let failed = 0;
  for (const record of records) {
    const invite: Record<string, unknown> = {
      name: record.contactName || record.companyName,
      phone: record.phone,
      channel,
      status: 'pending',
      createdAt: now,
      createdBy,
      preProfilePhone: record.id,
    };
    if (record.email) invite.email = record.email;
    try {
      await setDoc(doc(collection(db, 'invitations')), invite);
      success += 1;
    } catch {
      failed += 1;
      continue;
    }
    try {
      await updateDoc(doc(db, 'carrier_preprofiles', record.id), {
        status: 'sent',
        lastInvitedAt: now,
        inviteChannel: channel,
      });
    } catch {
      // The invitation was created; a missing pre-profile should not undo it.
    }
  }
  return { success, failed };
}

export async function saveManualPreProfileAndInvite(
  input: ManualInviteInput,
  createdBy: string,
): Promise<void> {
  const now = Timestamp.now();
  const name = input.contactName || input.companyName;
  if (input.phone) {
    await setDoc(
      doc(db, 'carrier_preprofiles', input.phone),
      {
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
        status: 'pending_invitation',
        importedAt: now,
      },
      { merge: true },
    );
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

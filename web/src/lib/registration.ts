import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import { companyToData, userToData } from '@/lib/firestore-user';
import type { AppUser, TransportCompany } from '@/lib/models';

export interface CarrierPreProfile {
  companyName: string;
  contactName: string;
  email: string;
  equipmentTypes: string[];
  coverageZones: string[];
  handlesLTL: boolean;
  handlesLocal: boolean;
}

const EMAIL_PATTERN = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;

export function isValidEmail(value: string): boolean {
  return EMAIL_PATTERN.test(value);
}

export type WhatsAppStatus = 'empty' | 'tooShort' | 'tooLong' | 'valid';

/** 10 Mexican digits, or 12 with country code 52. */
export function whatsappStatus(input: string): WhatsAppStatus {
  const digits = input.replace(/\D/g, '');
  if (!digits) return 'empty';
  const normalized = digits.startsWith('52') && digits.length === 12 ? digits.slice(2) : digits;
  if (normalized.length < 10) return 'tooShort';
  if (normalized.length > 10) return 'tooLong';
  return 'valid';
}

export function normalizeWhatsapp(input: string): string {
  const digits = input.replace(/\D/g, '');
  if (digits.startsWith('52') && digits.length === 12) return digits.slice(2);
  return digits;
}

/** Public get of carrier_preprofiles/{phone}. Returns null when missing or unreachable. */
export async function lookupCarrierPreProfile(phone: string): Promise<CarrierPreProfile | null> {
  const digits = phone.replace(/\D/g, '');
  if (digits.length !== 10) return null;
  try {
    const snap = await getDoc(doc(db, 'carrier_preprofiles', digits));
    if (!snap.exists()) return null;
    const data = snap.data();
    return {
      companyName: typeof data.companyName === 'string' ? data.companyName : '',
      contactName: typeof data.contactName === 'string' ? data.contactName : '',
      email: typeof data.email === 'string' ? data.email : '',
      equipmentTypes: Array.isArray(data.equipmentTypes)
        ? data.equipmentTypes.filter((item): item is string => typeof item === 'string')
        : [],
      coverageZones: Array.isArray(data.coverageZones)
        ? data.coverageZones.filter((item): item is string => typeof item === 'string')
        : [],
      handlesLTL: Boolean(data.handlesLTL),
      handlesLocal: Boolean(data.handlesLocal),
    };
  } catch {
    return null;
  }
}

/**
 * Same callable as iOS: sends the invitation template and reports whether the
 * number is on WhatsApp. null means a transient error — the caller still adds it.
 */
export async function checkWhatsApp(phone: string): Promise<boolean | null> {
  try {
    const response = await fetch(
      'https://us-central1-continente-conecta.cloudfunctions.net/checkWhatsApp',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: { phone } }),
      },
    );
    if (!response.ok) return null;
    const json = (await response.json()) as { result?: { hasWhatsApp?: unknown } };
    const has = json.result?.hasWhatsApp;
    return typeof has === 'boolean' ? has : null;
  } catch {
    return null;
  }
}

function functionErrorMessage(body: string): string {
  try {
    const json = JSON.parse(body) as { error?: { message?: string } };
    if (json.error?.message) return json.error.message;
  } catch {
    /* body is not JSON */
  }
  return 'No se pudo guardar el registro. Intenta de nuevo.';
}

/**
 * Admin SDK write used when the profile would not pass client rules
 * (coverageStates is capped at 16). Matches iOS createUserProfile.
 */
export async function createUserProfileViaFunction(
  idToken: string,
  user: AppUser,
  company?: TransportCompany,
): Promise<void> {
  const data: Record<string, unknown> = { ...userToData(user) };
  delete data.createdAt;
  if (company) {
    const companyJson: Record<string, unknown> = { ...companyToData(company) };
    delete companyJson.createdAt;
    delete companyJson.status;
    data.company = companyJson;
  }
  const response = await fetch(
    'https://us-central1-continente-conecta.cloudfunctions.net/createUserProfile',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ data }),
    },
  );
  if (!response.ok) {
    throw new Error(functionErrorMessage(await response.text()));
  }
}

import {
  doc,
  getDoc,
  setDoc,
  Timestamp,
  type DocumentData,
} from 'firebase/firestore';
import { db } from '@/plugins/firebase';
import type {
  AppUser,
  CarrierRoute,
  EquipmentType,
  TransportCompany,
  UserRole,
  UserStatus,
} from '@/lib/models';
import { phoneDigits } from '@/lib/models';

function routeToData(r: CarrierRoute) {
  return {
    id: r.id,
    originState: r.originState,
    destinationState: r.destinationState,
    bidirectional: r.bidirectional,
    equipmentTypes: r.equipmentTypes,
  };
}

function parseRoute(d: DocumentData): CarrierRoute | null {
  if (typeof d.originState !== 'string' || typeof d.destinationState !== 'string') {
    return null;
  }
  return {
    id: typeof d.id === 'string' ? d.id : crypto.randomUUID(),
    originState: d.originState,
    destinationState: d.destinationState,
    bidirectional: Boolean(d.bidirectional ?? true),
    equipmentTypes: Array.isArray(d.equipmentTypes)
      ? (d.equipmentTypes as EquipmentType[])
      : [],
  };
}

export function userToData(user: AppUser): DocumentData {
  const data: DocumentData = {
    uuid: user.uuid,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role,
    status: user.status,
    canNegotiateRates: user.canNegotiateRates,
    handlesLTL: user.handlesLTL,
    createdAt: user.createdAt
      ? Timestamp.fromDate(user.createdAt)
      : Timestamp.now(),
    routes: user.routes.map(routeToData),
  };
  if (user.companyId) data.companyId = user.companyId;
  if (user.coverageStates.length) data.coverageStates = user.coverageStates;
  if (user.coverageZones.length) data.coverageZones = user.coverageZones;
  if (user.coverageEquipmentTypes.length) {
    data.coverageEquipmentTypes = user.coverageEquipmentTypes;
  }
  const digits = phoneDigits(user.phone);
  if (digits.length >= 10 && digits.length <= 15) {
    data.phoneDigits = digits;
  }
  return data;
}

export function parseUser(data: DocumentData): AppUser | null {
  if (
    typeof data.name !== 'string' ||
    typeof data.email !== 'string' ||
    typeof data.phone !== 'string' ||
    typeof data.role !== 'string' ||
    typeof data.status !== 'string'
  ) {
    return null;
  }
  return {
    uuid: typeof data.uuid === 'string' ? data.uuid : crypto.randomUUID(),
    name: data.name,
    email: data.email,
    phone: data.phone,
    phoneDigits: typeof data.phoneDigits === 'string' ? data.phoneDigits : undefined,
    role: data.role as UserRole,
    status: data.status as UserStatus,
    companyId: typeof data.companyId === 'string' ? data.companyId : undefined,
    canNegotiateRates: Boolean(data.canNegotiateRates ?? true),
    handlesLTL: Boolean(data.handlesLTL ?? false),
    routes: Array.isArray(data.routes)
      ? data.routes.map(parseRoute).filter((r): r is CarrierRoute => r != null)
      : [],
    coverageStates: Array.isArray(data.coverageStates)
      ? (data.coverageStates as string[])
      : [],
    coverageZones: Array.isArray(data.coverageZones)
      ? (data.coverageZones as string[])
      : [],
    coverageEquipmentTypes: Array.isArray(data.coverageEquipmentTypes)
      ? (data.coverageEquipmentTypes as EquipmentType[])
      : [],
  };
}

export function companyToData(company: TransportCompany): DocumentData {
  return {
    id: company.id,
    name: company.name,
    contactName: company.contactName,
    phone: company.phone,
    email: company.email,
    rfc: company.rfc,
    status: company.status,
    createdAt: Timestamp.fromDate(company.createdAt),
  };
}

export async function fetchUserProfile(uid: string): Promise<AppUser | null> {
  const snap = await getDoc(doc(db, 'users', uid));
  if (!snap.exists()) return null;
  return parseUser(snap.data());
}

export async function writeUserProfile(uid: string, user: AppUser): Promise<void> {
  await setDoc(doc(db, 'users', uid), userToData(user));
}

export async function writeCompany(company: TransportCompany): Promise<void> {
  await setDoc(doc(db, 'companies', company.id), companyToData(company));
}

export async function writePhoneIndex(user: AppUser): Promise<void> {
  const digits = phoneDigits(user.phone);
  if (digits.length < 10 || digits.length > 15) return;
  await setDoc(doc(db, 'users_by_phone', digits), {
    phoneDigits: digits,
    uuid: user.uuid,
    name: user.name,
    role: user.role,
    status: user.status,
  });
}

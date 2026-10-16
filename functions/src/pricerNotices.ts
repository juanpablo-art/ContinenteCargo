import { createHash } from "crypto";

/** Title shown in Avisos on web and iOS when a load is first published. */
export const PRICER_PUBLISHED_TITLE = "Se publicó una carga";

const CANONICAL_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface PricerCandidate {
  uuid?: unknown;
  role?: unknown;
  status?: unknown;
}

export interface PricerNotice {
  /** Firestore document id. Same as `id` so mark-as-read hits this document. */
  docId: string;
  id: string;
  userId: string;
  type: "new_load";
  title: string;
  body: string;
  loadId: string;
  isRead: false;
}

export function isCanonicalUuid(value: string): boolean {
  return CANONICAL_UUID.test(value);
}

/**
 * Load id the apps use to open the load. Prefer the stored `id` field when
 * it is a UUID; otherwise the Firestore document id from the trigger.
 */
export function resolvePublishedLoadId(storedId: unknown, eventLoadId: string): string {
  if (typeof storedId === "string" && isCanonicalUuid(storedId.trim())) {
    return storedId.trim();
  }
  return eventLoadId;
}

/**
 * UUID version 5 derived from the load and the pricer. Stable across retries,
 * and a real UUID so iOS `UUID(uuidString:)` and the notification rules accept it.
 * The document id must equal this value: both clients update `notifications/{id}`.
 */
export function pricerNoticeId(loadId: string, pricerUuid: string): string {
  const hash = createHash("sha1").update(`nl:${loadId}:${pricerUuid}`).digest();
  const bytes = Buffer.from(hash.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join("-");
}

export function pricerPublishedBody(parts: {
  origin: string;
  destination: string;
  equipment: string;
  reference: string;
}): string {
  const route = `${parts.origin.trim()} → ${parts.destination.trim()}`.trim();
  const body = [route, parts.equipment.trim(), parts.reference.trim()]
    .filter((part) => part.length > 0 && part !== "→")
    .join(" · ")
    .slice(0, 500);
  return body || PRICER_PUBLISHED_TITLE;
}

/** Approved pricers only, one uuid each. Carriers and other roles are ignored. */
export function approvedPricerUuids(users: PricerCandidate[]): string[] {
  const seen = new Set<string>();
  const uuids: string[] = [];
  for (const user of users) {
    if (user.role !== "pricer" || user.status !== "approved") continue;
    if (typeof user.uuid !== "string") continue;
    const uuid = user.uuid.trim();
    if (!isCanonicalUuid(uuid) || seen.has(uuid)) continue;
    seen.add(uuid);
    uuids.push(uuid);
  }
  return uuids;
}

/**
 * One in-app notice per approved pricer. Empty when the load turns in-app off,
 * or when the load id is not a UUID the apps can open.
 */
export function pricerPublishedNotices(args: {
  inApp: boolean | undefined;
  loadId: string;
  origin: string;
  destination: string;
  equipment: string;
  reference: string;
  users: PricerCandidate[];
}): PricerNotice[] {
  if (args.inApp === false) return [];
  if (!isCanonicalUuid(args.loadId)) return [];
  const body = pricerPublishedBody(args);
  return approvedPricerUuids(args.users).map((userId) => {
    const id = pricerNoticeId(args.loadId, userId);
    return {
      docId: id,
      id,
      userId,
      type: "new_load",
      title: PRICER_PUBLISHED_TITLE,
      body,
      loadId: args.loadId,
      isRead: false,
    };
  });
}

export function isAlreadyExistsError(err: unknown): boolean {
  const code = (err as { code?: number | string } | null)?.code;
  const message = err instanceof Error ? err.message : String(err ?? "");
  return (
    code === 6 ||
    code === "already-exists" ||
    code === "ALREADY_EXISTS" ||
    message.includes("ALREADY_EXISTS") ||
    message.includes("already exists")
  );
}

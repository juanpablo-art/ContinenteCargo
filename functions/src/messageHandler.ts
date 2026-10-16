import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import { LoadRecord } from "./types";
import {
  CarrierInfo,
  detectIntentAsync,
  lookupCarrierByPhone,
  getConversation,
  upsertConversation,
  clearConversationLoad,
  resolveLoadId,
  logDecline,
  extractCounterPrice,
  pushMessageToHistory,
  analyzeConversationWithAI,
} from "./conversations";
import { WaHistoryMessage } from "./types";
import { sendWhatsAppText } from "./whatsapp";
import { formatPrice } from "./carriers";
import {
  LoadContext,
  UnitContext,
  aiUnknownCarrier,
  aiLoadAvailable,
  aiLoadUnavailable,
  aiShowSummary,
  aiAssignmentSuccess,
  aiAssignmentFailed,
  aiDeclineAck,
  aiNoLoadContext,
  aiUnknownWithLoad,
} from "./aiResponse";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface IncomingMsg {
  id: string;
  from: string;
  type: string;
  timestamp: string;
  text?: { body: string };
  context?: { id: string };  // wamid of the message this is a reply to
  interactive?: {
    type: "button_reply" | "list_reply";
    button_reply?: { id: string; title: string };
    list_reply?: { id: string; title: string };
  };
}

export interface WaBotContext {
  phoneNumberId: string;
  accessToken: string;
}

interface UnitInfo {
  id: string;
  plates: string;
  trailerNumber: string;
}

type AssignSuccess = { tag: "success"; unitsAssigned: number; isFull: boolean };
type AssignInsufficient = { tag: "insufficient"; available: number };
type AssignResult =
  | AssignSuccess
  | AssignInsufficient
  | "already_assigned"
  | "deadline_passed"
  | "mode_unsupported"
  | "error";

// ─── Deduplication ────────────────────────────────────────────────────────────

const DEDUPE = "wa_processed_messages";

async function markProcessed(wamid: string): Promise<boolean> {
  const db  = admin.firestore();
  const ref = db.collection(DEDUPE).doc(wamid);
  let alreadyDone = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      alreadyDone = true;
      return;
    }
    tx.set(ref, { wamid, processedAt: admin.firestore.Timestamp.now() });
  });
  return alreadyDone;
}

// ─── Unit availability check ─────────────────────────────────────────────────

/**
 * Finds the first available unit owned by the carrier that matches the load's
 * equipment type. Units are stored in Firestore with camelCase field names
 * matching the Swift Unit struct.
 */
async function findAvailableUnit(
  carrierUuid: string,
  equipmentType: string
): Promise<UnitInfo | null> {
  const snap = await admin.firestore()
    .collection("units")
    .where("ownerId", "==", carrierUuid)
    .where("status", "==", "Disponible")
    .where("equipmentType", "==", equipmentType)
    .limit(1)
    .get();

  if (snap.empty) return null;

  const d = snap.docs[0].data();
  return {
    id:            snap.docs[0].id,
    plates:        (d["plates"]        as string) || "—",
    trailerNumber: (d["trailerNumber"] as string) || "—",
  };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Capitalizes each word of the name (handles lowercase names stored in DB). */
function capitalizeName(name: string): string {
  return name.replace(/\b\w/g, (c) => c.toUpperCase());
}

// ─── Date formatting helpers ──────────────────────────────────────────────────

function formatPickupDate(ts: admin.firestore.Timestamp | undefined): string {
  if (!ts) return "—";
  const d = ts.toDate();
  const day   = d.toLocaleDateString("es-MX", { day: "2-digit", month: "2-digit", year: "numeric" });
  const hour  = d.getHours();
  const min   = d.getMinutes();
  const hhmm  = min === 0
    ? `${hour === 12 ? 12 : hour % 12} ${hour < 12 ? "am" : "pm"}`
    : `${hour === 12 ? 12 : hour % 12}:${String(min).padStart(2, "0")} ${hour < 12 ? "am" : "pm"}`;
  return `${day} a las ${hhmm}`;
}

// ─── Context builders ─────────────────────────────────────────────────────────

function fmtPlace(city: string | undefined, state: string): string {
  const c = city?.trim();
  if (!c) return state;
  const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "");
  return norm(c) === norm(state) ? state : `${c}, ${state}`;
}

function loadCtx(load: LoadRecord): LoadContext {
  const deadline = (load.deadline as admin.firestore.Timestamp | undefined)?.toDate();
  const dlStr = deadline
    ? deadline.toLocaleDateString("es-MX", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })
    : undefined;
  const pickupStr = formatPickupDate(load.pickupDate as admin.firestore.Timestamp | undefined);
  return {
    folio:       load.reference,
    ruta:        `${fmtPlace(load.originCity, load.originState)} → ${fmtPlace(load.destinationCity, load.destinationState)}`,
    tarifa:      `$${formatPrice(load.offeredPrice)} ${load.currency}`,
    equipo:      load.equipmentType,
    recoleccion: pickupStr !== "—" ? pickupStr : undefined,
    cierre:      dlStr,
    status:      load.status,
  };
}

function unitCtx(unit: UnitInfo): UnitContext {
  return { placas: unit.plates, caja: unit.trailerNumber || undefined };
}

/** Parses a unit count from free text. "all" means the caller should use the slots still free. */
export function mentionedUnitCount(text: string): number | "all" | null {
  const n = text.trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  if (/\b(todas?|todos?|todas las unidades?)\b/.test(n)) return "all";
  const wordMap: Record<string, number> = {
    una: 1, uno: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5,
    seis: 6, siete: 7, ocho: 8, nueve: 9, diez: 10,
  };
  for (const [word, val] of Object.entries(wordMap)) {
    if (n === word || n.includes(` ${word} `) || n.startsWith(`${word} `) || n.endsWith(` ${word}`)) {
      return val;
    }
  }
  const match = text.match(/\b(\d+)\b/);
  if (!match) return null;
  const value = parseInt(match[1], 10);
  return value >= 1 && value <= 40 ? value : null;
}

/**
 * Accepts a request only when it fits the free slots.
 * A larger request is refused; it is never trimmed down to the remainder.
 */
export function decideUnitTake(
  requested: number,
  available: number,
): { ok: true; units: number } | { ok: false; available: number; full: boolean } {
  const free = Math.max(0, Math.floor(available));
  if (free <= 0) return { ok: false, available: 0, full: true };
  if (!Number.isInteger(requested) || requested < 1 || requested > free) {
    return { ok: false, available: free, full: false };
  }
  return { ok: true, units: requested };
}

async function carrierOffersLtl(uuid: string): Promise<boolean> {
  const snap = await admin.firestore()
    .collection("users")
    .where("uuid", "==", uuid)
    .limit(1)
    .get();
  if (snap.empty) return false;
  return snap.docs[0].get("handlesLTL") === true;
}

async function refuseLtlLoad(
  from: string,
  carrier: CarrierInfo,
  load: LoadRecord,
  send: (body: string) => Promise<unknown>,
): Promise<boolean> {
  if (load.assignmentMode !== "Consolidada LTL") return false;
  if (await carrierOffersLtl(carrier.uuid)) return false;
  await clearConversationLoad(from);
  await send(
    `El viaje *${load.reference}* es carga consolidada (LTL). Tu registro no incluye ese servicio, así que no puedo ofrecértelo.`
  );
  return true;
}

export function unitSlots(load: LoadRecord): { total: number; confirmed: number; available: number } {
  const total = Math.max(1, load.unitCount ?? 1);
  const confirmed = typeof load.confirmedUnitCount === "number"
    ? Math.max(0, load.confirmedUnitCount)
    : 0;
  return { total, confirmed, available: Math.max(0, total - confirmed) };
}

/** What WhatsApp may offer right now. Never the original total once some units are taken. */
function unitOffer(
  load: LoadRecord,
  unit: UnitInfo | null,
  carrierName?: string,
): {
  text: string;
  state: "unavailable" | "awaiting_unit_count" | "awaiting_confirmation";
  pendingUnitCount: number | null;
} {
  const { total, available } = unitSlots(load);
  if (available <= 0) {
    return {
      text: `❌ El viaje *${load.reference}* ya no tiene unidades disponibles.`,
      state: "unavailable",
      pendingUnitCount: null,
    };
  }
  if (total > 1 && available === 1) {
    return {
      text: `Solo queda *1* unidad de *${total}* en el viaje *${load.reference}*. ¿La tomas? Responde *Sí* o *No*.`,
      state: "awaiting_confirmation",
      pendingUnitCount: 1,
    };
  }
  return {
    text: fallbackSummary(load, unit, carrierName),
    state: total > 1 ? "awaiting_unit_count" : "awaiting_confirmation",
    pendingUnitCount: total > 1 ? null : 1,
  };
}

// Fallback summary (used if AI fails). Unit is optional — shown only if available.
function fallbackSummary(load: LoadRecord, unit: UnitInfo | null, carrierName?: string): string {
  const lc = loadCtx(load);
  const { total, confirmed, available } = unitSlots(load);
  const isMulti = total > 1;
  const firstName = carrierName?.split(/\s+/)[0];
  const intro = firstName
    ? `Perfecto, ${firstName}. Te paso los detalles del viaje:`
    : "Te paso los detalles del viaje:";

  const lines = [
    intro,
    "",
    `📦 Folio: *${lc.folio}*`,
    `🚚 Ruta: *${lc.ruta}*`,
    isMulti
      ? `💰 Tarifa: *${lc.tarifa} por unidad*`
      : `💰 Tarifa: *${lc.tarifa}*`,
    `🔧 Equipo: ${lc.equipo}`,
    isMulti
      ? `📦 Unidades disponibles: *${available}* de ${total}` +
        (confirmed > 0 ? ` (ya se tomaron ${confirmed})` : "")
      : "",
    lc.recoleccion ? `📅 Recolección: ${lc.recoleccion}` : "",
    lc.cierre ? `⏰ Cierre de oferta: ${lc.cierre}` : "",
  ];
  if (unit && !isMulti) {
    const uc = unitCtx(unit);
    lines.push("", `🚛 Unidad asignada: *${uc.placas}*${uc.caja ? ` / Caja: ${uc.caja}` : ""}`);
  }
  if (isMulti) {
    lines.push("", `¿Cuántas unidades puedes tomar? (1 a ${available})`);
  } else {
    lines.push("", `¿Le entramos? Responde *Sí* para confirmar o *No* para declinar.`);
  }
  return lines.filter(Boolean).join("\n");
}

// Summary shown after the carrier specifies how many units they want.
function fallbackUnitConfirmSummary(load: LoadRecord, requestedUnits: number, carrierName?: string): string {
  const lc = loadCtx(load);
  const firstName = carrierName?.split(/\s+/)[0];
  const totalPrice = formatPrice(load.offeredPrice * requestedUnits);
  const intro = firstName
    ? `Perfecto, ${firstName}. Confirmando *${requestedUnits} unidad${requestedUnits > 1 ? "es" : ""}*:`
    : `Confirmando *${requestedUnits} unidad${requestedUnits > 1 ? "es" : ""}*:`;

  return [
    intro,
    "",
    `📦 Folio: *${lc.folio}*`,
    `🚚 Ruta: *${lc.ruta}*`,
    `💰 ${requestedUnits} × ${lc.tarifa} = *$${totalPrice} ${load.currency}*`,
    `🔧 Equipo: ${lc.equipo}`,
    lc.recoleccion ? `📅 Recolección: ${lc.recoleccion}` : "",
    "",
    `¿Le entramos? Responde *Sí* para confirmar o *No* para declinar.`,
  ].filter(Boolean).join("\n");
}

// ─── Atomic assignment ────────────────────────────────────────────────────────

async function atomicAssign(
  loadId: string,
  carrier: CarrierInfo,
  load: LoadRecord,
  unitId: string | null,        // null = no unit pre-matched; carrier will set it in-app
  incomingWamid: string,
  requestedUnitCount: number = 1,
  priceOverride?: number        // negotiated price (sin IVA); overrides offeredPrice when set
): Promise<AssignResult> {
  // WA assignment only works for fixed-rate loads
  const mode = load.assignmentMode ?? "";
  if (mode === "Consolidada LTL" && !(await carrierOffersLtl(carrier.uuid))) {
    return "mode_unsupported";
  }
  if (!["fixedRate", "Tarifa Fija"].includes(mode)) {
    return "mode_unsupported";
  }

  const db    = admin.firestore();
  const now   = new Date();
  const listedSinIVA = load.includesVAT
    ? Math.round((load.offeredPrice / 1.16) * 100) / 100
    : load.offeredPrice;
  const tarifa = priceOverride ?? listedSinIVA;

  const claveIdemp = `wa:${loadId}:${carrier.uuid}:${incomingWamid}`;
  const idempRef   = db.collection("ai_assignments").doc(claveIdemp);
  const loadRef    = db.collection("loads").doc(loadId);
  const unitRef    = unitId ? db.collection("units").doc(unitId) : null;

  try {
    const result = await db.runTransaction(async (tx) => {
      const reads: Promise<admin.firestore.DocumentSnapshot>[] = [
        tx.get(idempRef),
        tx.get(loadRef),
      ];
      if (unitRef) reads.push(tx.get(unitRef));

      const [idempSnap, loadSnap, unitSnap] = await Promise.all(reads);

      if (idempSnap.exists) return { tag: "success", unitsAssigned: requestedUnitCount, isFull: true } as AssignSuccess; // idempotent replay
      if (!loadSnap.exists) return "error";

      const data = loadSnap.data() as LoadRecord;
      if (data.status !== "Publicado")   return "already_assigned";
      // For single-unit loads, block if already has a carrier
      if ((data.unitCount ?? 1) <= 1 && data.assignedCarrierId) return "already_assigned";

      const deadline = (data.deadline as admin.firestore.Timestamp | undefined)?.toDate();
      if (!deadline || deadline <= now)  return "deadline_passed";

      // Respect maxAuthorizedPriceSinIVA if set
      const maxSinIVA = data.maxAuthorizedPriceSinIVA;
      if (typeof maxSinIVA === "number" && tarifa - maxSinIVA > 0.01) {
        return "mode_unsupported";
      }

      // For multi-unit loads: only the units still free can be taken.
      const totalUnits    = data.unitCount ?? 1;
      const confirmedSoFar = typeof data.confirmedUnitCount === "number" ? data.confirmedUnitCount : 0;
      const availableSlots = totalUnits - confirmedSoFar;
      const decision = decideUnitTake(requestedUnitCount, availableSlots);
      if (!decision.ok) {
        if (decision.full) return "already_assigned";
        return { tag: "insufficient", available: decision.available } as AssignInsufficient;
      }
      const unitsToAssign = decision.units;
      const newConfirmed  = confirmedSoFar + unitsToAssign;
      const isFull        = newConfirmed >= totalUnits;

      // If a specific unit was matched, verify it is still available
      const unitData = unitSnap?.exists ? unitSnap.data()! : null;
      if (unitRef && unitSnap && !unitSnap.exists) return "error";
      if (unitData && unitData["status"] !== "Disponible") return "error";

      const unitPlates = unitData?.["plates"] ?? null;
      const unitNote = unitPlates ? ` Unidad: ${unitPlates}.` : "";
      const unitCountNote = unitsToAssign > 1 ? ` Unidades: ${unitsToAssign}.` : "";
      const histStatus = isFull ? "Asignado" : "Publicado";
      const histEntry = {
        id:            randomUUID(),
        status:        histStatus,
        changedBy:     carrier.uuid,
        changedByName: `${carrier.name} (WhatsApp)`,
        changedAt:     admin.firestore.Timestamp.now(),
        notes:         `${isFull ? "Asignación completa" : `Asignación parcial (${newConfirmed}/${totalUnits} unidades)`} vía WhatsApp.${unitNote}${unitCountNote} Clave: ${claveIdemp}`,
      };

      // Update load
      const loadUpdate: Record<string, unknown> = {
        confirmedUnitCount:  newConfirmed,
        assignedPriceSinIVA: tarifa,
        assignedVia:         "whatsapp",
        statusHistory:       admin.firestore.FieldValue.arrayUnion(histEntry),
      };
      if (isFull) {
        loadUpdate["status"]            = "Asignado";
        loadUpdate["assignedCarrierId"] = carrier.uuid;
      }
      if (unitId) loadUpdate["assignedUnitId"] = unitId;
      tx.update(loadRef, loadUpdate);

      // Reserve unit only if one was matched
      if (unitRef && unitSnap?.exists) {
        tx.update(unitRef, { status: "Reservada" });
      }

      // Offer record for audit trail
      const offerId = randomUUID();
      tx.set(db.collection("offers").doc(offerId), {
        id:                 offerId,
        loadId,
        carrierId:          carrier.uuid,
        carrierName:        carrier.name,
        amount:             tarifa,
        currency:           data.currency,
        isAvailabilityOnly: false,
        status:             "Ganadora",
        submittedAt:        admin.firestore.Timestamp.now(),
        notes:              unitPlates
          ? `WhatsApp. Ref: ${data.reference}. Unidad: ${unitPlates}`
          : `WhatsApp. Ref: ${data.reference}. Sin unidad.`,
        availableUnitCount: unitsToAssign,
      });

      // Idempotency record
      tx.set(idempRef, {
        idViaje:         loadId,
        idTransportista: carrier.uuid,
        unitId:          unitId ?? null,
        unitCount:       unitsToAssign,
        tarifa,
        moneda:          data.currency,
        asignado:        true,
        referencia:      data.reference,
        assignedAt:      admin.firestore.Timestamp.now(),
        via:             "whatsapp",
      });

      return { tag: "success", unitsAssigned: unitsToAssign, isFull } as AssignSuccess;
    });

    return result as AssignResult;
  } catch (e) {
    console.error("[WA-Assign] Transaction error:", e);
    return "error";
  }
}

// ─── Main message handler ─────────────────────────────────────────────────────

export async function handleIncomingMessage(
  msg: IncomingMsg,
  ctx: WaBotContext
): Promise<void> {
  const from  = msg.from;
  // Button replies (interactive) carry no text.body — use the button title instead
  const text  = msg.text?.body
    ?? msg.interactive?.button_reply?.title
    ?? msg.interactive?.list_reply?.title
    ?? "";
  const wamid = msg.id;

  // Wrap send so every outgoing message is appended to conversation history
  const send = async (body: string): Promise<void> => {
    await sendWhatsAppText(ctx.phoneNumberId, ctx.accessToken, `+${from}`, body);
    pushMessageToHistory(from, "assistant", body).catch(() => {});
  };

  if (await markProcessed(wamid)) {
    console.log(`[WA-Bot] Skipping duplicate wamid=${wamid}`);
    return;
  }

  // Record the carrier's incoming message (fire-and-forget — non-critical)
  if (text) pushMessageToHistory(from, "user", text).catch(() => {});

  const carrier = await lookupCarrierByPhone(from);
  if (!carrier) {
    await send(await aiUnknownCarrier(
      "Hola, no encontré tu número en nuestra plataforma. " +
      "Descarga la app *Continente Conecta* para registrarte."
    ));
    return;
  }

  // Use capitalized display name in all user-facing messages
  const displayName = capitalizeName(carrier.name);

  const conversation = await getConversation(from);
  let intent         = await detectIntentAsync(text);
  const repliedTo    = msg.context?.id;
  let loadId         = await resolveLoadId(repliedTo, conversation, text, carrier.uuid);

  const db = admin.firestore();

  // ── AI-enhanced analysis for ambiguous messages ────────────────────────────
  // Only invoke when pattern matching fails AND there is conversation context to
  // reason from (history, pending load, or a mid-flow state).
  let aiSuggestedResponse: string | null = null;
  if (intent === "unknown") {
    const history = (conversation?.messageHistory ?? []) as WaHistoryMessage[];
    const hasContext =
      history.length > 0 ||
      !!conversation?.pendingLoadId ||
      (conversation?.state != null && conversation.state !== "idle");
    if (hasContext) {
      const analysis = await analyzeConversationWithAI(history, text, carrier.name);
      if (analysis.intent !== "unknown") {
        intent = analysis.intent;
        console.log(`[WA-Bot] AI upgraded intent="${intent}" (ref=${analysis.loadRef ?? "none"})`);
      }
      // If AI identified a folio that resolveLoadId missed, look it up
      if (!loadId && analysis.loadRef) {
        const refSnap = await db.collection("loads")
          .where("reference", "==", analysis.loadRef)
          .limit(1)
          .get();
        if (!refSnap.empty) {
          loadId = refSnap.docs[0].id;
          console.log(`[WA-Bot] AI resolved loadRef "${analysis.loadRef}" → ${loadId}`);
        }
      }
      aiSuggestedResponse = analysis.suggestedResponse;
    }
  }

  // Only escalate "Sí" when the user is NOT replying to a NEW load notification.
  // If they pressed "Sí" on a notification for a different load (loadId ≠ pendingLoadId),
  // that is new interest — not confirmation of the previous pending load.
  const isReplyToNewLoad =
    loadId !== null &&
    conversation?.pendingLoadId != null &&
    loadId !== conversation.pendingLoadId;

  if (!isReplyToNewLoad) {
    // If the carrier is already in awaiting_confirmation and sends any affirmative,
    // treat it as explicit confirmation — not as new interest.
    if (intent === "confirm_interest" && conversation?.state === "awaiting_confirmation") {
      intent = "explicit_confirm";
    }
    // If the carrier is awaiting_unit_count and sends an affirmative ("sí" / "todas"),
    // treat it as "take all units".
    if (intent === "confirm_interest" && conversation?.state === "awaiting_unit_count") {
      intent = "take_all_units" as typeof intent;
    }
  }

  console.log(
    `[WA-Bot] from=${from} carrier="${carrier.name}" intent=${intent} ` +
    `loadId=${loadId ?? "none"} conversationState=${conversation?.state ?? "none"} ` +
    `pendingRef=${conversation?.pendingLoadRef ?? "none"}`
  );

  // ── Explicit confirmation ─────────────────────────────────────────────────────
  if (intent === "explicit_confirm") {
    const activeLoadId = conversation?.state === "awaiting_confirmation"
      ? (conversation.pendingLoadId ?? loadId)
      : null;
    let activeUnitId = conversation?.pendingUnitId ?? null;

    // No active load — no context to confirm
    if (!activeLoadId) {
      if (!loadId) {
        await send(await aiNoLoadContext(
          carrier.name,
          "Responde al aviso de la carga que te interesa o indica el folio."
        ));
        return;
      }
      // Has a load but not in awaiting_confirmation — show summary first
      const loadSnap2 = await db.collection("loads").doc(loadId).get();
      if (!loadSnap2.exists) { await send("No encontré ese viaje en el sistema."); return; }
      const load2 = loadSnap2.data() as LoadRecord;
      const deadline2 = (load2.deadline as admin.firestore.Timestamp | undefined)?.toDate();
      const isOpen2 = load2.status === "Publicado" && deadline2 != null && deadline2 > new Date();
      if (!isOpen2) {
        await clearConversationLoad(from);
        await send(await aiLoadUnavailable(carrier.name, loadCtx(load2), load2.status,
          `❌ El viaje *${load2.reference}* ya no está disponible (${load2.status}).`
        ));
        return;
      }
      if (await refuseLtlLoad(from, carrier, load2, send)) return;
      const unit2 = await findAvailableUnit(carrier.uuid, load2.equipmentType);
      const offer2 = unitOffer(load2, unit2, displayName);
      if (offer2.state === "unavailable") {
        await clearConversationLoad(from);
        await send(offer2.text);
        return;
      }
      await send(await aiShowSummary(carrier.name, loadCtx(load2), unit2 ? unitCtx(unit2) : null, offer2.text));
      await upsertConversation(from, {
        pendingLoadId: loadId,
        pendingUnitId: unit2?.id ?? null,
        pendingUnitCount: offer2.pendingUnitCount,
        state: offer2.state,
      });
      return;
    }

    // Try to resolve a unit (best-effort; assignment proceeds even without one)
    if (!activeUnitId) {
      const loadForUnit = await db.collection("loads").doc(activeLoadId).get();
      if (loadForUnit.exists) {
        const unitFound = await findAvailableUnit(
          carrier.uuid,
          (loadForUnit.data() as LoadRecord).equipmentType
        );
        if (unitFound) {
          activeUnitId = unitFound.id;
          await upsertConversation(from, { pendingUnitId: activeUnitId });
        }
        // No unit found → proceed anyway; carrier completes it in the app
      }
    }

    const loadSnap = await db.collection("loads").doc(activeLoadId).get();
    if (!loadSnap.exists) {
      await clearConversationLoad(from);
      await send("No encontré ese viaje. Por favor intenta nuevamente.");
      return;
    }
    const load = loadSnap.data() as LoadRecord;
    if (await refuseLtlLoad(from, carrier, load, send)) return;
    const lc = loadCtx(load);

    const confirmedUnitCount = conversation?.pendingUnitCount ?? 1;
    const priceOverride = conversation?.pendingCounterPrice ?? undefined;
    const result = await atomicAssign(activeLoadId, carrier, load, activeUnitId, wamid, confirmedUnitCount, priceOverride);

    if (typeof result === "object" && result.tag === "insufficient") {
      const { total } = unitSlots(load);
      if (result.available <= 0) {
        await clearConversationLoad(from);
        await send(`❌ El viaje *${load.reference}* ya no tiene unidades disponibles.`);
      } else {
        await upsertConversation(from, {
          pendingLoadId: activeLoadId,
          pendingUnitCount: null,
          state: "awaiting_unit_count",
        });
        await send(
          `Solo quedan *${result.available}* de *${total}* unidades en *${load.reference}*. ` +
          `No puedo apartar más que eso. Responde con un número del *1* al *${result.available}*.`
        );
      }
      return;
    }

    await clearConversationLoad(from);

    const isSuccess = typeof result === "object" && result.tag === "success";
    if (isSuccess) {
      const res = result as AssignSuccess;
      const pickupStr  = formatPickupDate(load.pickupDate as admin.firestore.Timestamp | undefined);
      const pickupLine = pickupStr !== "—" ? `\n📅 Recolección: ${pickupStr}` : "";
      const firstName  = displayName.split(/\s+/)[0];
      const isMulti    = res.unitsAssigned > 1;
      const confirmedPriceSinIVA = priceOverride ?? (load.includesVAT
        ? Math.round((load.offeredPrice / 1.16) * 100) / 100
        : load.offeredPrice);
      const confirmedPriceStr = `$${formatPrice(confirmedPriceSinIVA)} ${load.currency}`;
      const tarifaLine = isMulti
        ? `💰 ${res.unitsAssigned} unidades × ${confirmedPriceStr} = *$${formatPrice(confirmedPriceSinIVA * res.unitsAssigned)} ${load.currency}*`
        : `💰 Tarifa: *${confirmedPriceStr}*`;
      const totalUnitsOnLoad = load.unitCount ?? 1;
      const unitsLine = totalUnitsOnLoad > 1
        ? `\n📦 Unidades confirmadas: *${res.unitsAssigned}* de *${totalUnitsOnLoad}*`
        : "";
      const partialNote = (!res.isFull && totalUnitsOnLoad > 1)
        ? `\n\n⚠️ Carga parcial — quedan unidades disponibles.`
        : "";
      await send(await aiAssignmentSuccess(
        carrier.name, lc, pickupStr !== "—" ? pickupStr : "",
        `✅ *¡Listo, ${firstName}! Quedaste asignado.*\n\n` +
        `📦 Folio: *${load.reference}*\n` +
        `🚚 Ruta: *${lc.ruta}*\n` +
        `${tarifaLine}${unitsLine}${pickupLine}${partialNote}\n\n` +
        `Recibirás la carta porte e instrucciones en la app *Continente Conecta*.`
      ));
    } else switch (result) {
      case "already_assigned":
        await send(await aiAssignmentFailed(carrier.name, lc, "already_assigned",
          `❌ El viaje *${load.reference}* ya fue tomado. Te avisamos cuando haya nuevas cargas.`
        ));
        break;
      case "deadline_passed":
        await send(await aiAssignmentFailed(carrier.name, lc, "deadline_passed",
          `❌ El plazo del viaje *${load.reference}* ya venció. Te avisamos de nuevas cargas.`
        ));
        break;
      case "mode_unsupported":
        await send(await aiAssignmentFailed(carrier.name, lc, "mode_unsupported",
          `Este viaje requiere confirmación desde la app *Continente Conecta*.`
        ));
        break;
      default:
        await send(await aiAssignmentFailed(carrier.name, lc, "error",
          `Ocurrió un error. Por favor confirma desde la app *Continente Conecta*.`
        ));
    }
    return;
  }

  // ── Awaiting unit count (multi-unit load) ────────────────────────────────────
  // Skip this block if the carrier replied to a *different* load notification —
  // that is new interest, not an answer to the unit-count question.
  if (conversation?.state === "awaiting_unit_count" && conversation.pendingLoadId && !isReplyToNewLoad) {
    const pendingLoadSnap = await db.collection("loads").doc(conversation.pendingLoadId).get();
    if (!pendingLoadSnap.exists) { await clearConversationLoad(from); return; }
    const pendingLoad  = pendingLoadSnap.data() as LoadRecord;
    if (await refuseLtlLoad(from, carrier, pendingLoad, send)) return;
    const { total, confirmed, available } = unitSlots(pendingLoad);
    if (available <= 0) {
      await clearConversationLoad(from);
      await send(`❌ El viaje *${pendingLoad.reference}* ya no tiene unidades disponibles.`);
      return;
    }

    // Decline
    if (intent === "decline") {
      await logDecline(carrier.uuid, conversation.pendingLoadId, pendingLoad.reference, text);
      await clearConversationLoad(from);
      const fn = displayName.split(/\s+/)[0];
      await send(await aiDeclineAck(carrier.name, pendingLoad.reference,
        `Ok, ${fn}, sin problema. Te avisamos en cuanto salga algo más. 👍`
      ));
      return;
    }

    // "sí" / "todas" → take every unit that is still free, never the original total.
    const takeAll = (intent as string) === "take_all_units";
    const mentioned = takeAll ? "all" : mentionedUnitCount(text);
    if (mentioned == null) {
      await send(
        `¿Cuántas unidades puedes tomar? Responde con un número del *1* al *${available}*.`
      );
      return;
    }
    const decision = decideUnitTake(mentioned === "all" ? available : mentioned, available);
    if (!decision.ok) {
      await send(
        `Esa carga es de *${total}* unidades y ya se tomaron *${confirmed}*. ` +
        `Solo quedan *${decision.available}*. Responde del *1* al *${decision.available}*.`
      );
      return;
    }

    await upsertConversation(from, { pendingUnitCount: decision.units, state: "awaiting_confirmation" });
    await send(fallbackUnitConfirmSummary(pendingLoad, decision.units, displayName));
    return;
  }

  // ── Remaining intents need a load ─────────────────────────────────────────────
  if (!loadId) {
    const firstName = displayName.split(/\s+/)[0];
    // Prefer AI-generated context-aware response when available
    await send(aiSuggestedResponse ?? await aiNoLoadContext(
      carrier.name,
      `Hola, ${firstName}. Para ayudarte necesito saber a qué carga te refieres. ` +
      `Responde directamente al aviso que recibiste o mándame el folio (ej. CC-202610-XXXXX).`
    ));
    return;
  }

  const loadSnap = await db.collection("loads").doc(loadId).get();
  if (!loadSnap.exists) {
    await send("No encontré ese viaje en el sistema.");
    return;
  }
  const load = loadSnap.data() as LoadRecord;
  if (await refuseLtlLoad(from, carrier, load, send)) return;

  await upsertConversation(from, {
    phone:          from,
    carrierUuid:    carrier.uuid,
    carrierName:    carrier.name,
    pendingLoadId:  loadId,
    pendingLoadRef: load.reference,
    pendingUnitId:  null,
    state:          "idle",
  });

  // ── Decline ───────────────────────────────────────────────────────────────────
  if (intent === "decline") {
    await logDecline(carrier.uuid, loadId, load.reference, text);
    await clearConversationLoad(from);
    const firstName = displayName.split(/\s+/)[0];
    await send(await aiDeclineAck(carrier.name, load.reference,
      `Ok, ${firstName}, sin problema. Te avisamos en cuanto salga algo más. 👍`
    ));
    return;
  }

  const deadline = (load.deadline as admin.firestore.Timestamp | undefined)?.toDate();
  const isOpen   = load.status === "Publicado" && deadline != null && deadline > new Date();

  // ── Price counter-offer ───────────────────────────────────────────────────────
  if (intent === "price_counter") {
    const lc5       = loadCtx(load);
    const offered   = extractCounterPrice(text);
    const isFixed   = ["fixedRate", "Tarifa Fija"].includes(load.assignmentMode ?? "");
    const firstName = displayName.split(/\s+/)[0];

    if (isFixed) {
      const listedSinIVA = load.includesVAT
        ? Math.round((load.offeredPrice / 1.16) * 100) / 100
        : load.offeredPrice;
      const maxSinIVA = typeof load.maxAuthorizedPriceSinIVA === "number"
        ? load.maxAuthorizedPriceSinIVA
        : null;

      // No price extracted — just remind them of the fixed rate
      if (!offered) {
        await send(`La tarifa de este viaje es fija en *${lc5.tarifa}*. ¿La aceptas? Responde *Sí* o *No*.`);
        return;
      }

      // Carrier's price ≤ listed → they accept the listed rate; show summary
      if (offered <= listedSinIVA) {
        const unit = await findAvailableUnit(carrier.uuid, load.equipmentType);
        const offer = unitOffer(load, unit, displayName);
        if (offer.state === "unavailable") {
          await clearConversationLoad(from);
          await send(offer.text);
          return;
        }
        await send(await aiShowSummary(carrier.name, lc5, unit ? unitCtx(unit) : null, offer.text));
        await upsertConversation(from, {
          pendingLoadId:       loadId,
          pendingUnitId:       unit?.id ?? null,
          pendingUnitCount:    offer.pendingUnitCount,
          pendingCounterPrice: null,
          state:               offer.state,
        });
        return;
      }

      // Carrier wants more than listed price
      if (maxSinIVA === null) {
        // No negotiation ceiling configured — redirect to app
        await send(
          `Entiendo, ${firstName}, pero este viaje tiene tarifa fija de *${lc5.tarifa}*. No hay margen de negociación por aquí.\n\n` +
          `Si quieres hacer una oferta, entra a la app *Continente Conecta* → *Hacer oferta*.`
        );
        return;
      }

      if (offered <= maxSinIVA) {
        // Within authorized range — counter at midpoint
        const mid = Math.round(((listedSinIVA + offered) / 2) / 500) * 500;
        const counterPrice = Math.max(listedSinIVA, Math.min(mid, maxSinIVA));
        const counterStr = `$${formatPrice(counterPrice)} ${load.currency}`;
        await upsertConversation(from, {
          pendingLoadId:       loadId,
          pendingUnitId:       null,
          pendingCounterPrice: counterPrice,
          state:               "awaiting_confirmation",
        });
        await send(
          `Entiendo, ${firstName}. La tarifa publicada es *${lc5.tarifa}*, pero te puedo ofrecer *${counterStr}* para cerrar el trato. ¿Le entramos? Responde *Sí* o *No*.`
        );
      } else {
        // Above max — offer the ceiling
        const maxStr = `$${formatPrice(maxSinIVA)} ${load.currency}`;
        await upsertConversation(from, {
          pendingLoadId:       loadId,
          pendingUnitId:       null,
          pendingCounterPrice: maxSinIVA,
          state:               "awaiting_confirmation",
        });
        await send(
          `Entiendo, ${firstName}, pero lo máximo que puedo autorizarte en este viaje es *${maxStr}*. ¿Te funciona? Responde *Sí* o *No*.`
        );
      }
    } else {
      // Bid-based: redirect to app
      const offerStr = offered ? `$${formatPrice(offered)} ${load.currency}` : "tu precio";
      await send(
        `Anotado, ${firstName}. Tu oferta de *${offerStr}* para el viaje *${lc5.folio}*.\n\n` +
        `Para enviarla formalmente entra a la app *Continente Conecta* → sección Cargas → *Hacer oferta*.`
      );
    }
    return;
  }

  // ── Availability query ────────────────────────────────────────────────────────
  if (intent === "availability_query") {
    const lc2 = loadCtx(load);
    if (isOpen) {
      await send(await aiLoadAvailable(
        carrier.name, lc2,
        `✅ Sí, *${load.reference}* (${lc2.ruta}) sigue disponible.\nTarifa: ${lc2.tarifa}\n\n¿Te interesa?`
      ));
    } else {
      const reason = load.status === "Asignado" ? "ya fue asignado" : load.status;
      await clearConversationLoad(from);
      await send(await aiLoadUnavailable(carrier.name, lc2, reason,
        `❌ El viaje *${load.reference}* ya no está disponible (${reason}).`
      ));
    }
    return;
  }

  // ── Show interest → always show summary, check unit only at confirm time ──────
  if (intent === "confirm_interest") {
    const lc3 = loadCtx(load);
    if (!isOpen) {
      const reason = load.status === "Asignado" ? "ya fue asignado" : load.status;
      await clearConversationLoad(from);
      await send(await aiLoadUnavailable(carrier.name, lc3, reason,
        `❌ El viaje *${load.reference}* ya no está disponible (${reason}).`
      ));
      return;
    }

    // Find unit eagerly if possible, but never block showing the summary
    const unit = await findAvailableUnit(carrier.uuid, load.equipmentType);
    const offer = unitOffer(load, unit, displayName);
    if (offer.state === "unavailable") {
      await clearConversationLoad(from);
      await send(offer.text);
      return;
    }

    await send(await aiShowSummary(carrier.name, lc3, unit ? unitCtx(unit) : null, offer.text));

    await upsertConversation(from, {
      pendingLoadId:       loadId,
      pendingUnitId:       unit?.id ?? null,
      pendingUnitCount:    offer.pendingUnitCount,
      pendingCounterPrice: null,
      state:               offer.state,
    });
    return;
  }

  // ── Unknown intent with load context ─────────────────────────────────────────
  const lc4 = loadCtx(load);

  // Carrier is mid-confirmation — remind them what step they're on instead of generic response
  if (conversation?.state === "awaiting_confirmation") {
    await send(
      `Solo falta tu confirmación para el viaje *${lc4.folio}* (${lc4.ruta}) por *${lc4.tarifa}*.\n\n` +
      `¿Le entramos? Responde *Sí* para confirmar o *No* para declinar.`
    );
    return;
  }

  // Use AI-generated response if available (already has conversation context)
  await send(aiSuggestedResponse ?? await aiUnknownWithLoad(carrier.name, lc4,
    `Tienes disponible el viaje *${lc4.folio}* (${lc4.ruta}) por *${lc4.tarifa}*.\n¿Te interesa tomarlo?`
  ));
}

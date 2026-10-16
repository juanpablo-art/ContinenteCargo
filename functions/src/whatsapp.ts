import * as admin from "firebase-admin";
import axios, { AxiosError } from "axios";
import * as crypto from "crypto";
import {
  WA_API_VERSION,
  WA_LANGUAGE,
  WA_MAX_RETRIES,
  WA_RETRY_DELAYS,
  WA_COLLECTION,
} from "./config";
import { WaEvent, WaMessageRecord, WaStatus } from "./types";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface TextParam {
  type: "text";
  text: string;
}

export type TemplateParam = TextParam; // extend as needed (currency, date_time)

export interface QuickReplyButton {
  index: number;
  payload: string;
}

/** Dynamic suffix for a template URL button. The approved template owns the base URL. */
export interface UrlButton {
  index: number;
  text: string;
}

export interface SendTemplateOptions {
  phoneNumberId: string;
  accessToken: string;
  to: string;
  templateName: string;
  bodyParams?: TemplateParam[];
  // Quick-reply button payloads (for templates with buttons)
  quickReplyButtons?: QuickReplyButton[];
  // URL button suffix, usually the phone so the template base can be /register?telefono=
  urlButton?: UrlButton;
  // Audit / idempotency
  idempotencyKey: string;
  event: WaEvent;
  loadId?: string;
  offerId?: string;
  carrierId?: string;
  adminId?: string;
}

// ─── Idempotency + send ───────────────────────────────────────────────────────

/**
 * Sends a WhatsApp template message with full idempotency and audit logging.
 *
 * - Checks Firestore before sending; skips if already accepted/sent/delivered/read.
 * - Retries up to WA_MAX_RETRIES times for transient (5xx / network) errors.
 * - 4xx errors are marked as permanent failures without retry.
 *
 * Returns true if a message was sent (or had already been sent), false on failure.
 */
export async function sendWhatsAppTemplate(
  opts: SendTemplateOptions
): Promise<boolean> {
  const db = admin.firestore();
  const docRef = db.collection(WA_COLLECTION).doc(opts.idempotencyKey);

  // ── Idempotency check (transactional) ───────────────────────────────────────
  const proceed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    if (snap.exists) {
      const rec = snap.data() as WaMessageRecord;
      // Only retry if last attempt failed — all other statuses are final enough.
      if (rec.status !== "failed") {
        console.log(`[WA] Duplicate skip: ${opts.idempotencyKey} (status=${rec.status})`);
        return false;
      }
    }
    const now = admin.firestore.Timestamp.now();
    const record: Partial<WaMessageRecord> = {
      idempotencyKey: opts.idempotencyKey,
      to: opts.to,
      event: opts.event,
      templateName: opts.templateName,
      ...(opts.loadId    !== undefined && { loadId:    opts.loadId }),
      ...(opts.offerId   !== undefined && { offerId:   opts.offerId }),
      ...(opts.carrierId !== undefined && { carrierId: opts.carrierId }),
      ...(opts.adminId   !== undefined && { adminId:   opts.adminId }),
      status: "pending",
      attempts: 0,
      createdAt: snap.exists ? (snap.data() as WaMessageRecord).createdAt : now,
      updatedAt: now,
    };
    tx.set(docRef, record, { merge: true });
    return true;
  });

  if (!proceed) return true; // already handled

  // ── Build request ─────────────────────────────────────────────────────────
  const components: object[] = [];
  if (opts.bodyParams && opts.bodyParams.length > 0) {
    components.push({ type: "body", parameters: opts.bodyParams });
  }
  if (opts.quickReplyButtons && opts.quickReplyButtons.length > 0) {
    for (const btn of opts.quickReplyButtons) {
      components.push({
        type:     "button",
        sub_type: "quick_reply",
        index:    String(btn.index),
        parameters: [{ type: "payload", payload: btn.payload }],
      });
    }
  }
  if (opts.urlButton) {
    components.push({
      type: "button",
      sub_type: "url",
      index: String(opts.urlButton.index),
      parameters: [{ type: "text", text: opts.urlButton.text }],
    });
  }

  const payload = {
    messaging_product: "whatsapp",
    to: opts.to,
    type: "template",
    template: {
      name: opts.templateName,
      language: { code: WA_LANGUAGE },
      components,
    },
  };

  const url = `https://graph.facebook.com/${WA_API_VERSION}/${opts.phoneNumberId}/messages`;
  const headers = {
    Authorization: `Bearer ${opts.accessToken}`,
    "Content-Type": "application/json",
  };

  // ── Send with retry ────────────────────────────────────────────────────────
  let lastError = "";
  let attempt = 0;

  while (attempt < WA_MAX_RETRIES) {
    attempt++;
    try {
      const resp = await axios.post(url, payload, { headers, timeout: 15_000 });
      const waMessageId = (resp.data?.messages?.[0]?.id as string) ?? null;

      await docRef.update({
        status: "accepted" as WaStatus,
        waMessageId,
        attempts: attempt,
        updatedAt: admin.firestore.Timestamp.now(),
        error: admin.firestore.FieldValue.delete(),
      });
      console.log(`[WA] ✅ Accepted: to=${opts.to} wamid=${waMessageId} key=${opts.idempotencyKey}`);
      return true;
    } catch (err) {
      const axErr = err as AxiosError;
      const status = axErr.response?.status ?? 0;
      lastError = axErr.message;

      // 4xx → permanent failure, no retry
      if (status >= 400 && status < 500) {
        const errData = JSON.stringify(axErr.response?.data ?? {});
        const metaError = (axErr.response?.data as Record<string, unknown> | undefined)?.error as Record<string, unknown> | undefined;
        const metaCode    = metaError?.code;
        const metaSubcode = metaError?.error_subcode;

        // code 100 / subcode 33: el Phone Number ID no existe o el token no tiene acceso.
        // Esto indica que WHATSAPP_PHONE_NUMBER_ID contiene un ID incorrecto (WABA ID,
        // App ID o Page ID en lugar del Phone Number ID), o que el número fue eliminado,
        // o que el token no tiene permiso sobre ese número.
        if (metaCode === 100 && metaSubcode === 33) {
          console.error(
            `[WA] ❌ Phone Number ID inválido o sin acceso. ` +
            `Verifica en Meta Business Manager → WhatsApp Manager → Números de teléfono ` +
            `que el Phone Number ID coincida con el secreto WHATSAPP_PHONE_NUMBER_ID, ` +
            `y que el token tenga el permiso whatsapp_business_messaging sobre ese número. ` +
            `ID en uso (últimos 4 dígitos): ...${opts.phoneNumberId.slice(-4)}`
          );
        }

        console.error(`[WA] ❌ Permanent error ${status}: ${errData}`);
        await docRef.update({
          status: "failed" as WaStatus,
          attempts: attempt,
          error: `${status}: ${errData}`,
          updatedAt: admin.firestore.Timestamp.now(),
        });
        return false;
      }

      // 5xx / network → retry after delay
      console.warn(`[WA] ⚠️ Transient error attempt ${attempt}/${WA_MAX_RETRIES}: ${lastError}`);
      if (attempt < WA_MAX_RETRIES) {
        await sleep(WA_RETRY_DELAYS[attempt - 1] ?? 4_000);
      }
    }
  }

  // Exhausted retries
  await docRef.update({
    status: "failed" as WaStatus,
    attempts: attempt,
    error: lastError,
    updatedAt: admin.firestore.Timestamp.now(),
  });
  console.error(`[WA] ❌ Exhausted retries for ${opts.idempotencyKey}: ${lastError}`);
  return false;
}

// ─── Webhook helpers ──────────────────────────────────────────────────────────

/**
 * Validates the X-Hub-Signature-256 header from Meta.
 * Returns true if the signature matches.
 */
export function validateWebhookSignature(
  rawBody: Buffer,
  signatureHeader: string,
  webhookSecret: string
): boolean {
  if (!signatureHeader.startsWith("sha256=")) return false;
  const expected = "sha256=" +
    crypto.createHmac("sha256", webhookSecret).update(rawBody).digest("hex");
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signatureHeader),
      Buffer.from(expected)
    );
  } catch {
    return false;
  }
}

/**
 * Updates the status of a tracked WA message given a wamid received in a
 * webhook status update.
 */
export async function updateWaStatusByWamid(
  waMessageId: string,
  newStatus: WaStatus
): Promise<void> {
  const db = admin.firestore();
  const snap = await db
    .collection(WA_COLLECTION)
    .where("waMessageId", "==", waMessageId)
    .limit(1)
    .get();

  if (snap.empty) {
    // Message may have been sent before this tracking was deployed — ignore.
    console.warn(`[WA-Webhook] Unknown wamid=${waMessageId}, status=${newStatus}`);
    return;
  }
  await snap.docs[0].ref.update({
    status: newStatus,
    updatedAt: admin.firestore.Timestamp.now(),
  });
  console.log(`[WA-Webhook] Updated wamid=${waMessageId} → ${newStatus}`);
}

// ─── Free-text reply (24-hour customer service window) ───────────────────────

/**
 * Sends a plain-text WhatsApp message.
 * Only works within Meta's 24-hour customer service window (carrier sent a message first).
 * Returns the wamid on success, null on failure.
 */
export async function sendWhatsAppText(
  phoneNumberId: string,
  accessToken: string,
  to: string,
  text: string
): Promise<string | null> {
  const url = `https://graph.facebook.com/${WA_API_VERSION}/${phoneNumberId}/messages`;
  try {
    const resp = await axios.post(
      url,
      {
        messaging_product: "whatsapp",
        to,
        type: "text",
        text: { body: text, preview_url: false },
      },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        timeout: 15_000,
      }
    );
    const wamid = (resp.data?.messages?.[0]?.id as string) ?? null;
    console.log(`[WA] sendText ✅ to=${to} wamid=${wamid} body="${text.replace(/\n/g, "\\n").substring(0, 200)}"`);
    return wamid;
  } catch (err) {
    const axErr = err as AxiosError;
    console.error(`[WA] sendText ❌ to=${to}:`, axErr.response?.data ?? axErr.message);
    return null;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Convenience: build a text parameter list from ordered string values. */
export function textParams(...values: string[]): TemplateParam[] {
  return values.map((text) => ({ type: "text" as const, text }));
}
